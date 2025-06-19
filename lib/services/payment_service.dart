import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // 결제 생성 함수 호출
  Future<String?> createPayment({
    required int amount,
    required int creditAmount,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('createPayment');
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'creditAmount': creditAmount,
      });
      return result.data['orderId'];
    } on FirebaseFunctionsException catch (e) {
      print('Error calling createPayment: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('Unknown error in createPayment: $e');
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
      final HttpsCallable callable = _functions.httpsCallable('approvePayment');
      final result = await callable.call<Map<String, dynamic>>({
        'orderId': orderId,
        'paymentKey': paymentKey,
        'amount': amount, // 서버에서 한번 더 검증하기 위해 금액을 함께 보냅니다.
      });
      return result.data['success'] ?? false;
    } on FirebaseFunctionsException catch (e) {
      print('Error calling approvePayment: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Unknown error in approvePayment: $e');
      return false;
    }
  }
}