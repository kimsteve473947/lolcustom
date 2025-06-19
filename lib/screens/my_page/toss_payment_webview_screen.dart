import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class TossPaymentWebviewScreen extends StatefulWidget {
  final String clientKey;
  final String orderId;
  final String orderName;
  final double amount;
  final String customerName;
  final String customerEmail;

  const TossPaymentWebviewScreen({
    Key? key,
    required this.clientKey,
    required this.orderId,
    required this.orderName,
    required this.amount,
    required this.customerName,
    required this.customerEmail,
  }) : super(key: key);

  @override
  State<TossPaymentWebviewScreen> createState() => _TossPaymentWebviewScreenState();
}

class _TossPaymentWebviewScreenState extends State<TossPaymentWebviewScreen> {
  late final WebViewController _controller;
  bool _isPaymentFinished = false;
  bool _isLoading = true;
  String? _errorMessage;

  // 앱 전용 커스텀 스킴 사용
  static const String _appScheme = 'lolcustomgame';
  static const String _successUrl = '$_appScheme://payment/success';
  static const String _failUrl = '$_appScheme://payment/fail';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15')
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _errorMessage = '페이지 로드 중 오류가 발생했습니다: ${error.description}';
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              if (request.url.startsWith(_successUrl)) {
                _handlePaymentResult(request.url, true);
                return NavigationDecision.prevent;
              } else if (request.url.startsWith(_failUrl)) {
                _handlePaymentResult(request.url, false);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );

      _loadPaymentPage();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '결제 화면을 초기화하는 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _loadPaymentPage() async {
    try {
      final htmlContent = _generatePaymentHtml(
        clientKey: widget.clientKey,
        orderId: widget.orderId,
        orderName: widget.orderName,
        amount: widget.amount,
        customerName: widget.customerName,
        customerEmail: widget.customerEmail,
        successUrl: _successUrl,
        failUrl: _failUrl,
      );

      await _controller.loadHtmlString(htmlContent);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '결제 페이지를 로드하는 중 오류가 발생했습니다: $e';
      });
    }
  }

  void _handlePaymentResult(String url, bool isSuccess) {
    if (_isPaymentFinished) return;
    _isPaymentFinished = true;

    try {
      final uri = Uri.parse(url);
      final result = <String, dynamic>{
        'success': isSuccess,
        'orderId': uri.queryParameters['orderId'],
        'paymentKey': uri.queryParameters['paymentKey'],
        'amount': uri.queryParameters['amount'],
        'errorCode': uri.queryParameters['code'],
        'errorMessage': uri.queryParameters['message'],
      };

      // 필수 데이터 검증 (성공 시에만)
      if (isSuccess) {
        if (result['orderId'] == null || result['paymentKey'] == null || result['amount'] == null) {
          result['success'] = false;
          result['errorMessage'] = '결제 응답 데이터가 올바르지 않습니다.';
        }
      }

      Navigator.of(context).pop(result);
    } catch (e) {
      Navigator.of(context).pop({
        'success': false,
        'errorMessage': '결제 결과를 처리하는 중 오류가 발생했습니다: $e',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '토스페이먼츠 결제',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => _handleCancel(),
        ),
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            _buildErrorWidget()
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '결제 화면을 준비하고 있습니다...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: 24),
              Text(
                '오류가 발생했습니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? '알 수 없는 오류가 발생했습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _loadPaymentPage();
                      },
                      child: const Text('다시 시도'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCancel() {
    if (_isPaymentFinished) return;
    _isPaymentFinished = true;
    
    Navigator.of(context).pop({
      'success': false,
      'errorMessage': '사용자가 결제를 취소했습니다.',
    });
  }

  String _generatePaymentHtml({
    required String clientKey,
    required String orderId,
    required String orderName,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String successUrl,
    required String failUrl,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Toss Payments</title>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <script src="https://js.tosspayments.com/v1"></script>
      <style>
        body { 
          margin: 0; 
          padding: 20px; 
          font-family: -apple-system, BlinkMacSystemFont, sans-serif;
          background-color: #f8f9fa;
        }
        .container {
          max-width: 400px;
          margin: 50px auto;
          padding: 20px;
          background: white;
          border-radius: 12px;
          box-shadow: 0 2px 12px rgba(0,0,0,0.1);
        }
        .loading {
          text-align: center;
          color: #666;
        }
        .error {
          color: #e74c3c;
          text-align: center;
          padding: 20px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="loading">결제를 준비하고 있습니다...</div>
      </div>
      
      <script>
        try {
          var tossPayments = TossPayments('$clientKey');
          
          // 결제 요청
          tossPayments.requestPayment('카드', {
            amount: $amount,
            orderId: '$orderId',
            orderName: '$orderName',
            customerName: '$customerName',
            customerEmail: '$customerEmail',
            successUrl: '$successUrl',
            failUrl: '$failUrl'
          }).catch(function (error) {
            console.error('Payment error:', error);
            
            var errorUrl = '$failUrl?code=' + encodeURIComponent(error.code || 'UNKNOWN_ERROR') + 
                          '&message=' + encodeURIComponent(error.message || '알 수 없는 오류가 발생했습니다.');
            
            // 에러 처리
            if (error.code === 'USER_CANCEL') {
              window.location.href = errorUrl;
            } else {
              // 기타 에러
              document.body.innerHTML = '<div class="container"><div class="error">결제 중 오류가 발생했습니다: ' + 
                                       (error.message || '알 수 없는 오류') + '</div></div>';
              setTimeout(function() {
                window.location.href = errorUrl;
              }, 3000);
            }
          });
        } catch (e) {
          console.error('Script error:', e);
          document.body.innerHTML = '<div class="container"><div class="error">결제 시스템을 초기화할 수 없습니다.</div></div>';
          setTimeout(function() {
            window.location.href = '$failUrl?code=INIT_ERROR&message=' + encodeURIComponent('결제 시스템 초기화 실패');
          }, 3000);
        }
      </script>
    </body>
    </html>
    ''';
  }
}