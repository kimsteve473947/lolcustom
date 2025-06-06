import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        String? apnsToken = await _messaging.getAPNSToken();
        debugPrint('APNS Token retrieved successfully: $apnsToken');
        
        // APNS 토큰이 없는 경우 지연 후 다시 시도
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
          debugPrint('APNS Token after delay: $apnsToken');
        }
      } catch (e) {
        debugPrint('Failed to retrieve APNS Token: $e');
      }
    }
    
    // Get token
    try {
      String? token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      
      // 토큰이 없는 경우 지연 후 다시 시도
      if (token == null) {
        await Future.delayed(const Duration(seconds: 3));
        token = await _messaging.getToken();
        debugPrint('FCM Token after delay: $token');
      }
      
      // 토큰을 Firebase에 저장
      if (token != null) {
        await _saveFcmTokenToFirestore(token);
      }
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
    
    // 토큰 갱신 리스너 설정
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _saveFcmTokenToFirestore(newToken);
    });
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
  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('Cannot save FCM token: No user logged in');
        return;
      }
      
      final userId = currentUser.uid;
      final tokenData = {
        'token': token,
        'device': Platform.isIOS ? 'iOS' : 'Android',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0', // 앱 버전 정보 (나중에 동적으로 가져올 수 있음)
      };
      
      // 사용자 문서에 토큰 업데이트
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // 사용자 문서가 없는 경우 새로 생성
        if (e is FirebaseException && e.code == 'not-found') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .set({
            'uid': userId,
            'email': currentUser.email ?? '',
            'nickname': currentUser.displayName ?? 'User${userId.substring(0, 4)}',
            'fcmTokens': [token],
            'joinedAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
            'isPremium': false,
          }, SetOptions(merge: true));
          debugPrint('Created new user document with FCM token');
        } else {
          debugPrint('Error updating user with FCM token: $e');
          return;
        }
      }
      
      // 토큰 컬렉션에 토큰 정보 저장 (기기별 관리를 위해)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .doc(token)
          .set(tokenData, SetOptions(merge: true));
      
      debugPrint('FCM token saved successfully for user: $userId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
} 