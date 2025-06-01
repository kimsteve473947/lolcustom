import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
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
  final _customRoomNameController = TextEditingController();
  final _customRoomPasswordController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _ovrLimitController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  bool _isPaid = false;
  bool _hasPremiumBadge = false;
  
  // 리그 오브 레전드 특화 필드
  GameFormat _gameFormat = GameFormat.single;
  GameServer _gameServer = GameServer.kr;
  
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
    _customRoomNameController.dispose();
    _customRoomPasswordController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _ovrLimitController.dispose();
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
    
    // If tournament is paid, ensure price is set
    if (_isPaid && (_priceController.text.isEmpty || int.parse(_priceController.text) <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('유료 내전인 경우 참가비를 입력해주세요'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tournamentId = await appState.createTournament(
        title: _titleController.text,
        location: LolGameServers.names[_gameServer] ?? '한국 서버',
        startsAt: _selectedDate,
        slotsByRole: _slotsByRole,
        isPaid: _isPaid,
        price: _isPaid ? int.parse(_priceController.text) : null,
        ovrLimit: _ovrLimitController.text.isNotEmpty ? int.parse(_ovrLimitController.text) : null,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : '리그 오브 레전드 내전입니다',
        premiumBadge: _hasPremiumBadge,
        gameFormat: _gameFormat,
        gameServer: _gameServer,
        customRoomName: _customRoomNameController.text.isNotEmpty ? _customRoomNameController.text : null,
        customRoomPassword: _customRoomPasswordController.text.isNotEmpty ? _customRoomPasswordController.text : null,
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
                  _buildGameServerSection(),
                  const SizedBox(height: 24),
                  _buildCustomRoomSection(),
                  const SizedBox(height: 24),
                  _buildPriceSection(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 24),
                  _buildPremiumSection(),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _createTournament,
                    child: const Text('내전 만들기'),
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
  
  Widget _buildGameServerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '게임 서버',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<GameServer>(
              value: _gameServer,
              isExpanded: true,
              items: GameServer.values.map((server) {
                return DropdownMenuItem<GameServer>(
                  value: server,
                  child: Text(LolGameServers.names[server] ?? '한국 서버'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _gameServer = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCustomRoomSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '커스텀 방 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '커스텀 방 이름과 비밀번호는 내전 시작 전까지 입력하지 않아도 됩니다',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _customRoomNameController,
          decoration: const InputDecoration(
            labelText: '커스텀 방 이름',
            hintText: '예: 내전방123',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customRoomPasswordController,
          decoration: const InputDecoration(
            labelText: '커스텀 방 비밀번호',
            hintText: '예: 1234',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '참가비',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('참가비 내전'),
          subtitle: const Text('참가자들로부터 참가비를 받습니다'),
          value: _isPaid,
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _isPaid = value;
            });
          },
        ),
        if (_isPaid)
          Column(
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: '참가비 (원)',
                  border: OutlineInputBorder(),
                  prefixText: '₩ ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (_isPaid && (value == null || value.isEmpty)) {
                    return '참가비를 입력하세요';
                  }
                  return null;
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
        const Text(
          '실력 제한',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ovrLimitController,
          decoration: const InputDecoration(
            labelText: '티어 제한 (없으면 비워두세요)',
            border: OutlineInputBorder(),
            hintText: '예: 골드 이상, 플래티넘 이하 등',
          ),
        ),
      ],
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
  
  Widget _buildPremiumSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '프리미엄 내전',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('프리미엄 내전 배지'),
          subtitle: const Text('프리미엄 배지로 내전을 더 돋보이게 합니다'),
          value: _hasPremiumBadge,
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _hasPremiumBadge = value;
            });
          },
        ),
      ],
    );
  }
} 