import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:provider/provider.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({Key? key}) : super(key: key);

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  TournamentType _tournamentType = TournamentType.casual;
  
  // 선택한 역할 (호스트 역할)
  String _selectedRole = 'top';
  bool _isLoading = false;
  
  // 역할 정보
  final List<Map<String, dynamic>> _roles = [
    {'name': 'Top', 'icon': Icons.arrow_upward, 'color': AppColors.roleTop, 'key': 'top'},
    {'name': 'Jungle', 'icon': Icons.nature_people, 'color': AppColors.roleJungle, 'key': 'jungle'},
    {'name': 'Mid', 'icon': Icons.adjust, 'color': AppColors.roleMid, 'key': 'mid'},
    {'name': 'ADC', 'icon': Icons.gps_fixed, 'color': AppColors.roleAdc, 'key': 'adc'},
    {'name': 'Support', 'icon': Icons.shield, 'color': AppColors.roleSupport, 'key': 'support'},
  ];
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final user = appState.currentUser;
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }
      
      // 시작 시간 설정
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      // 기본 슬롯 설정 (각 역할 2명씩)
      final Map<String, int> slotsByRole = {
        'top': 2,
        'jungle': 2,
        'mid': 2,
        'adc': 2,
        'support': 2,
      };
      
      // 역할별 참가자 목록 초기화
      final Map<String, List<String>> participantsByRole = {
        'top': [],
        'jungle': [],
        'mid': [],
        'adc': [],
        'support': [],
      };
      
      // 생성자를 선택한 역할에 추가
      participantsByRole[_selectedRole]!.add(user.uid);
      
      // 역할별 채워진 슬롯 초기화
      final Map<String, int> filledSlotsByRole = {
        'top': 0,
        'jungle': 0,
        'mid': 0,
        'adc': 0,
        'support': 0,
      };
      
      // 생성자의 역할 슬롯 카운트 증가
      filledSlotsByRole[_selectedRole] = 1;
      
      // 토너먼트 모델 생성
      final tournament = TournamentModel(
        id: '',  // Firebase에서 자동 생성
        title: _titleController.text,
        description: _descriptionController.text,
        hostId: user.uid,
        hostName: user.name ?? user.email ?? '익명',
        hostNickname: user.nickname,
        hostProfileImageUrl: user.profileImageUrl,
        startsAt: Timestamp.fromDate(startDateTime),
        location: '한국 서버',
        tournamentType: _tournamentType,
        status: TournamentStatus.open,
        createdAt: DateTime.now(),
        slots: {'total': 10},  // 총 슬롯 (5 roles x 2 players)
        filledSlots: {'total': 1},  // 호스트로 1개 채워짐
        slotsByRole: slotsByRole,
        filledSlotsByRole: filledSlotsByRole,
        participants: [user.uid],  // 호스트를 참가자로 추가
        participantsByRole: participantsByRole,
        premiumBadge: false,
        gameFormat: GameFormat.single,
        gameServer: GameServer.kr,
      );
      
      // 서비스를 통해 토너먼트 생성
      final tournamentService = Provider.of<TournamentService>(context, listen: false);
      final tournamentId = await tournamentService.createTournament(tournament);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내전이 생성되었습니다')),
      );
      
      // 생성 후 상세 페이지로 이동
      if (mounted) {
        context.push('/tournaments/$tournamentId');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내전 생성 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내전 생성'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 내전 제목
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '내전 제목',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '제목을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 내전 설명
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '내전 설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '설명을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // 날짜 선택
            ListTile(
              title: const Text('날짜'),
              subtitle: Text(
                DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                style: const TextStyle(fontSize: 16),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
            ),
            const Divider(),
            
            // 시간 선택
            ListTile(
              title: const Text('시간'),
              subtitle: Text(
                _selectedTime.format(context),
                style: const TextStyle(fontSize: 16),
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectTime(context),
            ),
            const Divider(),
            
            // 내전 유형 선택 (일반전/경쟁전)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '내전 유형',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<TournamentType>(
                    title: const Text('일반전'),
                    subtitle: const Text('무료'),
                    value: TournamentType.casual,
                    groupValue: _tournamentType,
                    onChanged: (TournamentType? value) {
                      setState(() {
                        _tournamentType = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<TournamentType>(
                    title: const Text('경쟁전'),
                    subtitle: const Text('20 크레딧'),
                    value: TournamentType.competitive,
                    groupValue: _tournamentType,
                    onChanged: (TournamentType? value) {
                      setState(() {
                        _tournamentType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 호스트 역할 선택
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '나의 역할 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Text(
              '내전을 개최하면서 참가할 포지션을 선택해주세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // 역할 선택 위젯
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _roles.map((role) {
                final key = role['key'] as String;
                final isSelected = _selectedRole == key;
                
                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRole = key;
                        });
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? role['color'] as Color
                              : (role['color'] as Color).withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Icon(
                          role['icon'] as IconData,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role['name'] as String,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // 생성 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _createTournament,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('내전 생성하기', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
} 