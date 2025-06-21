import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _baseUrl = 'https://us-central1-lolcustom-3d471.cloudfunctions.net';

  // 결제 생성 함수 호출
  Future<String?> createPayment({
    required int amount,
    required int creditAmount,
  }) async {
    try {
      // 현재 사용자 확인
      final currentUser = _auth.currentUser;
      debugPrint('PaymentService.createPayment - Current user: ${currentUser?.email} (${currentUser?.uid})');
      
      if (currentUser == null) {
        debugPrint('PaymentService.createPayment - No user logged in');
        throw Exception('로그인이 필요합니다.');
      }

      // ID 토큰 강제 새로고침
      final idToken = await currentUser.getIdToken(true);
      debugPrint('PaymentService.createPayment - ID Token obtained: ${idToken != null}');

      // HTTP 요청 보내기
      final response = await http.post(
        Uri.parse('$_baseUrl/createPayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'amount': amount,
          'creditAmount': creditAmount,
        }),
      );

      debugPrint('PaymentService.createPayment - Response status: ${response.statusCode}');
      debugPrint('PaymentService.createPayment - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('PaymentService.createPayment - Success: ${responseData['orderId']}');
          return responseData['orderId'];
        } else {
          throw Exception(responseData['error'] ?? '결제 생성에 실패했습니다.');
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('PaymentService.createPayment - Error: $e');
      return null;
    }
  }

  // 결제 승인 함수 호출
  Future<bool> approvePayment({
    required String orderId,
    required String paymentKey,
    required int amount,
  }) async {
    try {
      // 현재 사용자 확인
      final currentUser = _auth.currentUser;
      debugPrint('PaymentService.approvePayment - Current user: ${currentUser?.email} (${currentUser?.uid})');
      
      if (currentUser == null) {
        debugPrint('PaymentService.approvePayment - No user logged in');
        throw Exception('로그인이 필요합니다.');
      }

      // ID 토큰 강제 새로고침
      final idToken = await currentUser.getIdToken(true);
      debugPrint('PaymentService.approvePayment - ID Token obtained: ${idToken != null}');

      // HTTP 요청 보내기
      final response = await http.post(
        Uri.parse('$_baseUrl/approvePayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'orderId': orderId,
          'paymentKey': paymentKey,
          'amount': amount,
        }),
      );

      debugPrint('PaymentService.approvePayment - Response status: ${response.statusCode}');
      debugPrint('PaymentService.approvePayment - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        debugPrint('PaymentService.approvePayment - Success: ${responseData['success']}');
        return responseData['success'] ?? false;
      } else {
        debugPrint('PaymentService.approvePayment - HTTP Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('PaymentService.approvePayment - Error: $e');
      return false;
    }
  }
}
