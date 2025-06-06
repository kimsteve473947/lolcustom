import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// FCM 토큰 관리를 위한 서비스 클래스
class FcmTokenService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// 현재 사용자의 FCM 토큰을 Firestore에 저장
  Future<void> saveToken() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('Cannot save FCM token: No user logged in');
        return;
      }
      
      // iOS에서 APNS 토큰 먼저 가져오기
      if (Platform.isIOS) {
        try {
          String? apnsToken = await _messaging.getAPNSToken();
          debugPrint('APNS Token: $apnsToken');
          
          // 토큰이 없으면 지연 후 다시 시도
          if (apnsToken == null) {
            await Future.delayed(const Duration(seconds: 2));
            apnsToken = await _messaging.getAPNSToken();
            debugPrint('APNS Token after delay: $apnsToken');
          }
        } catch (e) {
          debugPrint('Failed to get APNS token: $e');
        }
      }
      
      // FCM 토큰 가져오기
      String? token = await _messaging.getToken();
      if (token == null) {
        debugPrint('FCM token is null, retrying...');
        await Future.delayed(const Duration(seconds: 2));
        token = await _messaging.getToken();
        
        if (token == null) {
          debugPrint('Failed to get FCM token after retry');
          return;
        }
      }
      
      debugPrint('FCM Token: $token');
      await _saveTokenToFirestore(currentUser.uid, token);
    } catch (e) {
      debugPrint('Error in saveToken: $e');
    }
  }
  
  /// FCM 토큰을 Firestore에 저장하는 내부 메서드
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      // 토큰 데이터 준비
      final tokenData = {
        'token': token,
        'device': Platform.isIOS ? 'iOS' : 'Android',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0', // 앱 버전
      };
      
      // 사용자 문서가 존재하는지 확인
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        // 토큰 배열 업데이트
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 사용자 정보 가져오기
        final user = _auth.currentUser;
        if (user == null) return;
        
        // 새 사용자 문서 생성
        await _firestore.collection('users').doc(userId).set({
          'uid': userId,
          'email': user.email ?? '',
          'nickname': user.displayName ?? 'User${userId.substring(0, 4)}',
          'fcmTokens': [token],
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isPremium': false,
          'isVerified': user.emailVerified,
        });
      }
      
      // 토큰 하위 컬렉션에 저장
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .doc(token)
          .set(tokenData);
      
      debugPrint('FCM token saved successfully');
    } catch (e) {
      debugPrint('Error saving token to Firestore: $e');
    }
  }
  
  /// 토큰 갱신 리스너 설정
  void setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
      final user = _auth.currentUser;
      if (user != null) {
        _saveTokenToFirestore(user.uid, newToken);
      }
    });
  }
  
  /// 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }
  
  /// 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
  
  /// 모든 토큰 삭제 (로그아웃 시 호출)
  Future<void> deleteAllTokens() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // 현재 토큰 가져오기
      final token = await _messaging.getToken();
      if (token == null) return;
      
      // 토큰 문서 삭제
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc(token)
          .delete();
      
      // 사용자 문서에서 토큰 제거
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
      
      // FCM 토큰 삭제
      await _messaging.deleteToken();
      
      debugPrint('All FCM tokens deleted');
    } catch (e) {
      debugPrint('Error deleting FCM tokens: $e');
    }
  }
} 