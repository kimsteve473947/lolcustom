import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClanEmblemWidget extends StatelessWidget {
  final dynamic emblemData;
  final double size;

  const ClanEmblemWidget({
    Key? key,
    required this.emblemData,
    this.size = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (emblemData is String) {
      // Custom image from Firebase Storage
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: emblemData as String,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            color: Colors.grey[300],
          ),
          errorWidget: (context, url, error) => Container(
            width: size,
            height: size,
            color: Colors.grey[300],
            child: Icon(Icons.error, color: Colors.red, size: size * 0.5),
          ),
        ),
      );
    } else if (emblemData is Map) {
      // Default emblem
      final Map<String, dynamic> emblemMap = Map<String, dynamic>.from(emblemData);
      final String frame = emblemMap['frame'] ?? 'circle';
      final String symbol = emblemMap['symbol'] ?? 'star';
      final Color backgroundColor = emblemMap['backgroundColor'] is Color
          ? emblemMap['backgroundColor']
          : Color(emblemMap['backgroundColor'] ?? Colors.grey.value);

      return _buildFramePreview(frame, size, backgroundColor, symbol);
    }

    // Fallback for invalid data
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.shield, color: Colors.grey[400], size: size * 0.6),
    );
  }

  Widget _buildFramePreview(String frameType, double size, Color backgroundColor, String symbol) {
    Widget content = Icon(_getIconData(symbol), size: size * 0.6, color: Colors.white);
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
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}