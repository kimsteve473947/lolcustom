import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/payment_service.dart';
import 'package:lol_custom_game_manager/screens/my_page/toss_payment_webview_screen.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class CreditChargeScreen extends StatefulWidget {
  const CreditChargeScreen({Key? key}) : super(key: key);

  @override
  State<CreditChargeScreen> createState() => _CreditChargeScreenState();
}

class _CreditChargeScreenState extends State<CreditChargeScreen> {
  final PaymentService _paymentService = PaymentService();
  // 사용자에게 받은 테스트 클라이언트 키
  final String _tossClientKey = 'test_ck_Poxy1XQL8RJo12Y4P0eN87nO5Wml';

  int _selectedAmount = 1000;
  bool _isLoading = false;

  final List<int> _chargeOptions = [1000, 5000, 10000, 30000, 50000];

  Future<void> _handlePayment() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final user = Provider.of<AppStateProvider>(context, listen: false).currentUser;
    if (user == null) {
      _showErrorDialog('사용자 정보를 찾을 수 없습니다.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. 서버에 결제 정보 생성을 요청하고 orderId를 받습니다.
      final orderId = await _paymentService.createPayment(
        amount: _selectedAmount,
        creditAmount: _selectedAmount, // 1원 = 1크레딧으로 가정
      );

      if (orderId == null) {
        throw Exception('결제 정보를 생성하지 못했습니다.');
      }

      // 2. 웹뷰를 통해 토스 결제창을 띄웁니다.
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TossPaymentWebviewScreen(
            clientKey: _tossClientKey,
            orderId: orderId,
            orderName: '${_selectedAmount} 크레딧 충전',
            amount: _selectedAmount.toDouble(),
            customerName: user.nickname,
            customerEmail: user.email,
          ),
        ),
      ) as Map<String, dynamic>?;

      // 3. 웹뷰로부터 결제 결과를 받아 처리합니다.
      if (result == null || result['success'] != true) {
        throw Exception(result?['errorMessage'] ?? '결제가 취소되거나 실패했습니다.');
      }

      final paymentKey = result['paymentKey'];
      final returnedOrderId = result['orderId'];
      final returnedAmount = double.tryParse(result['amount'] ?? '0');

      if (paymentKey == null || returnedOrderId != orderId || returnedAmount != _selectedAmount) {
        throw Exception('결제 정보가 일치하지 않습니다.');
      }

      // 4. 서버에 결제 승인을 요청합니다.
      final bool isApproved = await _paymentService.approvePayment(
        orderId: orderId,
        paymentKey: paymentKey,
        amount: _selectedAmount,
      );

      if (isApproved) {
        await _showSuccessDialog();
        // 사용자 정보 갱신 및 화면 닫기
        await Provider.of<AppStateProvider>(context, listen: false).syncCurrentUser();
        if (mounted) Navigator.of(context).pop();
      } else {
        throw Exception('최종 결제 승인에 실패했습니다.');
      }
    } catch (e) {
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결제 성공'),
        content: Text('${NumberFormat.decimalPattern().format(_selectedAmount)} 크레딧이 성공적으로 충전되었습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결제 오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateProvider>(context).currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('크레딧 충전'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentCredits(user),
            const SizedBox(height: 30),
            _buildChargeOptions(),
            const SizedBox(height: 30),
            _buildSummary(),
            const SizedBox(height: 40),
            _buildChargeButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentCredits(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('현재 보유 크레딧', style: TextStyle(fontSize: 16, color: Colors.black54)),
          Text(
            '${NumberFormat.decimalPattern().format(user.credits)} C',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildChargeOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('충전 금액 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _chargeOptions.map((amount) {
            final isSelected = _selectedAmount == amount;
            return ChoiceChip(
              label: Text('${NumberFormat.decimalPattern().format(amount)} C'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedAmount = amount;
                  });
                }
              },
              backgroundColor: Colors.grey[200],
              selectedColor: AppColors.primary.withOpacity(0.8),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('선택한 충전 크레딧', style: TextStyle(fontSize: 16)),
                Text(
                  '${NumberFormat.decimalPattern().format(_selectedAmount)} C',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('결제 예정 금액', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '₩${NumberFormat.decimalPattern().format(_selectedAmount)}', // 1 크레딧 = 1원으로 가정
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargeButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handlePayment,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            )
          : Text('${NumberFormat.decimalPattern().format(_selectedAmount)}원 결제하기'),
    );
  }
}