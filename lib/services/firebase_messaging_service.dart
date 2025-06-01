import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Method to initialize Firebase Messaging
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    debugPrint('User granted permission: ${settings.authorizationStatus}');
    
    // iOS에서 APNS 토큰 가져오기 (iOS 특화 문제 해결)
    if (Platform.isIOS) {
      try {
        // APNS 토큰을 먼저 확인
        await _messaging.getAPNSToken();
        debugPrint('APNS Token retrieved successfully');
      } catch (e) {
        debugPrint('Failed to retrieve APNS Token: $e');
      }
    }
    
    // Get token
    try {
      String? token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
    
    // Setup local notifications for Android
    if (Platform.isAndroid) {
      await _setupLocalNotifications();
    } else if (Platform.isIOS) {
      await _setupIOSNotifications();
    }
    
    // Set up message handlers
    _setupMessageHandlers();
  }
  
  // Method to setup local notifications for Android
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification clicked: ${details.payload}');
        // Handle notification click
        _handleNotificationClick(details.payload);
      },
    );
    
    // Create notification channels for Android
    const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
      'main_channel',
      'Main Notifications',
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
    );
    
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(mainChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);
  }
  
  // iOS 특화 알림 설정
  Future<void> _setupIOSNotifications() async {
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification clicked: ${details.payload}');
        // Handle notification click
        _handleNotificationClick(details.payload);
      },
    );
  }
  
  // Method to setup message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });
    
    // Message clicked when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      _handleNotificationClick(jsonEncode(message.data));
    });
  }
  
  // Method to show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final AndroidNotification? android = message.notification?.android;
    
    if (notification != null && android != null && !kIsWeb && Platform.isAndroid) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            message.data['channel_id'] ?? 'main_channel',
            message.data['channel_name'] ?? 'Main Notifications',
            icon: android.smallIcon,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }
  
  // Method to handle notification click
  void _handleNotificationClick(String? payload) {
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final type = data['type'];
        
        switch (type) {
          case 'tournament':
            final tournamentId = data['tournament_id'];
            debugPrint('Navigate to tournament: $tournamentId');
            // TODO: Implement navigation
            break;
          case 'chat':
            final chatId = data['chat_id'];
            debugPrint('Navigate to chat: $chatId');
            // TODO: Implement navigation
            break;
          default:
            debugPrint('Unknown notification type: $type');
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }
  
  // Method to subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }
  
  // Method to unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
  
  // Method to save FCM token to the database
  Future<void> saveFcmToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      // TODO: Save token to Firestore
      debugPrint('Saving FCM token for user: $userId');
    }
  }
} 