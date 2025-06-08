import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 싱글톤 패턴 구현
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  
  // 팩토리 생성자
  factory FirebaseMessagingService() {
    return _instance;
  }
  
  // 내부 생성자
  FirebaseMessagingService._internal();
  
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
      
      // FCM 토큰 콘솔에 출력 (디버깅 및 테스트용)
      debugPrint('==================== FCM TOKEN ====================');
      debugPrint('FCM Token: $token');
      debugPrint('===================================================');
      
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
    
    const AndroidNotificationChannel tournamentChannel = AndroidNotificationChannel(
      'tournament_channel',
      'Tournament Notifications',
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
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(tournamentChannel);
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
    
    // Background message handling
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  // Method to show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final AndroidNotification? android = message.notification?.android;
    
    if (notification != null && !kIsWeb) {
      String channelId = 'main_channel';
      String channelName = 'Main Notifications';
      
      // 알림 타입에 따라 채널 설정
      if (message.data.containsKey('type')) {
        final type = message.data['type'];
        if (type == 'chat') {
          channelId = 'chat_channel';
          channelName = 'Chat Notifications';
        } else if (type == 'tournament') {
          channelId = 'tournament_channel';
          channelName = 'Tournament Notifications';
        }
      }
      
      // Android 디바이스에서 알림 표시
      if (Platform.isAndroid) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              icon: android?.smallIcon,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      } 
      // iOS 디바이스에서 알림 표시
      else if (Platform.isIOS) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    }
  }
  
  // Method to handle notification click
  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      if (data.containsKey('type')) {
        final type = data['type'];
        
        if (type == 'chat') {
          final chatId = data['chat_id'];
          debugPrint('Navigate to chat: $chatId');
          // 여기서 채팅 화면으로 이동하는 로직을 구현합니다.
          // 실제 구현에서는 GlobalKey<NavigatorState>나 GoRouter 같은 라우팅 시스템을 사용해야 합니다.
        } else if (type == 'tournament') {
          final tournamentId = data['tournament_id'];
          debugPrint('Navigate to tournament: $tournamentId');
          // 여기서 토너먼트 화면으로 이동하는 로직을 구현합니다.
        }
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('User not logged in, skipping FCM token save');
        return;
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final tokens = List<String>.from(userData['fcmTokens'] ?? []);
        
        // 중복 토큰 방지
        if (!tokens.contains(token)) {
          tokens.add(token);
          await _firestore.collection('users').doc(user.uid).update({
            'fcmTokens': tokens,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM token saved to Firestore for user ${user.uid}');
        } else {
          debugPrint('FCM token already exists in Firestore for user ${user.uid}');
        }
      } else {
        // 사용자 문서가 없는 경우, 새로 생성
        await _firestore.collection('users').doc(user.uid).set({
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('Created new FCM token entry for user ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }
  
  // 사용자에게 로컬 알림 전송
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'main_channel',
  }) async {
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'chat_channel' ? 'Chat Notifications' : 
      channelId == 'tournament_channel' ? 'Tournament Notifications' : 'Main Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
  
  // 토너먼트 알림 전송 (내부적으로는 클라우드 함수를 호출하거나 서버를 통해 전송해야 함)
  Future<void> sendTournamentNotification({
    required String tournamentId,
    required String title,
    required String body,
    required List<String> userIds,
  }) async {
    // 실제 프로덕션에서는 이 메서드를 통해 클라우드 함수를 호출합니다.
    // 현재는 로컬 알림만 전송합니다.
    
    // 현재 로그인한 사용자에게만 로컬 알림 전송
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && userIds.contains(currentUser.uid)) {
      await showLocalNotification(
        title: title,
        body: body,
        channelId: 'tournament_channel',
        payload: jsonEncode({
          'type': 'tournament',
          'tournament_id': tournamentId,
        }),
      );
    }
    
    // 서버 측 구현이 있다면 아래와 같이 API 호출을 할 수 있습니다.
    // 보안상의 이유로 클라이언트에서 직접 FCM API를 호출하지 않습니다.
    // await _callCloudFunction('sendTournamentNotification', {
    //   'tournamentId': tournamentId,
    //   'title': title,
    //   'body': body,
    //   'userIds': userIds,
    // });
    
    debugPrint('Tournament notification sent to ${userIds.length} users');
  }
  
  // 채팅 알림 전송
  Future<void> sendChatNotification({
    required String chatRoomId,
    required String title,
    required String body,
    required List<String> userIds,
  }) async {
    // 실제 프로덕션에서는 이 메서드를 통해 클라우드 함수를 호출합니다.
    // 현재는 로컬 알림만 전송합니다.
    
    // 현재 로그인한 사용자에게만 로컬 알림 전송
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && userIds.contains(currentUser.uid)) {
      await showLocalNotification(
        title: title,
        body: body,
        channelId: 'chat_channel',
        payload: jsonEncode({
          'type': 'chat',
          'chat_id': chatRoomId,
        }),
      );
    }
    
    debugPrint('Chat notification sent to ${userIds.length} users');
  }
  
  // 특정 사용자에게 알림 전송
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    // 실제 프로덕션에서는 이 메서드를 통해 클라우드 함수를 호출합니다.
    // 현재는 로컬 알림만 전송합니다.
    
    // 현재 로그인한 사용자에게만 로컬 알림 전송
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && userId == currentUser.uid) {
      String channelId = 'main_channel';
      if (type == 'chat') {
        channelId = 'chat_channel';
      } else if (type == 'tournament') {
        channelId = 'tournament_channel';
      }
      
      await showLocalNotification(
        title: title,
        body: body,
        channelId: channelId,
        payload: data != null ? jsonEncode(data) : null,
      );
    }
    
    debugPrint('Notification sent to user: $userId');
  }
}

// 백그라운드 메시지 처리 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 메시지를 처리하는 로직
  // 이 함수는 앱이 백그라운드에 있을 때 호출됩니다.
  debugPrint('Handling a background message: ${message.messageId}');
} 