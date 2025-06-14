import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';

class ClanManagementScreen extends StatefulWidget {
  final String clanId;

  const ClanManagementScreen({Key? key, required this.clanId}) : super(key: key);

  @override
  _ClanManagementScreenState createState() => _ClanManagementScreenState();
}

class _ClanManagementScreenState extends State<ClanManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClanService _clanService = ClanService();
  late Future<ClanModel?> _clanFuture;

  bool _isLoading = false;
  bool _isInitialized = false;

  // Form-related state
  String? _name;
  String? _description;
  String? _discordUrl;
  bool _areMembersPublic = true;
  bool _isRecruiting = true;

  // Activity-related state
  Set<String> _activityDays = {};
  Set<PlayTimeType> _activityTimes = {};

  // Preference-related state
  Set<AgeGroup> _ageGroups = {};
  GenderPreference _genderPreference = GenderPreference.any;

  // Focus-related state
  double _focusRating = 5.0;
  ClanFocus _focus = ClanFocus.balanced;

  @override
  void initState() {
    super.initState();
    _clanFuture = _clanService.getClan(widget.clanId);
  }

  void _updateClan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        final originalClan = await _clanFuture;
        if (originalClan == null) {
          throw Exception("Original clan not found");
        }

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.user;

        if (currentUser == null || originalClan.ownerId != currentUser.uid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('권한이 없습니다.')),
          );
          return;
        }

        final updatedClan = originalClan.copyWith(
          name: _name,
          description: _description,
          discordUrl: _discordUrl,
          areMembersPublic: _areMembersPublic,
          isRecruiting: _isRecruiting,
          activityDays: _activityDays.toList(),
          activityTimes: _activityTimes.toList(),
          ageGroups: _ageGroups.toList(),
          genderPreference: _genderPreference,
          focusRating: _focusRating.toInt(),
          focus: _focus,
        );

        await _clanService.updateClan(updatedClan.id, updatedClan.toMap());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜 정보가 성공적으로 업데이트되었습니다.')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 정보 업데이트에 실패했습니다: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildActivityDayChips() {
    final dayLabels = {'월': '월', '화': '화', '수': '수', '목': '목', '금': '금', '토': '토', '일': '일'};
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: dayLabels.entries.map((entry) {
        final day = entry.key;
        final isSelected = _activityDays.contains(day);
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _activityDays.add(day);
              } else {
                _activityDays.remove(day);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildActivityTimeChips() {
    final timeLabels = {
      PlayTimeType.morning: '아침\n6-10시',
      PlayTimeType.daytime: '낮\n10-18시',
      PlayTimeType.evening: '저녁\n18-24시',
      PlayTimeType.night: '심야\n24-6시',
    };
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: timeLabels.entries.map((entry) {
        final time = entry.key;
        final isSelected = _activityTimes.contains(time);
        return ChoiceChip(
          label: Text(entry.value, textAlign: TextAlign.center),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _activityTimes.add(time);
              } else {
                _activityTimes.remove(time);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildAgeGroupChips() {
    final ageLabels = {
      AgeGroup.teens: '10대', AgeGroup.twenties: '20대',
      AgeGroup.thirties: '30대', AgeGroup.fortyPlus: '40대 이상',
    };
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: ageLabels.entries.map((entry) {
        final ageGroup = entry.key;
        final isSelected = _ageGroups.contains(ageGroup);
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _ageGroups.add(ageGroup);
              } else {
                _ageGroups.remove(ageGroup);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildGenderChips() {
    final genderLabels = {
      GenderPreference.male: '남자', GenderPreference.female: '여자', GenderPreference.any: '남녀 모두',
    };
    return Wrap(
      spacing: 8.0,
      children: genderLabels.entries.map((entry) {
        return ChoiceChip(
          label: Text(entry.value),
          selected: _genderPreference == entry.key,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _genderPreference = entry.key;
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildFocusSlider() {
    if (_focusRating <= 3) {
      _focus = ClanFocus.casual;
    } else if (_focusRating >= 7) {
      _focus = ClanFocus.competitive;
    } else {
      _focus = ClanFocus.balanced;
    }

    Color focusColor;
    String focusLabel;
    switch (_focus) {
      case ClanFocus.casual:
        focusColor = Colors.green.shade600;
        focusLabel = '친목 위주';
        break;
      case ClanFocus.competitive:
        focusColor = Colors.red.shade600;
        focusLabel = '실력 위주';
        break;
      case ClanFocus.balanced:
        focusColor = AppColors.primary;
        focusLabel = '균형잡힌 스타일';
        break;
    }

    return Column(
      children: [
        Text(focusLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: focusColor)),
        Slider(
          value: _focusRating,
          min: 1,
          max: 10,
          divisions: 9,
          label: _focusRating.round().toString(),
          activeColor: focusColor,
          onChanged: (value) {
            setState(() {
              _focusRating = value;
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('친목', style: TextStyle(color: Colors.green[700])),
              Text('실력', style: TextStyle(color: Colors.red[700])),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클랜 정보 수정'),
      ),
      body: FutureBuilder<ClanModel?>(
        future: _clanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('클랜 정보를 불러올 수 없습니다.'));
          }

          final clan = snapshot.data!;
          if (!_isInitialized) {
            _name = clan.name;
            _description = clan.description;
            _discordUrl = clan.discordUrl;
            _areMembersPublic = clan.areMembersPublic;
            _isRecruiting = clan.isRecruiting;
            _activityDays = clan.activityDays.toSet();
            _activityTimes = clan.activityTimes.toSet();
            _ageGroups = clan.ageGroups.toSet();
            _genderPreference = clan.genderPreference;
            _focusRating = clan.focusRating.toDouble();
            _focus = clan.focus;
            _isInitialized = true;
          }

          return _isLoading
              ? const Center(child: LoadingIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('클랜 기본 정보'),
                        TextFormField(
                          initialValue: _name,
                          decoration: const InputDecoration(labelText: '클랜 이름', border: OutlineInputBorder()),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return '클랜 이름을 입력해주세요.';
                            if (value.trim().length < 2) return '최소 2자 이상 입력해주세요.';
                            return null;
                          },
                          onSaved: (value) => _name = value?.trim(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _description,
                          decoration: const InputDecoration(labelText: '클랜 설명', border: OutlineInputBorder()),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return '클랜 설명을 입력해주세요.';
                            if (value.trim().length < 10) return '최소 10자 이상 입력해주세요.';
                            return null;
                          },
                          onSaved: (value) => _description = value?.trim(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _discordUrl,
                          decoration: const InputDecoration(labelText: '디스코드 URL (선택)', border: OutlineInputBorder()),
                          onSaved: (value) => _discordUrl = value?.trim(),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('멤버 목록 공개'),
                          value: _areMembersPublic,
                          onChanged: (value) => setState(() => _areMembersPublic = value),
                        ),
                        SwitchListTile(
                          title: const Text('멤버 모집'),
                          value: _isRecruiting,
                          onChanged: (value) => setState(() => _isRecruiting = value),
                        ),
                        const Divider(height: 48),
                        _buildSectionTitle('주요 활동 시간'),
                        const SizedBox(height: 8),
                        const Text('활동 요일'),
                        const SizedBox(height: 8),
                        _buildActivityDayChips(),
                        const SizedBox(height: 24),
                        const Text('활동 시간대'),
                        const SizedBox(height: 8),
                        _buildActivityTimeChips(),
                        const Divider(height: 48),
                        _buildSectionTitle('클랜 선호도'),
                        const SizedBox(height: 8),
                        const Text('주요 나이대 (복수선택 가능)'),
                        const SizedBox(height: 8),
                        _buildAgeGroupChips(),
                        const SizedBox(height: 24),
                        const Text('선호 성별'),
                        const SizedBox(height: 8),
                        _buildGenderChips(),
                        const Divider(height: 48),
                        _buildSectionTitle('클랜 성향'),
                        const SizedBox(height: 8),
                        _buildFocusSlider(),
                        const SizedBox(height: 48),
                        Center(
                          child: ElevatedButton(
                            onPressed: _updateClan,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                            child: const Text('저장'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }
}