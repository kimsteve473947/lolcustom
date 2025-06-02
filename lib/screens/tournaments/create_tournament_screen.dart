import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/tier_selector.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({Key? key}) : super(key: key);

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  TournamentType _tournamentType = TournamentType.casual;
  
  // 리그 오브 레전드 특화 필드
  GameFormat _gameFormat = GameFormat.single;
  
  // 티어 제한
  PlayerTier? _selectedTierLimit;
  
  // 라인별 인원 - 각 2명으로 고정
  final Map<String, int> _slotsByRole = {
    'top': 2,
    'jungle': 2,
    'mid': 2,
    'adc': 2,
    'support': 2,
  };
  
  bool _isLoading = false;
  
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }
  
  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    // 내전 제목이 비어있으면 기본값 설정
    if (_titleController.text.isEmpty) {
      _titleController.text = '리그 오브 레전드 내전';
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournamentId = await appState.createTournament(
        title: _titleController.text,
        location: '한국 서버', // 기본값으로 한국 서버 고정
        startsAt: _selectedDate,
        slotsByRole: _slotsByRole,
        tournamentType: _tournamentType,
        tierLimit: _selectedTierLimit,
        description: _descriptionController.text.isNotEmpty ? 
                     _descriptionController.text : '리그 오브 레전드 내전입니다',
        gameFormat: _gameFormat,
      );
      
      if (tournamentId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내전이 생성되었습니다'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Navigate to the tournament detail page
        context.push('/tournaments/$tournamentId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내전 생성에 실패했습니다'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('내전 생성 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
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
        title: const Text('내전 만들기'),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 24),
                  _buildDateTimeSection(),
                  const SizedBox(height: 24),
                  _buildGameFormatSection(),
                  const SizedBox(height: 24),
                  _buildTierLimitSection(),
                  const SizedBox(height: 24),
                  _buildPriceSection(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _createTournament,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '내전 만들기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내전 제목',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: '내전 제목을 입력하세요',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '제목을 입력하세요';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '날짜 및 시간',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '날짜',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '시간',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    DateFormat('HH:mm').format(_selectedDate),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildGameFormatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '경기 방식',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildGameFormatOption(GameFormat.single, '단판'),
            const SizedBox(width: 12),
            _buildGameFormatOption(GameFormat.bestOfThree, '3판 2선승제'),
            const SizedBox(width: 12),
            _buildGameFormatOption(GameFormat.bestOfFive, '5판 3선승제'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildGameFormatOption(GameFormat format, String label) {
    final isSelected = _gameFormat == format;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _gameFormat = format;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTierLimitSection() {
    return TierSelector(
      initialTier: _selectedTierLimit,
      onTierChanged: (tier) {
        setState(() {
          _selectedTierLimit = tier;
        });
      },
    );
  }
  
  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내전 유형',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildTournamentTypeSelector(),
        if (_tournamentType == TournamentType.competitive)
          Column(
            children: [
              const SizedBox(height: 16),
              const SizedBox(height: 8),
              const Text(
                '* 경쟁전은 참가자에게 20 크레딧을 요구합니다. 참가자는 참가 시 크레딧을 소모합니다.\n* 경쟁전은 앱 내 심판 권한이 있는 사용자가 심판을 봐주는 구조입니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
      ],
    );
  }
  
  Widget _buildTournamentTypeSelector() {
    return Row(
      children: [
        _buildTournamentTypeOption(
          TournamentType.casual, 
          '일반전', 
          '무료로 참가 가능한 일반 내전입니다.',
          Icons.sports_esports,
        ),
        const SizedBox(width: 16),
        _buildTournamentTypeOption(
          TournamentType.competitive, 
          '경쟁전', 
          '참가자는 20 크레딧을 소모하며, 심판이 배정되는 경쟁적인 내전입니다.',
          Icons.emoji_events,
        ),
      ],
    );
  }
  
  Widget _buildTournamentTypeOption(
    TournamentType type, 
    String title, 
    String description, 
    IconData icon,
  ) {
    final isSelected = _tournamentType == type;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tournamentType = type;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey.shade500,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.primary.withOpacity(0.8) : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '설명',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            hintText: '내전에 대한 추가 설명을 입력하세요',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
      ],
    );
  }
} 