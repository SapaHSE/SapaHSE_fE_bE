import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SUPABASE STORAGE SERVICE
/// ═══════════════════════════════════════════════════════════════════════════
/// Handles uploading & deleting images to Supabase Storage from Flutter.
/// The returned public URL is sent to the Laravel backend, which only stores
/// it as a string (no file handling on the server anymore).
class SupabaseStorageService {
  static SupabaseClient get _client => Supabase.instance.client;
  static String get _bucket => SupabaseConfig.storageBucket;

  /// Upload a local image file to Supabase Storage.
  /// Returns the public URL on success, or null on failure.
  ///
  /// [imagePath] absolute path of the picked image
  /// [folder] subfolder inside the bucket (e.g. 'hazard-reports')
  static Future<String?> uploadImage({
    required String imagePath,
    required String folder,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('SupabaseStorage: file not found at $imagePath');
        return null;
      }

      final ext = _extensionFromPath(imagePath);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}$ext';
      final objectPath = '$folder/$fileName';

      await _client.storage.from(_bucket).upload(
            objectPath,
            file,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: _contentTypeFromExt(ext),
            ),
          );

      final publicUrl =
          _client.storage.from(_bucket).getPublicUrl(objectPath);
      debugPrint('SupabaseStorage: uploaded -> $publicUrl');
      return publicUrl;
    } on StorageException catch (e) {
      debugPrint('SupabaseStorage upload error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('SupabaseStorage unknown upload error: $e');
      return null;
    }
  }

  /// Delete an object from the bucket given its full public URL.
  /// Returns true on success.
  static Future<bool> deleteByUrl(String publicUrl) async {
    try {
      final objectPath = _objectPathFromUrl(publicUrl);
      if (objectPath == null) return false;

      await _client.storage.from(_bucket).remove([objectPath]);
      return true;
    } catch (e) {
      debugPrint('SupabaseStorage delete error: $e');
      return false;
    }
  }

  /// Extract the storage object path from a Supabase public URL.
  /// Example URL pattern:
  ///   https://xxx.supabase.co/storage/v1/object/public/<bucket>/<folder>/<file>
  static String? _objectPathFromUrl(String url) {
    final marker = '/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    return url.substring(idx + marker.length);
  }

  static String _extensionFromPath(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot < 0 || lastDot == path.length - 1) return '.jpg';
    final ext = path.substring(lastDot).toLowerCase();
    // Sanity-check: only allow image-ish extensions
    const allowed = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'};
    return allowed.contains(ext) ? ext : '.jpg';
  }

  static String _contentTypeFromExt(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  static String _randomSuffix() {
    final ms = DateTime.now().microsecondsSinceEpoch;
    return ms.toRadixString(36);
  }
}
