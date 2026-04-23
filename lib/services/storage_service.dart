import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;

  // ─── BYTES-BASED (web + mobile) ───────────────────────────────────────────
  // These methods THROW on failure — callers must handle errors.

  static Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref      = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: contentType);
    final task     = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }

  static Future<String> uploadXFile({
    required String path,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(path: path, bytes: bytes);
  }

  /// Uploads promo images and returns their download URLs.
  /// Path: promos/{promoId}/{timestamp}_{index}.jpg
  /// THROWS if any upload fails.
  static Future<List<String>> uploadPromoImages(
      String promoId, List<XFile> files) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final url = await uploadXFile(
        path: 'promos/$promoId/${ts}_$i.jpg',
        file: files[i],
      );
      urls.add(url);
    }
    return urls;
  }

  // ─── FILE-BASED (mobile only) ─────────────────────────────────────────────
  // Used by register_screen for matricule upload.
  // Returns null on failure (fire-and-forget; non-critical for registration).

  static Future<String?> uploadFile({
    required String path,
    required File file,
  }) async {
    try {
      final ref  = _storage.ref().child(path);
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadMatricule(String uid, File file) =>
      uploadFile(path: 'matricules/$uid.jpg', file: file);

  static Future<String?> uploadMatriculeXFile(String uid, XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadBytes(path: 'matricules/$uid.jpg', bytes: bytes);
    } catch (_) {
      return null;
    }
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────

  static Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
