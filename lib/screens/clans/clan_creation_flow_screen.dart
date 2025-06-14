import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart' as CustomAuth;
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ClanCreationFlowScreen extends StatefulWidget {
  const ClanCreationFlowScreen({Key? key}) : super(key: key);

  @override
  State<ClanCreationFlowScreen> createState() => _ClanCreationFlowScreenState();
}

class _ClanCreationFlowScreenState extends State<ClanCreationFlowScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCreating = false;

  // 각 페이지의 Form Key
  final _basicInfoFormKey = GlobalKey<FormState>();

  // 각 페이지의 컨트롤러
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discordController = TextEditingController();

  // Emblem state
  String _selectedFrame = 'circle';
  String _selectedSymbol = 'sports_soccer';
  Color _selectedColor = AppColors.primary;
  File? _imageFile;
  bool _isCustomImage = false;

  final List<String> _frames = ['circle', 'rounded_square', 'shield'];
  final List<String> _symbols = [
    'sports_soccer', 'sports_basketball', 'sports_baseball', 'sports_football',
    'sports_volleyball', 'sports_tennis', 'star', 'shield', 'whatshot', 'bolt',
    'favorite', 'pets', 'stars', 'military_tech', 'emoji_events',
    'local_fire_department', 'public', 'cruelty_free', 'emoji_nature', 'rocket_launch',
  ];
  final List<Color> _colors = [
    AppColors.primary, Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal,
    Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber,
    Colors.orange, Colors.deepOrange, Colors.brown, Colors.grey, Colors.blueGrey,
  ];

  // Activity state
  final Map<String, String> _dayLabels = {
    '월': '월', '화': '화', '수': '수', '목': '목', '금': '금', '토': '토', '일': '일',
  };
  final Map<PlayTimeType, String> _timeLabels = {
    PlayTimeType.morning: '아침\n6-10시', PlayTimeType.daytime: '낮\n10-18시',
    PlayTimeType.evening: '저녁\n18-24시', PlayTimeType.night: '심야\n24-6시',
  };

  // Preferences state
  final Map<AgeGroup, String> _ageLabels = {
    AgeGroup.teens: '10대', AgeGroup.twenties: '20대',
    AgeGroup.thirties: '30대', AgeGroup.fortyPlus: '40대 이상',
  };
  final Map<GenderPreference, String> _genderLabels = {
    GenderPreference.male: '남자', GenderPreference.female: '여자', GenderPreference.any: '남녀 모두',
  };

  // Focus state
  double _sliderValue = 5.0;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    // 기존 데이터 로드
    _nameController.text = provider.name;
    _descriptionController.text = provider.description;
    _discordController.text = provider.discordUrl ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _discordController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // 현재 페이지 유효성 검사
    if (_currentPage == 0) {
      if (!_basicInfoFormKey.currentState!.validate()) return;
      // 유효성 검사 통과 시 provider에 데이터 저장
      final provider = Provider.of<ClanCreationProvider>(context, listen: false);
      provider.setName(_nameController.text.trim());
      provider.setDescription(_descriptionController.text.trim());
      provider.setDiscordUrl(_discordController.text.trim());
    } else if (_currentPage == 1) {
      // 엠블럼 정보 저장
      final provider = Provider.of<ClanCreationProvider>(context, listen: false);
      if (_isCustomImage && _imageFile != null) {
        provider.setEmblem(_imageFile);
      } else {
        final emblemData = {
          'frame': _selectedFrame,
          'symbol': _selectedSymbol,
          'backgroundColor': _selectedColor.value, // Store color value
        };
        provider.setEmblem(emblemData);
      }
    } else if (_currentPage == 2) {
      final provider = Provider.of<ClanCreationProvider>(context, listen: false);
      if (provider.activityDays.isEmpty || provider.activityTimes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('활동 요일과 시간대를 모두 선택해주세요.')));
        return;
      }
    } else if (_currentPage == 3) {
      final provider = Provider.of<ClanCreationProvider>(context, listen: false);
      if (provider.ageGroups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주요 나이대를 최소 1개 이상 선택해주세요.')));
        return;
      }
    }
    
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _createClan() async {
    setState(() => _isCreating = true);
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    final authProvider = Provider.of<CustomAuth.AuthProvider>(context, listen: false);

    try {
      final user = authProvider.user!;
      final clan = await provider.createClan(user.uid, user.nickname);
      provider.reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클랜이 성공적으로 생성되었습니다!')),
        );
        context.go('/clans/${clan.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클랜 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClanCreationProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _previousPage,
        ),
        title: Text(
          '클랜 만들기',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildBasicInfoStep(provider),
          _buildEmblemStep(provider),
          _buildActivityStep(provider),
          _buildPreferencesStep(provider),
          _buildFocusStep(provider),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: _currentPage == 4 ? (_isCreating ? null : _createClan) : _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isCreating
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(
                _currentPage == 4 ? '클랜 만들기' : '다음',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // Step 1: Basic Info
  Widget _buildBasicInfoStep(ClanCreationProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _basicInfoFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              '어떤 클랜을 만드시나요?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '클랜을 잘 나타내는 이름과 소개를 적어주세요.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildTextField(
              controller: _nameController,
              label: '클랜 이름 (2~10자)',
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '클랜 이름을 입력해주세요.';
                if (value.trim().length < 2) return '최소 2자 이상 입력해주세요.';
                if (value.trim().length > 10) return '최대 10자까지 입력 가능합니다.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _descriptionController,
              label: '클랜 소개 (10자 이상)',
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '클랜 설명을 입력해주세요.';
                if (value.trim().length < 10) return '최소 10자 이상 입력해주세요.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _discordController,
              label: '디스코드 URL (선택)',
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final urlPattern = RegExp(r'^(https?:\/\/)?(www\.)?discord\.gg\/[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*$');
                  if (!urlPattern.hasMatch(value.trim())) return '올바른 디스코드 URL 형식을 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            _buildSwitch(
              title: '멤버 목록 공개',
              subtitle: '클랜원이 아닌 사람에게 멤버 목록을 공개합니다.',
              value: provider.areMembersPublic,
              onChanged: (value) => provider.setAreMembersPublic(value),
            ),
            const SizedBox(height: 10),
            _buildSwitch(
              title: '멤버 모집',
              subtitle: '클랜원 모집을 활성화합니다.',
              value: provider.isRecruiting,
              onChanged: (value) => provider.setIsRecruiting(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Step 2: Emblem
  Widget _buildEmblemStep(ClanCreationProvider provider) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '클랜을 대표하는 엠블럼을\n만들어보세요.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '클랜의 개성을 뽐낼 수 있는 엠블럼을 선택해주세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isCustomImage && _imageFile != null
                        ? ClipOval(child: Image.file(_imageFile!, width: 150, height: 150, fit: BoxFit.cover))
                        : _buildEmblemPreview(),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildEmblemTypeSelector(setState),
              const SizedBox(height: 20),
              if (_isCustomImage)
                _buildCustomImageUploader(setState)
              else
                _buildDefaultEmblemCreator(setState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmblemTypeSelector(StateSetter setState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton('기본', !_isCustomImage, () => setState(() => _isCustomImage = false)),
          ),
          Expanded(
            child: _buildTypeButton('사진 업로드', _isCustomImage, () => setState(() => _isCustomImage = true)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String text, bool isSelected, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomImageUploader(StateSetter setState) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () async {
          final file = await _pickImage();
          if (file != null) {
            setState(() {
              _imageFile = file;
            });
          }
        },
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('갤러리에서 사진 선택'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDefaultEmblemCreator(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('프레임', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _frames.map((frame) {
            final isSelected = frame == _selectedFrame;
            return GestureDetector(
              onTap: () => setState(() => _selectedFrame = frame),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: _buildFramePreview(frame, 40, _selectedColor)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text('아이콘', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 10, crossAxisSpacing: 10),
            itemCount: _symbols.length,
            itemBuilder: (context, index) {
              final symbol = _symbols[index];
              final isSelected = symbol == _selectedSymbol;
              return GestureDetector(
                onTap: () => setState(() => _selectedSymbol = symbol),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                  child: Center(child: Icon(_getIconData(symbol), color: isSelected ? AppColors.primary : Colors.grey[600], size: 24)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text('색상', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _colors.map((color) {
            final isSelected = color.value == _selectedColor.value;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: AppColors.primary, width: 3) : Border.all(color: Colors.grey.shade300),
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<File?> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 선택 오류: $e')));
    }
    return null;
  }

  Widget _buildEmblemPreview() {
    return _buildFramePreview(_selectedFrame, 150, _selectedColor);
  }

  Widget _buildFramePreview(String frameType, double size, Color backgroundColor) {
    Widget content = Icon(_getIconData(_selectedSymbol), size: size * 0.6, color: Colors.white);
    switch (frameType) {
      case 'circle':
        return Container(width: size, height: size, decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle), child: Center(child: content));
      case 'rounded_square':
        return Container(width: size, height: size, decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(size * 0.2)), child: Center(child: content));
      case 'shield':
        return SizedBox(width: size, height: size, child: CustomPaint(painter: ShieldPainter(color: backgroundColor), child: Center(child: Padding(padding: EdgeInsets.only(bottom: size * 0.05), child: content))));
      default:
        return Container(width: size, height: size, decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle), child: Center(child: content));
    }
  }

  IconData _getIconData(String symbol) {
    final Map<String, IconData> iconMap = {
      'shield': Icons.shield, 'star': Icons.star, 'sports_soccer': Icons.sports_soccer, 'sports_basketball': Icons.sports_basketball,
      'sports_baseball': Icons.sports_baseball, 'sports_football': Icons.sports_football, 'sports_volleyball': Icons.sports_volleyball,
      'sports_tennis': Icons.sports_tennis, 'whatshot': Icons.whatshot, 'bolt': Icons.bolt, 'pets': Icons.pets, 'favorite': Icons.favorite,
      'stars': Icons.stars, 'military_tech': Icons.military_tech, 'emoji_events': Icons.emoji_events, 'local_fire_department': Icons.local_fire_department,
      'public': Icons.public, 'cruelty_free': Icons.cruelty_free, 'emoji_nature': Icons.emoji_nature, 'rocket_launch': Icons.rocket_launch,
    };
    return iconMap[symbol] ?? Icons.star;
  }


  // Step 3: Activity
  Widget _buildActivityStep(ClanCreationProvider provider) {
    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '주로 언제 활동하시나요?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '정확하지 않아도 괜찮아요. 주로 활동하는 시간을 알려주세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const Text('활동 요일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _dayLabels.entries.map((entry) {
                  final day = entry.key;
                  final label = entry.value;
                  final isSelected = provider.activityDays.contains(day);
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.toggleActivityDay(day);
                      setState(() {});
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              const Text('활동 시간대', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _timeLabels.entries.map((entry) {
                  final time = entry.key;
                  final label = entry.value.replaceAll('\n', ' ');
                  final isSelected = provider.activityTimes.contains(time);
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.toggleActivityTime(time);
                      setState(() {});
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Step 4: Preferences
  Widget _buildPreferencesStep(ClanCreationProvider provider) {
    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '어떤 멤버와 함께하고 싶나요?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
               const SizedBox(height: 12),
              const Text(
                '클랜의 선호 연령대와 성별을 선택해주세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const Text('선호 연령대 (복수선택 가능)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _ageLabels.entries.map((entry) {
                  final isSelected = provider.ageGroups.contains(entry.key);
                  return ChoiceChip(
                    avatar: isSelected ? null : Icon(_getAgeIcon(entry.key), color: Colors.grey[600]),
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.toggleAgeGroup(entry.key);
                      setState(() {});
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              const Text('선호 성별', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: _genderLabels.entries.map((entry) {
                  final isSelected = provider.genderPreference == entry.key;
                  return ChoiceChip(
                    avatar: isSelected ? null : Icon(_getGenderIcon(entry.key), color: Colors.grey[600]),
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setGenderPreference(entry.key);
                      setState(() {});
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getAgeIcon(AgeGroup ageGroup) {
    switch (ageGroup) {
      case AgeGroup.teens: return Icons.school;
      case AgeGroup.twenties: return Icons.emoji_people;
      case AgeGroup.thirties: return Icons.work;
      case AgeGroup.fortyPlus: return Icons.psychology;
    }
  }

  IconData _getGenderIcon(GenderPreference gender) {
    switch (gender) {
      case GenderPreference.male: return Icons.male;
      case GenderPreference.female: return Icons.female;
      case GenderPreference.any: return Icons.people;
    }
  }

  Widget _buildSelectionTile({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade700, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // Step 5: Focus
  Widget _buildFocusStep(ClanCreationProvider provider) {
    return StatefulBuilder(
      builder: (context, setState) {
        ClanFocus focus;
        if (_sliderValue <= 3) {
          focus = ClanFocus.casual;
        } else if (_sliderValue >= 7) {
          focus = ClanFocus.competitive;
        } else {
          focus = ClanFocus.balanced;
        }

        // Update provider immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.setFocusRating(_sliderValue.toInt());
          provider.setFocus(focus);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '클랜의 성향은 어떤가요?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '슬라이더를 움직여 클랜의 주된 성향을 알려주세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildFocusIndicator(label: _getFocusLabel(focus), description: _getFocusDescription(focus), color: _getFocusColor(focus)),
                    const SizedBox(height: 20),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _getFocusColor(focus),
                        inactiveTrackColor: Colors.grey[300],
                        thumbColor: Colors.white,
                        overlayColor: _getFocusColor(focus).withOpacity(0.2),
                        trackHeight: 8,
                      ),
                      child: Slider(
                        value: _sliderValue,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (value) => setState(() => _sliderValue = value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('친목', style: TextStyle(color: Colors.green[700])),
                          Text('균형', style: TextStyle(color: AppColors.primary)),
                          Text('실력', style: TextStyle(color: Colors.red[700])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                '마지막으로 확인해주세요',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildConfirmationSection(provider, focus),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfirmationSection(ClanCreationProvider provider, ClanFocus focus) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildConfirmationItem('클랜 이름', provider.name),
          _buildConfirmationItem('클랜 소개', provider.description),
          _buildConfirmationItem('활동 요일', provider.activityDays.join(', ')),
          _buildConfirmationItem('활동 시간', provider.activityTimes.map(_playTimeToString).join(', ')),
          _buildConfirmationItem('선호 연령대', (provider.ageGroups..sort((a, b) => a.index.compareTo(b.index))).map(_ageGroupToString).join(', ')),
          _buildConfirmationItem('선호 성별', _genderPreferenceToString(provider.genderPreference)),
          _buildConfirmationItem('클랜 성향', _getFocusLabel(focus)),
        ],
      ),
    );
  }

  String _playTimeToString(PlayTimeType type) {
    switch (type) {
      case PlayTimeType.morning: return '아침';
      case PlayTimeType.daytime: return '낮';
      case PlayTimeType.evening: return '저녁';
      case PlayTimeType.night: return '심야';
    }
  }

  String _ageGroupToString(AgeGroup group) {
    switch (group) {
      case AgeGroup.teens: return '10대';
      case AgeGroup.twenties: return '20대';
      case AgeGroup.thirties: return '30대';
      case AgeGroup.fortyPlus: return '40대 이상';
    }
  }

  String _genderPreferenceToString(GenderPreference preference) {
    switch (preference) {
      case GenderPreference.male: return '남자';
      case GenderPreference.female: return '여자';
      case GenderPreference.any: return '남녀 모두';
    }
  }

  Widget _buildConfirmationItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusIndicator({required String label, required String description, required Color color}) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(child: Icon(_getFocusIcon(), color: color, size: 30)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getFocusIcon() {
    if (_sliderValue <= 3) return Icons.sentiment_satisfied_alt;
    if (_sliderValue >= 7) return Icons.fitness_center;
    return Icons.balance;
  }

  String _getFocusLabel(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual: return '친목 위주';
      case ClanFocus.competitive: return '실력 위주';
      case ClanFocus.balanced: return '균형잡힌 스타일';
    }
  }

  String _getFocusDescription(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual: return '즐겁게 게임하며 좋은 시간을 보내요';
      case ClanFocus.competitive: return '승리를 위해 전략적으로 플레이해요';
      case ClanFocus.balanced: return '실력과 친목 모두 중요해요';
    }
  }

  Color _getFocusColor(ClanFocus focus) {
    switch (focus) {
      case ClanFocus.casual: return Colors.green.shade600;
      case ClanFocus.competitive: return Colors.red.shade600;
      case ClanFocus.balanced: return AppColors.primary;
    }
  }
}
class ShieldPainter extends CustomPainter {
  final Color color;
  
  ShieldPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.05, size.width * 0.95, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.7, size.width / 2, size.height);
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.7, size.width * 0.05, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.05, size.width / 2, 0);
    path.close();
    canvas.drawPath(path, paint);
    
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawPath(path, shadowPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}