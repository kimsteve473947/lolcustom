import 'package:flutter/material.dart';

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
} 