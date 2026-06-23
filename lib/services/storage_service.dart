import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/cloudinary_config.dart';

// ─── CLOUDINARY STORAGE SERVICE ──────────────────────────────────────────────
//
// Uploads images to Cloudinary using unsigned multipart/form-data requests.
// No Firebase Storage SDK required — only the http package.
//
// Public API surface is identical to the old Firebase Storage version so that
// PromoService, RegisterScreen, etc. need zero changes.

class StorageService {

  // ─── PROMO IMAGES ──────────────────────────────────────────────────────────

  /// Uploads [files] to Cloudinary under promos/[promoId]/ and returns the
  /// list of secure HTTPS URLs in the same order.
  /// [onProgress] fires after each successful upload: (doneCount, totalCount).
  /// Throws [Exception] with a French-language message on any failure.
  static Future<List<String>> uploadPromoImages(
    String promoId,
    List<XFile> files, {
    void Function(int done, int total)? onProgress,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final url = await _uploadXFile(
        files[i],
        folder: 'promos/$promoId',
      );
      urls.add(url);
      onProgress?.call(i + 1, files.length);
    }
    return urls;
  }

  // ─── MATRICULE (mobile only) ────────────────────────────────────────────────

  static Future<String?> uploadMatricule(String uid, File file) async {
    try {
      return await _uploadXFile(XFile(file.path), folder: 'matricules/$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[StorageService] matricule error: $e');
      return null;
    }
  }

  static Future<String?> uploadMatriculeXFile(String uid, XFile file) async {
    try {
      return await _uploadXFile(file, folder: 'matricules/$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[StorageService] matriculeXFile error: $e');
      return null;
    }
  }

  // ─── DELETE ────────────────────────────────────────────────────────────────
  // Cloudinary deletion requires the API secret (server-side only).
  // Orphaned assets can be removed manually in the Cloudinary Media Library.
  static Future<void> deleteFile(String url) async {}

  // ─── INTERNAL ──────────────────────────────────────────────────────────────

  static Future<String> _uploadXFile(XFile file, {String? folder}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Fichier image vide ou illisible.');

    final uri     = Uri.parse(CloudinaryConfig.imageUploadUrl);
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'image.jpg',
      ),
    );

    final http.StreamedResponse response;
    try {
      response = await request.send().timeout(const Duration(seconds: 60));
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('imeout')) {
        throw Exception('Délai réseau dépassé. Vérifiez votre connexion.');
      }
      throw Exception(
          'Impossible de contacter Cloudinary. Vérifiez votre connexion.');
    }

    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(_parseError(body, response.statusCode));
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final url  = data['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary : aucune URL reçue dans la réponse.');
    }
    return url;
  }

  static String _parseError(String body, int statusCode) {
    try {
      final data    = jsonDecode(body) as Map<String, dynamic>;
      final error   = data['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String? ?? '';

      if (message.contains('upload_preset')) {
        return 'Preset Cloudinary invalide. Vérifiez CloudinaryConfig.uploadPreset.';
      }
      if (message.contains('cloud_name') || statusCode == 404) {
        return 'Cloud name invalide. Vérifiez CloudinaryConfig.cloudName.';
      }
      if (message.contains('Invalid image') ||
          message.contains('format')) {
        return 'Format d\'image non supporté. Utilisez JPG, PNG ou WebP.';
      }
      if (message.contains('File size') || message.contains('too large')) {
        return 'Image trop volumineuse. Réduisez la taille et réessayez.';
      }
      if (message.isNotEmpty) return 'Cloudinary : $message';
    } catch (_) {}
    return 'Erreur upload (HTTP $statusCode). Réessayez.';
  }
}
