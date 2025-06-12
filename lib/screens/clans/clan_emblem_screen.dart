import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/clan_creation_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;

class ClanEmblemScreen extends StatefulWidget {
  const ClanEmblemScreen({Key? key}) : super(key: key);

  @override
  State<ClanEmblemScreen> createState() => _ClanEmblemScreenState();
}

class _ClanEmblemScreenState extends State<ClanEmblemScreen> {
  // Emblem design options
  String _selectedFrame = 'circle';
  String _selectedSymbol = 'sports_soccer';
  Color _selectedColor = AppColors.primary;
  File? _imageFile;
  bool _isCustomImage = false;
  
  // Available frames
  final List<String> _frames = ['circle', 'rounded_square', 'shield'];
  
  // Available symbols
  final List<String> _symbols = [
    'sports_soccer',
    'sports_basketball',
    'sports_baseball',
    'sports_football',
    'sports_volleyball',
    'sports_tennis',
    'star',
    'shield',
    'whatshot',
    'bolt',
    'favorite',
    'pets',
    'stars',
    'military_tech',
    'emoji_events',
    'local_fire_department',
    'public',
    'cruelty_free',
    'emoji_nature',
    'rocket_launch',
  ];
  
  // Available colors
  final List<Color> _colors = [
    AppColors.primary,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize with existing emblem data if available
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    if (provider.hasEmblem) {
      if (provider.emblem is Map) {
        final emblem = provider.emblem as Map;
        if (emblem.containsKey('frame')) {
          _selectedFrame = emblem['frame'] as String;
        }
        if (emblem.containsKey('symbol')) {
          _selectedSymbol = emblem['symbol'] as String;
        }
        if (emblem.containsKey('backgroundColor')) {
          _selectedColor = emblem['backgroundColor'] as Color;
        }
        _isCustomImage = false;
      } else if (provider.emblem is File) {
        _imageFile = provider.emblem as File;
        _isCustomImage = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClanCreationProvider>(context);
    final clanName = provider.name.isNotEmpty ? provider.name : '새 클랜';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('엠블럼 선택'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show clan name
                  Text(
                    clanName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  const Text(
                    '엠블럼을\n선택해주세요',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Emblem preview
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isCustomImage && _imageFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _imageFile!,
                                  width: 180,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _buildEmblemPreview(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Custom image upload
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('사진 업로드'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Toggle between custom image and template
                  if (_imageFile != null)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isCustomImage = !_isCustomImage;
                          });
                        },
                        child: Text(
                          _isCustomImage ? '기본 아이콘 선택' : '업로드한 사진 사용',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Only show these options if not using custom image
                  if (!_isCustomImage) ...[
                    // Frame selection
                    const Text(
                      '프레임',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _frames.map((frame) {
                          final isSelected = frame == _selectedFrame;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => setState(() => _selectedFrame = frame),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isSelected ? _selectedColor.withOpacity(0.2) : Colors.grey[100],
                                  border: isSelected
                                      ? Border.all(color: _selectedColor, width: 2)
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: _selectedColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ] : null,
                                ),
                                child: Center(
                                  child: _buildFramePreview(frame, 40, _selectedColor),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Symbol selection
                    const Text(
                      '아이콘',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: _symbols.length,
                      itemBuilder: (context, index) {
                        final symbol = _symbols[index];
                        final isSelected = symbol == _selectedSymbol;
                        return InkWell(
                          onTap: () => setState(() => _selectedSymbol = symbol),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? _selectedColor.withOpacity(0.2) : Colors.grey[100],
                              border: isSelected
                                  ? Border.all(color: _selectedColor, width: 2)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: _selectedColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 0,
                                ),
                              ] : null,
                            ),
                            child: Center(
                              child: Icon(
                                _getIconData(symbol),
                                color: isSelected ? _selectedColor : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Color selection
                    const Text(
                      '색상',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: _colors.length,
                      itemBuilder: (context, index) {
                        final color = _colors[index];
                        final isSelected = color.value == _selectedColor.value;
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '뒤로',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _saveEmblem(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _isCustomImage = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지를 불러오는 중 오류가 발생했습니다: $e')),
      );
    }
  }
  
  Widget _buildEmblemPreview() {
    double size = 180;
    
    return _buildFramePreview(_selectedFrame, size, _selectedColor);
  }
  
  Widget _buildFramePreview(String frameType, double size, Color backgroundColor) {
    Widget content = Icon(
      _getIconData(_selectedSymbol),
      size: size * 0.6,
      color: Colors.white,
    );
    
    switch (frameType) {
      case 'circle':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(child: content),
        );
        
      case 'rounded_square':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(child: content),
        );
        
      case 'shield':
        return Container(
          width: size,
          height: size,
          child: CustomPaint(
            size: Size(size, size),
            painter: ShieldPainter(color: backgroundColor),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: size * 0.05),
                  child: content,
                ),
              ),
            ),
          ),
        );
        
      default:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(child: content),
        );
    }
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
  
  void _saveEmblem(BuildContext context) {
    final provider = Provider.of<ClanCreationProvider>(context, listen: false);
    
    if (_isCustomImage && _imageFile != null) {
      // Save custom image
      provider.setEmblem(_imageFile);
    } else {
      // Create emblem data
      final emblemData = {
        'frame': _selectedFrame,
        'symbol': _selectedSymbol,
        'backgroundColor': _selectedColor,
      };
      
      // Save to provider
      provider.setEmblem(emblemData);
    }
    
    // Show confirmation and go back
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('엠블럼이 저장되었습니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Return to previous screen
    context.pop(provider.emblem);
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
    
    // Start at top center
    path.moveTo(size.width / 2, 0);
    
    // Top right curve
    path.quadraticBezierTo(
      size.width * 0.95,
      size.height * 0.05,
      size.width * 0.95,
      size.height * 0.35,
    );
    
    // Bottom right curve
    path.quadraticBezierTo(
      size.width * 0.95,
      size.height * 0.7,
      size.width / 2,
      size.height,
    );
    
    // Bottom left curve
    path.quadraticBezierTo(
      size.width * 0.05,
      size.height * 0.7,
      size.width * 0.05,
      size.height * 0.35,
    );
    
    // Top left curve
    path.quadraticBezierTo(
      size.width * 0.05,
      size.height * 0.05,
      size.width / 2,
      0,
    );
    
    path.close();
    canvas.drawPath(path, paint);
    
    // Add shadow effect
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