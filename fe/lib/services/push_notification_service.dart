import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app_globals.dart';
import '../models/report.dart';
import '../screens/report_detail_screen.dart';
import '../screens/news_detail_screen.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'report_service.dart';
import 'news_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;
    _isInitialized = true;

    // 1. Request permissions (especially for iOS & Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }

    await _fcm.setAutoInitEnabled(true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          _handleNotificationClick(data);
        }
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && !kIsWeb) {
        _localNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 4. Handle Notification Click when app is in Background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
      if (kDebugMode) {
        print('FCM token refreshed');
      }
      await _registerTokenWithBackend(token);
    });

    // 5. Handle Notification Click when app was terminated
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage.data);
    }

    await syncTokenWithBackendIfLoggedIn();
  }

  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _registerTokenWithBackend(token);
      }
      return token;
    } catch (e) {
      if (kDebugMode) print('Error getting FCM token: $e');
      return null;
    }
  }

  static Future<void> syncTokenWithBackendIfLoggedIn() async {
    if (kIsWeb) return;

    final userToken = await StorageService.getToken();
    if (userToken == null) {
      if (kDebugMode) {
        print('Skip FCM sync: user belum login');
      }
      return;
    }

    // Only register if user has not explicitly disabled notifications
    final isEnabled = await StorageService.isNotificationEnabled();
    if (!isEnabled) {
      if (kDebugMode) {
        print('Skip FCM sync: notifikasi push dimatikan oleh user');
      }
      return;
    }

    await getToken();
  }

  /// Enable or disable push notifications.
  /// When enabled:  registers FCM token with backend.
  /// When disabled: removes FCM token from backend & deletes local token.
  static Future<void> setEnabled(bool enabled) async {
    await StorageService.setNotificationEnabled(enabled);

    if (enabled) {
      // Register FCM token with backend
      await getToken();
    } else {
      // Unregister from backend
      await _unregisterFromBackend();
    }
  }

  static Future<void> _unregisterFromBackend() async {
    if (kIsWeb) return;
    try {
      final userToken = await StorageService.getToken();
      if (userToken == null) return;

      final response = await ApiService.post('/notifications/unregister-fcm', {});
      if (response.success) {
        if (kDebugMode) {
          print('FCM token unregistered successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to unregister FCM token: ${response.errorMessage}');
        }
      }

      // Also delete the local FCM token
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error unregistering FCM token: $e');
      }
    }
  }

  static Future<void> _registerTokenWithBackend(String token) async {
    if (kIsWeb) return;
    try {
      // Only register if user is logged in
      final userToken = await StorageService.getToken();
      if (userToken == null) {
        if (kDebugMode) {
          print('Skip FCM register: auth token tidak ada');
        }
        return;
      }

      final response = await ApiService.post('/notifications/register-fcm', {
        'fcm_token': token,
      });

      if (response.success) {
        if (kDebugMode) print('FCM token registered successfully');
      } else {
        if (kDebugMode) {
          print('Failed to register FCM token: ${response.errorMessage}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error registering FCM token: $e');
      }
    }
  }

  static Future<void> _handleNotificationClick(
      Map<String, dynamic> data) async {
    if (kDebugMode) print('Notification clicked with data: $data');

    final type = data['type']?.toString();
    final id = (data['report_id'] ?? data['announcement_id'] ?? data['news_id'])
        ?.toString();

    if (type == null || id == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      if (type.contains('hazard') || type.contains('inspection')) {
        final reportType =
            type.contains('hazard') ? ReportType.hazard : ReportType.inspection;
        final result = await ReportService.getReportDetails(id, reportType);

        // Guard against async gap
        if (!context.mounted) return;

        // Remove loading
        if (Navigator.canPop(context)) Navigator.pop(context);

        if (result.success && result.report != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ReportDetailScreen(report: result.report!)),
          );
        }
      } else if (type == 'news') {
        final result = await NewsService.getNewsDetail(id);

        // Guard against async gap
        if (!context.mounted) return;

        // Remove loading
        if (Navigator.canPop(context)) Navigator.pop(context);

        if (result.success && result.article != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => NewsDetailScreen(article: result.article!)),
          );
        }
      } else {
        // Remove loading
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (kDebugMode) print('Navigation error: $e');
    }
  }
}
