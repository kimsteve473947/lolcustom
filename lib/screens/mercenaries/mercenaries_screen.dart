import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';

class MercenariesScreen extends StatefulWidget {
  const MercenariesScreen({Key? key}) : super(key: key);

  @override
  State<MercenariesScreen> createState() => _MercenariesScreenState();
}

class _MercenariesScreenState extends State<MercenariesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<MercenaryModel> _mercenaries = [];
  bool _ovrToggle = true;
  
  @override
  void initState() {
    super.initState();
    _loadMercenaries();
  }
  
  Future<void> _loadMercenaries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final mercenaries = await _firebaseService.getAvailableMercenaries(
        limit: 20,
        minOvr: _ovrToggle ? null : 0,
      );
      
      setState(() {
        _mercenaries = mercenaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load mercenaries: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              '용병있음',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(width: 8),
            Chip(
              label: Text('민락동'),
              padding: EdgeInsets.zero,
              labelStyle: TextStyle(fontSize: 12),
              backgroundColor: Color(0xFFEEEEEE),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Navigate to search
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _errorMessage != null
                ? ErrorView(
                    errorMessage: _errorMessage!,
                    onRetry: _loadMercenaries,
                  )
                : _isLoading
                    ? const LoadingIndicator()
                    : _mercenaries.isEmpty
                        ? _buildEmptyState()
                        : _buildMercenaryList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToMercenaryRegistration,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // OVR Filter toggle
          FilterChip(
            label: const Text('OVR 표시'),
            selected: _ovrToggle,
            onSelected: (value) {
              setState(() {
                _ovrToggle = value;
              });
              _loadMercenaries();
            },
            selectedColor: AppColors.primary.withOpacity(0.2),
            checkmarkColor: AppColors.primary,
          ),
          // 불필요한 필터는 제거했습니다
        ],
      ),
    );
  }
  
  Widget _buildMercenaryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mercenaries.length,
      itemBuilder: (context, index) {
        final mercenary = _mercenaries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              context.push('/mercenaries/${mercenary.id}');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: mercenary.profileImageUrl != null
                        ? NetworkImage(mercenary.profileImageUrl!)
                        : null,
                    child: mercenary.profileImageUrl == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              mercenary.nickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (mercenary.tier != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mercenary.tier!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Preferred positions
                        Wrap(
                          spacing: 8,
                          children: mercenary.preferredPositions.map((position) {
                            return Chip(
                              label: Text(position),
                              padding: EdgeInsets.zero,
                              labelStyle: const TextStyle(fontSize: 10),
                              backgroundColor: Colors.grey.shade200,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${mercenary.topRoleStat}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mercenary.topRole,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_search,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            '등록된 용병이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToMercenaryRegistration,
            child: const Text('용병 등록하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToMercenaryRegistration() async {
    try {
      debugPrint('용병 등록 화면으로 이동 시도');
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MercenaryEditScreen(mercenaryId: null),
        ),
      );
      
      if (result != null) {
        debugPrint('용병 등록 성공, 결과: $result');
        // 용병 목록 새로고침
        _loadMercenaries();
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('용병 등록이 완료되었습니다')),
        );
      } else {
        debugPrint('용병 등록 취소됨');
      }
    } catch (e) {
      debugPrint('!!! 용병 등록 화면 이동 중 오류 발생: $e !!!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }
} 