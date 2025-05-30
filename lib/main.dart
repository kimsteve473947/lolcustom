import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/firebase_options.dart';
import 'package:lol_custom_game_manager/navigation/app_router.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/widgets/tournament_card_simplified.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService: AuthService()),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authService = Provider.of<AuthProvider>(context).authService;
          final appRouter = AppRouter(authService: authService);
          
          return MaterialApp.router(
            title: 'LoL 내전 매니저',
            theme: AppTheme.lightTheme,
            routerConfig: appRouter.router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LoL 내전 매니저'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '내전 목록',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TournamentCardSimplified(
              id: 'tournament1',
              title: '친목 내전 파티원 모집',
              description: '실력 무관, 재미있게 즐기실 분들 환영합니다. 5대5 내전이고 팀은 밸런스 맞춰서 랜덤으로 구성할 예정입니다.',
              hostName: '호스트1',
              date: '2023-07-15 18:00',
              location: '서울 강남구',
              isPaid: false,
              slots: {
                'top': 2,
                'jungle': 2,
                'mid': 2,
                'adc': 2,
                'support': 2,
              },
              filledSlots: {
                'top': 1,
                'jungle': 2,
                'mid': 1,
                'adc': 0,
                'support': 1,
              },
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('내전 상세 페이지로 이동합니다')),
                );
              },
            ),
            TournamentCardSimplified(
              id: 'tournament2',
              title: '골드 이상 내전',
              description: '골드 이상 랭크 보유자만 참가 가능합니다. 진지하게 게임 하실 분들 모십니다.',
              hostName: '호스트2',
              date: '2023-07-20 20:00',
              location: '서울 종로구',
              isPaid: true,
              price: 5000,
              slots: {
                'top': 2,
                'jungle': 2,
                'mid': 2,
                'adc': 2,
                'support': 2,
              },
              filledSlots: {
                'top': 2,
                'jungle': 1,
                'mid': 2,
                'adc': 1,
                'support': 0,
              },
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('내전 상세 페이지로 이동합니다')),
                );
              },
            ),
            TournamentCardSimplified(
              id: 'tournament3',
              title: '초보자 환영 내전',
              description: '롤 초보자를 위한 내전입니다. 서로 도움을 주고 받으며 실력을 향상시켜요!',
              hostName: '호스트3',
              date: '2023-07-25 19:00',
              location: '온라인',
              isPaid: false,
              slots: {
                'top': 2,
                'jungle': 2,
                'mid': 2,
                'adc': 2,
                'support': 2,
              },
              filledSlots: {
                'top': 1,
                'jungle': 0,
                'mid': 1,
                'adc': 2,
                'support': 2,
              },
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('내전 상세 페이지로 이동합니다')),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('새 내전 생성 페이지로 이동합니다')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 