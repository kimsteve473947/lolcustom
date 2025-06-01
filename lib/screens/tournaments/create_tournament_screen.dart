import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
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
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _ovrLimitController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  bool _isPaid = false;
  bool _hasPremiumBadge = false;
  
  Map<String, int> _slotsByRole = {
    'top': 2,
    'jungle': 2,
    'mid': 2,
    'adc': 2,
    'support': 2,
  };
  
  bool _isLoading = false;
  
  @override
  void dispose() {
    _locationController.dispose();
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
  
  void _updateSlots(String role, int value) {
    if (value < 0) return;
    
    setState(() {
      _slotsByRole[role] = value;
    });
  }
  
  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
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
    
    // Ensure at least one slot is available
    int totalSlots = 0;
    _slotsByRole.forEach((_, value) => totalSlots += value);
    
    if (totalSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 한 명 이상의 참가자가 필요합니다'),
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
        location: _locationController.text,
        startsAt: _selectedDate,
        slotsByRole: _slotsByRole,
        isPaid: _isPaid,
        price: _isPaid ? int.parse(_priceController.text) : null,
        ovrLimit: _ovrLimitController.text.isNotEmpty ? int.parse(_ovrLimitController.text) : null,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        premiumBadge: _hasPremiumBadge,
        // TODO: Add location coordinates
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
                  _buildDateTimeSection(),
                  const SizedBox(height: 24),
                  _buildLocationSection(),
                  const SizedBox(height: 24),
                  _buildSlotsSection(),
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
                    labelText: '날짜',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selectedDate),
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
                    labelText: '시간',
                    prefixIcon: Icon(Icons.access_time),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedTime.format(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '장소',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: '장소 이름',
            hintText: '예) 민락 체육공원 축구장',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '장소를 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement location picker
          },
          icon: const Icon(Icons.map),
          label: const Text('지도에서 선택하기'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSlotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '포지션별 인원',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildRoleSlotSelector('Top', 'top', AppColors.roleTop),
            const SizedBox(width: 8),
            _buildRoleSlotSelector('Jungle', 'jungle', AppColors.roleJungle),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRoleSlotSelector('Mid', 'mid', AppColors.roleMid),
            const SizedBox(width: 8),
            _buildRoleSlotSelector('ADC', 'adc', AppColors.roleAdc),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRoleSlotSelector('Support', 'support', AppColors.roleSupport),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '총 ${_slotsByRole.values.fold(0, (prev, curr) => prev + curr)}명',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRoleSlotSelector(String label, String role, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _updateSlots(role, _slotsByRole[role]! - 1),
                  color: color,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_slotsByRole[role]}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _updateSlots(role, _slotsByRole[role]! + 1),
                  color: color,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '참가비 및 제한',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('유료 내전'),
          subtitle: const Text('참가비를 받아요'),
          value: _isPaid,
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool value) {
            setState(() {
              _isPaid = value;
              if (!value) {
                _priceController.clear();
              }
            });
          },
        ),
        if (_isPaid)
          TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: '참가비 (원)',
              hintText: '예) 10000',
              prefixIcon: Icon(Icons.monetization_on),
              border: OutlineInputBorder(),
              suffixText: '원',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (_isPaid && (value == null || value.isEmpty)) {
                return '참가비를 입력해주세요';
              }
              return null;
            },
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ovrLimitController,
          decoration: const InputDecoration(
            labelText: 'OVR 제한 (선택사항)',
            hintText: '예) 75',
            prefixIcon: Icon(Icons.fitness_center),
            border: OutlineInputBorder(),
            helperText: '이 OVR 이상만 참가할 수 있어요',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ],
    );
  }
  
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내전 소개',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '내전 소개 (선택사항)',
            hintText: '내전에 대한 추가 정보를 알려주세요',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
      ],
    );
  }
  
  Widget _buildPremiumSection() {
    // Get current user
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    
    // If user is not premium, show upgrade message
    if (user != null && !user.isPremium) {
      return Card(
        color: Colors.amber.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: Colors.amber,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '프리미엄 배지',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '프리미엄 멤버가 되어 내전을 상단에 노출시키고 더 많은 참가자를 모집하세요!',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to premium subscription page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                ),
                child: const Text('프리미엄 멤버 되기'),
              ),
            ],
          ),
        ),
      );
    }
    
    // If user is premium, show premium badge option
    return SwitchListTile(
      title: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          const Text(
            '프리미엄 배지',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (user?.isPremium ?? false)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
        ],
      ),
      subtitle: const Text('내전 목록에서 상단에 노출됩니다'),
      value: _hasPremiumBadge,
      activeColor: Colors.amber,
      contentPadding: EdgeInsets.zero,
      onChanged: (user?.isPremium ?? false)
          ? (bool value) {
              setState(() {
                _hasPremiumBadge = value;
              });
            }
          : null,
    );
  }
} 