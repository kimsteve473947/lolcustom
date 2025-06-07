import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/services/firebase_messaging_service.dart';

class FCMTestScreen extends StatefulWidget {
  const FCMTestScreen({Key? key}) : super(key: key);

  @override
  State<FCMTestScreen> createState() => _FCMTestScreenState();
}

class _FCMTestScreenState extends State<FCMTestScreen> {
  String _fcmToken = 'Loading...';
  String _notificationStatus = '';
  
  @override
  void initState() {
    super.initState();
    _loadFCMToken();
  }
  
  Future<void> _loadFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token ?? 'Token not available';
      });
    } catch (e) {
      setState(() {
        _fcmToken = 'Error loading token: $e';
      });
    }
  }
  
  Future<void> _sendTestNotification() async {
    try {
      final messagingService = Provider.of<FirebaseMessagingService>(context, listen: false);
      
      await messagingService.showLocalNotification(
        title: 'Test Notification',
        body: 'This is a test notification from FCM Test Screen',
        channelId: 'main_channel',
        payload: '{"type":"test","message":"test notification"}',
      );
      
      setState(() {
        _notificationStatus = '✅ 로컬 알림이 전송되었습니다.';
      });
    } catch (e) {
      setState(() {
        _notificationStatus = '❌ 알림 전송 오류: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM 알림 테스트'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM 토큰',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _fcmToken,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _fcmToken));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('토큰이 클립보드에 복사되었습니다')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadFCMToken,
                      icon: const Icon(Icons.refresh),
                      label: const Text('토큰 새로고침'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '로컬 알림 테스트',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _sendTestNotification,
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('테스트 알림 보내기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_notificationStatus.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _notificationStatus,
                        style: TextStyle(
                          color: _notificationStatus.contains('❌') 
                              ? Colors.red 
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firebase Console에서 테스트하기',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Firebase Console의 Messaging 메뉴로 이동\n'
                      '2. \'첫 번째 캠페인 보내기\' 클릭\n'
                      '3. 알림 제목과 텍스트 입력\n'
                      '4. 테스트 메시지 보내기 선택\n'
                      '5. 위에 표시된 FCM 토큰 입력 후 테스트\n',
                      style: TextStyle(
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 