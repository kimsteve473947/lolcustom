import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/models/payment_model.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';

class CreditHistoryTab extends StatefulWidget {
  const CreditHistoryTab({Key? key}) : super(key: key);

  @override
  State<CreditHistoryTab> createState() => _CreditHistoryTabState();
}

class _CreditHistoryTabState extends State<CreditHistoryTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId != null) {
      _historyStream = FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      _historyStream = const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    
    if (!authProvider.isLoggedIn) {
      return _buildLoginRequiredState(context);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return _buildErrorState(
            '크레딧 내역을 불러오는 중 오류가 발생했습니다.',
            '잠시 후 다시 시도해주세요.',
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context);
        }

        final payments = snapshot.data!.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: payments.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final payment = payments[index];
            return _buildHistoryCard(payment);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(PaymentModel payment) {
    final statusInfo = _getStatusInfo(payment.status);
    final formattedDate = payment.createdAt != null
        ? DateFormat('yyyy.MM.dd HH:mm').format(payment.createdAt!.toDate())
        : '날짜 정보 없음';

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.lightGrey, width: 1),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusInfo['color']!.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getStatusIcon(payment.status),
                          color: statusInfo['color'],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${NumberFormat.decimalPattern().format(payment.creditAmount)} C 충전',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusInfo['color']!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusInfo['color']!.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    payment.statusDisplayText,
                    style: TextStyle(
                      color: statusInfo['color'],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.payment_outlined,
                    '결제 금액',
                    '₩${NumberFormat.decimalPattern().format(payment.amount)}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.receipt_long_outlined,
                    '주문번호',
                    payment.orderId,
                  ),
                  if (payment.paymentKey != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.key_outlined,
                      '결제키',
                      payment.paymentKey!.length > 20 
                          ? '${payment.paymentKey!.substring(0, 20)}...'
                          : payment.paymentKey!,
                    ),
                  ],
                  if (payment.errorMessage != null && payment.isFailed) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.error_outline,
                      '오류 메시지',
                      payment.errorMessage!,
                      isError: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value, {bool isError = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isError ? AppColors.error : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: TextStyle(
            color: isError ? AppColors.error : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isError ? AppColors.error : AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            '크레딧 결제 내역이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '크레딧을 충전하여 다양한 게임 서비스를\n이용해보세요!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.go('/mypage/credit-charge');
            },
            icon: const Icon(Icons.monetization_on_outlined),
            label: const Text('크레딧 충전하기'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String title, String subtitle) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                // 위젯 재빌드를 통한 재시도
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRequiredState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: AppColors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            '로그인이 필요합니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '크레딧 내역을 확인하려면 로그인해주세요.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login),
            label: const Text('로그인하기'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return Icons.check_circle_outline;
      case PaymentStatus.failed:
        return Icons.error_outline;
      case PaymentStatus.initiated:
        return Icons.hourglass_empty_outlined;
      case PaymentStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Map<String, dynamic> _getStatusInfo(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return {'text': '충전 완료', 'color': AppColors.success};
      case PaymentStatus.failed:
        return {'text': '결제 실패', 'color': AppColors.error};
      case PaymentStatus.initiated:
        return {'text': '결제 시도', 'color': AppColors.warning};
      case PaymentStatus.cancelled:
        return {'text': '결제 취소', 'color': AppColors.grey};
      default:
        return {'text': '알 수 없음', 'color': AppColors.grey};
    }
  }
}