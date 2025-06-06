import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

/// 안전하게 이미지를 로드하기 위한 유틸리티 클래스
class ImageUtils {
  /// 안전하게 CircleAvatar 위젯을 생성하는 메서드
  static Widget safeCircleAvatar({
    String? imageUrl,
    double radius = 20,
    IconData defaultIcon = Icons.person,
    double? defaultIconSize,
    Color? backgroundColor,
  }) {
    // URL이 유효한지 확인
    final hasValidUrl = imageUrl != null && 
                        imageUrl.isNotEmpty && 
                        imageUrl.startsWith('http');
    
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasValidUrl ? NetworkImage(imageUrl!) : null,
      backgroundColor: hasValidUrl ? null : (backgroundColor ?? Colors.grey.shade200),
      child: hasValidUrl 
          ? null 
          : Icon(defaultIcon, size: defaultIconSize ?? radius, color: Colors.grey.shade700),
    );
  }
  
  /// 안전하게 네트워크 이미지를 로드하는 메서드
  static Widget safeNetworkImage({
    required String? imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // URL이 유효한지 확인
    final hasValidUrl = imageUrl != null && 
                        imageUrl.isNotEmpty && 
                        imageUrl.startsWith('http');
    
    if (!hasValidUrl) {
      return placeholder ?? Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade400,
            size: width / 3,
          ),
        ),
      );
    }
    
    return Image.network(
      imageUrl!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.grey.shade400,
              size: width / 3,
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  // 티어별 로고 이미지 경로 반환
  static String getTierLogoPath(PlayerTier tier) {
    switch (tier) {
      case PlayerTier.iron:
        return 'assets/images/tiers/아이언로고.png';
      case PlayerTier.bronze:
        return 'assets/images/tiers/브론즈로고.png';
      case PlayerTier.silver:
        return 'assets/images/tiers/실버로고.png';
      case PlayerTier.gold:
        return 'assets/images/tiers/골드로고.png';
      case PlayerTier.platinum:
        return 'assets/images/tiers/플레티넘로고.png';
      case PlayerTier.emerald:
        return 'assets/images/tiers/에메랄드로고.png';
      case PlayerTier.diamond:
        return 'assets/images/tiers/다이아로고.png';
      case PlayerTier.master:
        return 'assets/images/tiers/마스터로고.png';
      case PlayerTier.grandmaster:
      case PlayerTier.challenger:
      case PlayerTier.unranked:
      default:
        return 'assets/images/tiers/마스터로고.png';
    }
  }
} 