import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/announcement.dart';
import 'api_service.dart';

class AnnouncementRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

class AnnouncementService {
  static final AnnouncementRefreshNotifier refreshNotifier =
      AnnouncementRefreshNotifier();

  static Future<List<Announcement>> getAnnouncements({int page = 1}) async {
    try {
      final response =
          await ApiService.get('/announcements?per_page=100&page=$page');
      if (!response.success || response.data is! Map) {
        return [];
      }

      final rawData = response.data['data'];
      final data = rawData is List ? rawData : const <dynamic>[];
      return data
          .whereType<Map>()
          .map((json) => Announcement.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      return [];
    }
  }

  static Future<bool> createAnnouncement({
    required String title,
    required String body,
    required bool isUrgent,
    File? image,
  }) async {
    try {
      final fields = <String, String>{
        'title': title,
        'body': body,
        'is_urgent': isUrgent ? '1' : '0',
      };

      final files = <http.MultipartFile>[];
      if (image != null) {
        files.add(await http.MultipartFile.fromPath('image', image.path));
      }

      final response = await ApiService.postMultipart(
        '/announcements',
        fields,
        files,
      );
      if (response.success) {
        refreshNotifier.refresh();
      }
      return response.success;
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      return false;
    }
  }
}
