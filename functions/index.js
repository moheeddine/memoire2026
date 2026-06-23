/**
 * PromoCity — Cloud Functions v2
 *
 * Functions:
 *   deleteExpiredPromos     — Scheduled every 60 min: hard-delete expired promos + Cloudinary images
 *   onPromoPublished        — Firestore trigger on promo CREATE: fan-out new-promo notifications
 *   sendExpirationReminders — Scheduled every 60 min: notify interested users 24 h before expiry
 */

const { onSchedule }       = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions }  = require("firebase-functions/v2");
const { defineSecret }      = require("firebase-functions/params");
const { initializeApp }     = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getMessaging }      = require("firebase-admin/messaging");
const { v2: cloudinary }    = require("cloudinary");

initializeApp();

// Région la plus proche (Paris)
setGlobalOptions({ region: "europe-west1" });

// Cloudinary secrets
const cloudinaryApiKey    = defineSecret("CLOUDINARY_API_KEY");
const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");

// ─── HELPERS ─────────────────────────────────────────────────────────────────

/**
 * Sends an FCM multicast to up to 500 tokens per call.
 * Returns total success count.
 */
async function sendFcmMulticast(tokens, notification, data) {
  if (!tokens || tokens.length === 0) return 0;
  const messaging = getMessaging();
  let successCount = 0;

  // FCM allows max 500 tokens per multicast call
  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    try {
      const response = await messaging.sendEachForMulticast({
        tokens:       batch,
        notification,
        data,
        android: {
          priority:   "high",
          notification: { channelId: "cityone_urgent" },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      });
      successCount += response.successCount;
      if (response.failureCount > 0) {
        console.warn(`FCM batch: ${response.failureCount} failure(s)`);
      }
    } catch (err) {
      console.error("FCM multicast error:", err.message);
    }
  }
  return successCount;
}

/**
 * Writes a Firestore notification document with a deterministic ID (no dupes).
 * Uses a Firestore transaction to skip if the doc already exists.
 * Returns true if written, false if already existed.
 */
async function writeNotification(db, docId, payload) {
  const ref = db.collection("notifications").doc(docId);
  let written = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return;
    tx.set(ref, { ...payload, createdAt: FieldValue.serverTimestamp() });
    written = true;
  });
  return written;
}

// ─── 1. DELETE EXPIRED PROMOS (existing, updated) ────────────────────────────

exports.deleteExpiredPromos = onSchedule(
  {
    schedule:       "every 60 minutes",
    timeZone:       "Africa/Tunis",
    secrets:        [cloudinaryApiKey, cloudinaryApiSecret],
    memory:         "256MiB",
    timeoutSeconds: 120,
  },
  async (_event) => {
    const db  = getFirestore();
    const now = new Date();
    const nowTs = Timestamp.fromDate(now);

    cloudinary.config({
      cloud_name: "dkpbxucct",
      api_key:    cloudinaryApiKey.value(),
      api_secret: cloudinaryApiSecret.value(),
      secure:     true,
    });

    console.log(`[deleteExpiredPromos] Start — ${now.toISOString()}`);

    let snap;
    try {
      snap = await db
        .collection("promos")
        .where("expirationDate", "<=", nowTs)
        .get();
    } catch (err) {
      console.error("[deleteExpiredPromos] Firestore error:", err);
      return;
    }

    if (snap.empty) {
      console.log("[deleteExpiredPromos] No expired promos.");
      return;
    }

    console.log(`[deleteExpiredPromos] ${snap.size} expired promo(s) found.`);
    let deleted = 0, errors = 0;

    for (const doc of snap.docs) {
      const data    = doc.data();
      const promoId = doc.id;
      const title   = data.title || promoId;
      try {
        // Delete Cloudinary images
        const imageUrls = Array.isArray(data.imageUrls) ? data.imageUrls : [];
        if (imageUrls.length > 0) {
          const publicIds = imageUrls.map(extractPublicId).filter(Boolean);
          if (publicIds.length > 0) {
            try {
              await cloudinary.api.delete_resources(publicIds, { resource_type: "image" });
              console.log(`  ✓ ${publicIds.length} Cloudinary image(s) deleted`);
            } catch (cdnErr) {
              console.warn(`  ⚠ Cloudinary error for ${promoId}:`, cdnErr.message);
            }
          }
        }

        // Delete related favorites
        const favSnap = await db.collection("favorites").where("promoId", "==", promoId).get();
        if (!favSnap.empty) {
          const b = db.batch();
          favSnap.docs.forEach((d) => b.delete(d.ref));
          await b.commit();
        }

        // Delete related reservations
        const resSnap = await db.collection("reservations").where("promoId", "==", promoId).get();
        if (!resSnap.empty) {
          const b = db.batch();
          resSnap.docs.forEach((d) => b.delete(d.ref));
          await b.commit();
        }

        // Delete Firestore promo document
        await doc.ref.delete();
        console.log(`  ✓ Promo "${title}" deleted`);
        deleted++;
      } catch (err) {
        console.error(`  ✗ Failed for "${title}" (${promoId}):`, err);
        errors++;
      }
    }
    console.log(`[deleteExpiredPromos] Done — ${deleted} deleted, ${errors} error(s).`);
  }
);

// ─── 2. ON PROMO PUBLISHED ────────────────────────────────────────────────────
//
// Fires when any document is created in the "promos" collection.
// Smart fan-out:
//   • Firestore notification → business followers + high-discount promos (≥ 25 %)
//   • FCM push              → ALL active clients with a token

exports.onPromoPublished = onDocumentCreated(
  {
    document:       "promos/{promoId}",
    region:         "europe-west1",
    memory:         "512MiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const promo   = snap.data();
    const promoId = event.params.promoId;

    // Only notify for approved promos (promos are auto-approved in this app).
    if (promo.status !== "approved") {
      console.log(`[onPromoPublished] Skipped ${promoId} — status: ${promo.status}`);
      return;
    }

    const db           = getFirestore();
    const businessId   = promo.businessId  || "";
    const businessName = promo.businessName || "Un commerce";
    const promoTitle   = promo.title        || "Nouvelle promotion";
    const category     = promo.category     || "";
    const discount     = promo.discountPercentage || promo.discount || 0;
    const HIGH_DISCOUNT = 25; // notify ALL clients if discount ≥ this value

    console.log(`[onPromoPublished] New promo: "${promoTitle}" by ${businessName} (${discount}%)`);

    // ── A. Get business followers ──────────────────────────────────────────
    const bizFavsSnap = await db.collection("favorites")
      .where("businessId", "==", businessId)
      .get();
    const businessFollowers = new Set(bizFavsSnap.docs.map((d) => d.data().userId));
    console.log(`  Business followers: ${businessFollowers.size}`);

    // ── B. Get all active client users ────────────────────────────────────
    const usersSnap = await db.collection("users")
      .where("role",   "==", "client")
      .where("status", "==", "active")
      .get();
    console.log(`  Active clients: ${usersSnap.size}`);

    if (usersSnap.empty) return;

    // ── C. Build notification documents + collect FCM tokens ──────────────
    const fcmTokens = [];
    const notifPayload = {
      type:         "new_promotion",
      senderId:     businessId,
      actorName:    businessName,
      title:        "🎉 Nouvelle promotion disponible !",
      commentId:    "",
      promoId:      promoId,
      promoTitle:   promoTitle,
      message:      `Découvrez une nouvelle offre publiée par ${businessName}.`,
      isRead:       false,
    };

    const isHighDiscount = discount >= HIGH_DISCOUNT;
    const batches        = [];
    let   currentBatch   = db.batch();
    let   batchOps       = 0;
    let   notifCount     = 0;

    for (const userDoc of usersSnap.docs) {
      const user   = userDoc.data();
      const userId = userDoc.id;

      // Smart filter: Firestore notification only for interested users.
      const isBizFollower = businessFollowers.has(userId);
      if (isBizFollower || isHighDiscount) {
        const docId = `promo_new_${promoId}_${userId}`;
        const ref   = db.collection("notifications").doc(docId);
        currentBatch.set(ref, {
          ...notifPayload,
          targetUserId: userId,
          createdAt:    FieldValue.serverTimestamp(),
        }, { merge: false }); // idempotent: don't overwrite if exists
        batchOps++;
        notifCount++;

        if (batchOps === 500) {
          batches.push(currentBatch.commit());
          currentBatch = db.batch();
          batchOps     = 0;
        }
      }

      // FCM push to ALL clients (cheap, and smart filter applies at UI level).
      if (user.fcmToken && user.fcmToken.length > 0) {
        fcmTokens.push(user.fcmToken);
      }
    }

    if (batchOps > 0) batches.push(currentBatch.commit());
    await Promise.all(batches);
    console.log(`  Firestore notifications written: ${notifCount}`);

    // ── D. Send FCM push ──────────────────────────────────────────────────
    const successCount = await sendFcmMulticast(
      fcmTokens,
      {
        title: "🎉 Nouvelle promotion disponible !",
        body:  `${businessName} : ${promoTitle}`,
      },
      {
        type:    "new_promotion",
        promoId: promoId,
      }
    );
    console.log(`  FCM sent to ${successCount}/${fcmTokens.length} device(s).`);
  }
);

// ─── 3. SEND EXPIRATION REMINDERS ────────────────────────────────────────────
//
// Runs every hour. Detects promos expiring within the next 24 hours and
// notifies users who have expressed interest (favorited or reserved).
// Sets expirationReminderSent = true to prevent duplicate runs.

exports.sendExpirationReminders = onSchedule(
  {
    schedule:       "every 60 minutes",
    timeZone:       "Africa/Tunis",
    memory:         "512MiB",
    timeoutSeconds: 180,
  },
  async (_event) => {
    const db  = getFirestore();
    const now = new Date();

    const windowStart = Timestamp.fromDate(now);
    const windowEnd   = Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000));

    console.log(`[sendExpirationReminders] Start — ${now.toISOString()}`);

    // ── A. Find promos expiring in the next 24 hours ───────────────────────
    let snap;
    try {
      snap = await db.collection("promos")
        .where("status",                 "==", "approved")
        .where("isActive",               "==", true)
        .where("expirationReminderSent", "!=", true)
        .where("expirationDate",         ">=", windowStart)
        .where("expirationDate",         "<=", windowEnd)
        .get();
    } catch (err) {
      // Composite index may not exist yet — fallback to client-side filter.
      console.warn("[sendExpirationReminders] Composite query failed, trying fallback:", err.message);
      try {
        snap = await db.collection("promos")
          .where("status",   "==", "approved")
          .where("isActive", "==", true)
          .where("expirationDate", ">=", windowStart)
          .where("expirationDate", "<=", windowEnd)
          .get();
        // Client-side filter to exclude already-notified promos
        snap = { docs: snap.docs.filter((d) => d.data().expirationReminderSent !== true) };
      } catch (fallbackErr) {
        console.error("[sendExpirationReminders] Fallback also failed:", fallbackErr);
        return;
      }
    }

    if (!snap.docs || snap.docs.length === 0) {
      console.log("[sendExpirationReminders] No promos expiring soon.");
      return;
    }

    console.log(`[sendExpirationReminders] ${snap.docs.length} promo(s) expiring soon.`);

    for (const promoDoc of snap.docs) {
      const promo      = promoDoc.data();
      const promoId    = promoDoc.id;
      const promoTitle = promo.title        || "Cette promotion";
      const businessId = promo.businessId   || "";
      const bizName    = promo.businessName || "Un commerce";

      console.log(`  Processing: "${promoTitle}" (${promoId})`);

      try {
        // ── B. Find interested users ─────────────────────────────────────
        // Users who favorited this promo OR reserved it.
        const [favSnap, resSnap] = await Promise.all([
          db.collection("favorites")
            .where("promoId", "==", promoId)
            .get(),
          db.collection("reservations")
            .where("promoId", "==", promoId)
            .get(),
        ]);

        // Deduplicate by userId → Map<userId, fcmToken|null>
        const interestedUsers = new Map();

        for (const d of [...favSnap.docs, ...resSnap.docs]) {
          const userId = d.data().userId;
          if (userId && !interestedUsers.has(userId)) {
            interestedUsers.set(userId, null); // token fetched below
          }
        }

        if (interestedUsers.size === 0) {
          console.log(`    No interested users for ${promoId}.`);
          // Still mark as sent so we don't revisit.
          await promoDoc.ref.update({ expirationReminderSent: true });
          continue;
        }

        // ── C. Fetch FCM tokens for interested users ──────────────────────
        const userIds = [...interestedUsers.keys()];
        const fcmTokens = [];
        const batches   = [];
        let   curBatch  = db.batch();
        let   batchOps  = 0;
        let   notifCount = 0;

        for (const userId of userIds) {
          // Fetch user document (to get fcmToken).
          const userDoc = await db.collection("users").doc(userId).get();
          const token   = userDoc.exists ? (userDoc.data().fcmToken || "") : "";
          if (token) fcmTokens.push(token);

          // Write Firestore notification (idempotent).
          const docId = `promo_expiring_${promoId}_${userId}`;
          const ref   = db.collection("notifications").doc(docId);
          curBatch.set(ref, {
            type:         "expiring_promotion",
            targetUserId: userId,
            senderId:     businessId,
            actorName:    bizName,
            title:        "⏰ Cette promotion expire bientôt !",
            commentId:    "",
            promoId:      promoId,
            promoTitle:   promoTitle,
            message:      `Plus que 24 heures pour profiter de cette offre de ${bizName}.`,
            isRead:       false,
            createdAt:    FieldValue.serverTimestamp(),
          }, { merge: false });
          batchOps++;
          notifCount++;

          if (batchOps === 500) {
            batches.push(curBatch.commit());
            curBatch  = db.batch();
            batchOps  = 0;
          }
        }

        if (batchOps > 0) batches.push(curBatch.commit());
        await Promise.all(batches);
        console.log(`    Firestore notifications: ${notifCount}`);

        // ── D. Send FCM push ──────────────────────────────────────────────
        const sent = await sendFcmMulticast(
          fcmTokens,
          {
            title: "⏰ Cette promotion expire bientôt !",
            body:  `Plus que 24 heures pour profiter de l'offre ${promoTitle}.`,
          },
          {
            type:    "expiring_promotion",
            promoId: promoId,
          }
        );
        console.log(`    FCM sent: ${sent}/${fcmTokens.length} device(s).`);

        // ── E. Mark promo so the scheduler skips it next run ─────────────
        await promoDoc.ref.update({ expirationReminderSent: true });
        console.log(`    expirationReminderSent = true for ${promoId}.`);

      } catch (err) {
        console.error(`  ✗ Error for "${promoTitle}" (${promoId}):`, err);
      }
    }

    console.log("[sendExpirationReminders] Done.");
  }
);

// ─── HELPER ──────────────────────────────────────────────────────────────────

function extractPublicId(url) {
  if (!url || typeof url !== "string") return null;
  try {
    const marker = "/image/upload/";
    const idx    = url.indexOf(marker);
    if (idx === -1) return null;
    let path = url.slice(idx + marker.length);
    path = path.replace(/^v\d+\//, "");
    path = path.replace(/\.[^/.]+$/, "");
    return path || null;
  } catch {
    return null;
  }
}
