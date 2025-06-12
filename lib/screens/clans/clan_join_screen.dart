import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:cloud_firestore/cloud_firestore.dart';

class ClanJoinScreen extends StatefulWidget {
  final String clanId;
  
  const ClanJoinScreen({
    Key? key,
    required this.clanId,
  }) : super(key: key);

  @override
  State<ClanJoinScreen> createState() => _ClanJoinScreenState();
}

class _ClanJoinScreenState extends State<ClanJoinScreen> {
  final ClanService _clanService = ClanService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  ClanModel? _clan;
  
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _positionController = TextEditingController();
  final _experienceController = TextEditingController();
  final _contactInfoController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadClanData();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _positionController.dispose();
    _experienceController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }
  
  Future<void> _loadClanData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final clan = await _clanService.getClan(widget.clanId);
      
      if (mounted) {
        setState(() {
          _clan = clan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 정보를 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
  
  Future<void> _submitApplication() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final success = await _clanService.applyToClan(
        clanId: widget.clanId,
        message: _messageController.text,
        position: _positionController.text,
        experience: _experienceController.text,
        contactInfo: _contactInfoController.text,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('클랜 가입 신청이 완료되었습니다')),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('클랜 가입 신청 중 오류가 발생했습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 가입 신청'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clan == null
              ? const Center(child: Text('클랜 정보를 찾을 수 없습니다'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 클랜 정보 섹션
                      _buildClanInfoSection(),
                      
                      const SizedBox(height: 24),
                      
                      // 로그인 확인
                      if (!isLoggedIn)
                        _buildLoginRequiredSection()
                      else
                        _buildApplicationForm(),
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildClanInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildClanEmblem(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _clan!.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '멤버: ${_clan!.memberCount}/${_clan!.maxMembers}명',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // 주요 정보
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('멤버', '${_clan!.memberCount}/${_clan!.maxMembers}명'),
              _buildInfoRow('활동 요일', _formatActivityDays()),
              _buildInfoRow('활동 시간대', _formatActivityTimes()),
              _buildInfoRow('주요 나이대', _formatAgeGroups()),
              _buildInfoRow('성별', _formatGender()),
              _buildInfoRow('팀 성향', _formatFocus()),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        if (_clan!.description != null && _clan!.description!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '클랜 소개',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _clan!.description!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
            ],
          ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClanEmblem() {
    if (_clan!.emblem is String && (_clan!.emblem as String).startsWith('http')) {
      // 이미지 URL인 경우
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(_clan!.emblem as String),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (_clan!.emblem is Map) {
      // 기본 엠블럼인 경우
      final emblem = _clan!.emblem as Map;
      final Color backgroundColor = emblem['backgroundColor'] as Color? ?? AppColors.primary;
      final String symbol = emblem['symbol'] as String? ?? 'sports_soccer';
      
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            _getIconData(symbol),
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    } else {
      // 기본 아이콘
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.groups,
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    }
  }
  
  String _formatActivityDays() {
    if (_clan!.activityDays.isEmpty) {
      return '정보 없음';
    }
    return _clan!.activityDays.join(', ');
  }
  
  String _formatActivityTimes() {
    if (_clan!.activityTimes.isEmpty) {
      return '정보 없음';
    }
    
    final timeLabels = {
      PlayTimeType.morning: '아침(6-10시)',
      PlayTimeType.daytime: '낮(10-18시)',
      PlayTimeType.evening: '저녁(18-24시)',
      PlayTimeType.night: '심야(24-6시)',
    };
    
    return _clan!.activityTimes.map((time) => timeLabels[time]).join(', ');
  }
  
  String _formatAgeGroups() {
    if (_clan!.ageGroups.isEmpty) {
      return '정보 없음';
    }
    
    final ageLabels = {
      AgeGroup.teens: '10대',
      AgeGroup.twenties: '20대',
      AgeGroup.thirties: '30대',
      AgeGroup.fortyPlus: '40대 이상',
    };
    
    return _clan!.ageGroups.map((age) => ageLabels[age]).join(', ');
  }
  
  String _formatGender() {
    final genderLabels = {
      GenderPreference.male: '남자',
      GenderPreference.female: '여자',
      GenderPreference.any: '남녀 모두',
    };
    
    return genderLabels[_clan!.genderPreference] ?? '정보 없음';
  }
  
  String _formatFocus() {
    switch (_clan!.focus) {
      case ClanFocus.casual:
        return '친목 위주';
      case ClanFocus.competitive:
        return '실력 위주';
      case ClanFocus.balanced:
        return '균형잡힌 스타일';
    }
  }
  
  Widget _buildLoginRequiredSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.login,
          size: 64,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        const Text(
          '클랜 가입 신청을 하려면 로그인이 필요합니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '로그인하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildApplicationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가입 신청',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            '포지션',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _positionController,
            decoration: InputDecoration(
              hintText: '선호하는 포지션을 입력하세요',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            '경력/경험',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _experienceController,
            decoration: InputDecoration(
              hintText: '경력이나 경험을 입력하세요',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            '연락처 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _contactInfoController,
            decoration: InputDecoration(
              hintText: '연락 가능한 정보를 입력하세요',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            '신청 메시지',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _messageController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '신청 메시지를 입력해주세요';
              }
              return null;
            },
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '클랜에 가입하고 싶은 이유를 작성해주세요',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitApplication,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '가입 신청하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getIconData(String symbol) {
    final Map<String, IconData> iconMap = {
      'shield': Icons.shield,
      'star': Icons.star,
      'sports_soccer': Icons.sports_soccer,
      'sports_basketball': Icons.sports_basketball,
      'sports_baseball': Icons.sports_baseball,
      'sports_football': Icons.sports_football,
      'sports_volleyball': Icons.sports_volleyball,
      'sports_tennis': Icons.sports_tennis,
      'whatshot': Icons.whatshot,
      'bolt': Icons.bolt,
      'pets': Icons.pets,
      'favorite': Icons.favorite,
      'stars': Icons.stars,
      'military_tech': Icons.military_tech,
      'emoji_events': Icons.emoji_events,
      'local_fire_department': Icons.local_fire_department,
      'public': Icons.public,
      'cruelty_free': Icons.cruelty_free,
      'emoji_nature': Icons.emoji_nature,
      'rocket_launch': Icons.rocket_launch,
    };
    
    return iconMap[symbol] ?? Icons.star;
  }
} 