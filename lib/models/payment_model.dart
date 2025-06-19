import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  initiated, // 결제 시작
  completed, // 결제 완료
  failed,    // 결제 실패
  cancelled, // 결제 취소
}

extension PaymentStatusExtension on PaymentStatus {
  static PaymentStatus fromIndex(int? index) {
    if (index == null || index < 0 || index >= PaymentStatus.values.length) {
      return PaymentStatus.initiated; // 기본값
    }
    return PaymentStatus.values[index];
  }

  static PaymentStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      case 'cancelled':
        return PaymentStatus.cancelled;
      case 'initiated':
      default:
        return PaymentStatus.initiated;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.initiated:
        return '결제 시도';
      case PaymentStatus.completed:
        return '충전 완료';
      case PaymentStatus.failed:
        return '결제 실패';
      case PaymentStatus.cancelled:
        return '결제 취소';
    }
  }
}

class PaymentModel {
  final String id;
  final String userId;
  final int amount; // 원화 금액
  final int creditAmount; // 지급될 크레딧
  final String orderId;
  final String? paymentKey; // 토스페이먼츠 결제 키
  final PaymentStatus status;
  final Timestamp createdAt;
  final Timestamp? completedAt;
  final String provider;
  final String? errorCode;
  final String? errorMessage;

  PaymentModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.creditAmount,
    required this.orderId,
    this.paymentKey,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.provider = 'toss_payments',
    this.errorCode,
    this.errorMessage,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data == null) {
        throw Exception('Payment document data is null');
      }

      // 필수 필드 검증
      final userId = data['userId'] as String?;
      final amount = data['amount'] as int?;
      final creditAmount = data['creditAmount'] as int?;
      final orderId = data['orderId'] as String?;
      final createdAt = data['createdAt'] as Timestamp?;

      if (userId == null || amount == null || creditAmount == null || 
          orderId == null || createdAt == null) {
        throw Exception('Missing required payment fields');
      }

      // status 필드 안전하게 파싱
      PaymentStatus status;
      final statusData = data['status'];
      if (statusData is int) {
        status = PaymentStatusExtension.fromIndex(statusData);
      } else if (statusData is String) {
        status = PaymentStatusExtension.fromString(statusData);
      } else {
        status = PaymentStatus.initiated; // 기본값
      }

    return PaymentModel(
      id: doc.id,
        userId: userId,
        amount: amount,
        creditAmount: creditAmount,
        orderId: orderId,
        paymentKey: data['paymentKey'] as String?,
        status: status,
        createdAt: createdAt,
        completedAt: data['completedAt'] as Timestamp?,
        provider: data['provider'] as String? ?? 'toss_payments',
        errorCode: data['errorCode'] as String?,
        errorMessage: data['errorMessage'] as String?,
    );
    } catch (e) {
      // 로깅용 - 실제 운영에서는 더 정교한 로깅 시스템 사용
      print('Error parsing PaymentModel from Firestore: $e');
      print('Document ID: ${doc.id}');
      print('Document data: ${doc.data()}');
      
      // 기본값으로 fallback 또는 재throw
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'creditAmount': creditAmount,
      'orderId': orderId,
      'paymentKey': paymentKey,
      'status': status.index,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'provider': provider,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
    };
  }

  // 결제 상태가 성공인지 확인
  bool get isCompleted => status == PaymentStatus.completed;

  // 결제 상태가 실패인지 확인
  bool get isFailed => status == PaymentStatus.failed || status == PaymentStatus.cancelled;

  // 결제가 진행 중인지 확인
  bool get isPending => status == PaymentStatus.initiated;

  // 상태 표시용 텍스트
  String get statusDisplayText => status.displayName;
}