import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  static final _auth       = FirebaseAuth.instance;
  static final _db         = FirebaseFirestore.instance;
  static final _googleSignIn = GoogleSignIn(scopes: ['email']);

  // ─── STATE ────────────────────────────────────────────────────────────────

  static User?          get currentUser  => _auth.currentUser;
  static String?        get currentUid   => _auth.currentUser?.uid;
  static Stream<User?>  get authState    => _auth.authStateChanges();

  // ─── READ ─────────────────────────────────────────────────────────────────

  static Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromDocument(doc);
    } catch (_) {
      return null;
    }
  }

  static Future<UserModel?> getCurrentUserData() async {
    final uid = currentUid;
    if (uid == null) return null;
    return getUserData(uid);
  }

  static Stream<UserModel?> watchCurrentUser() {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) =>
            doc.exists ? UserModel.fromDocument(doc) : null);
  }

  // ─── AUTH OPERATIONS ──────────────────────────────────────────────────────

  static Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email:    email.trim(),
      password: password,
    );
    final uid  = credential.user!.uid;
    final user = await getUserData(uid);
    if (user == null) throw Exception('user-data-not-found');
    return user;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    try { await _googleSignIn.signOut(); } catch (_) {}
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Persists the FCM device token to the user document.
  /// Pass an empty string to clear the token (on sign-out).
  static Future<void> saveFcmToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': token});
    } catch (_) {}
  }

  // ─── GOOGLE SIGN-IN ──────────────────────────────────────────────────────

  static Future<UserModel> signInWithGoogle() async {
    late UserCredential credential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      credential = await _auth.signInWithPopup(provider);
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('google-signin-cancelled');
      final googleAuth = await googleUser.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(oauthCredential);
    }

    final uid       = credential.user!.uid;
    final fireUser  = credential.user!;

    // Fetch or create user document
    var userData = await getUserData(uid);
    if (userData == null) {
      userData = UserModel(
        uid:    uid,
        name:   fireUser.displayName ?? 'Utilisateur',
        email:  fireUser.email       ?? '',
        role:   UserRole.client,
        status: UserStatus.active,
      );
      await _db.collection('users').doc(uid).set({
        ...userData.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return userData;
  }

  // ─── REGISTER CLIENT ──────────────────────────────────────────────────────

  static Future<UserModel> createClient({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email:    email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    final data = UserModel(
      uid:    uid,
      name:   name.trim(),
      email:  email.trim(),
      role:   UserRole.client,
      status: UserStatus.active,
    );

    await _db.collection('users').doc(uid).set({
      ...data.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return data;
  }

  // ─── REGISTER BUSINESS ────────────────────────────────────────────────────

  static Future<UserModel> createBusiness({
    required String ownerName,
    required String email,
    required String password,
    required String commerceName,
    required String matricule,
    required String category,
    required double lat,
    required double lng,
    String? matriculeImageUrl,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email:    email.trim(),
      password: password,
    );
    final uid   = credential.user!.uid;
    final now   = FieldValue.serverTimestamp();
    final batch = _db.batch();

    final userModel = UserModel(
      uid:    uid,
      name:   ownerName.trim(),
      email:  email.trim(),
      role:   UserRole.entreprise,
      status: UserStatus.pending,
    );

    batch.set(_db.collection('users').doc(uid), {
      ...userModel.toMap(),
      'createdAt': now,
    });

    batch.set(_db.collection('businesses').doc(uid), {
      'name':       commerceName.trim(),
      'ownerName':  ownerName.trim(),
      'email':      email.trim(),
      'matricule':         matricule.trim(),
      if (matriculeImageUrl != null) 'matriculeImageUrl': matriculeImageUrl,
      'category':          category,
      'lat':               lat,
      'lng':               lng,
      'status':            'pending',
      'createdAt':  now,
      'stats': {
        'views': 0, 'clicks': 0, 'conversions': 0, 'savings': 0,
      },
      'weekly_views': {
        'lun': 0, 'mar': 0, 'mer': 0,
        'jeu': 0, 'ven': 0, 'sam': 0, 'dim': 0,
      },
    });

    await batch.commit();
    return userModel;
  }

  // ─── ADMIN — WATCH ALL USERS ─────────────────────────────────────────────

  static Stream<List<UserModel>> watchAllUsers() {
    return _db
        .collection('users')
        .snapshots()
        .map((snap) => snap.docs
            .map(UserModel.fromDocument)
            .toList());
  }

  static Stream<List<UserModel>> watchUsersByRole(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snap) => snap.docs
            .map(UserModel.fromDocument)
            .toList());
  }

  static Future<void> updateUserStatus(String uid, String status) async {
    await _db.collection('users').doc(uid).update({'status': status});
  }

  static Future<void> updateUserName(String uid, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('Le nom ne peut pas être vide.');
    if (trimmed.length > 60) throw Exception('Le nom est trop long (max. 60 caractères).');
    await _db.collection('users').doc(uid).update({'name': trimmed});
  }

  static Future<void> updateUserPhone(String uid, String phone) async {
    final cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\.]'), '');
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleaned)) {
      throw Exception('Numéro invalide (ex: 0555 123 456 ou +213555123456).');
    }
    await _db.collection('users').doc(uid).update({'phone': cleaned});
  }

}
