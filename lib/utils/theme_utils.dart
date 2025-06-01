import 'package:flutter/material.dart';

/// Flutter 3.0+ 이후에서는 CardTheme 대신 CardThemeData를 사용해야 합니다.
/// 이 유틸리티 클래스는 기존 코드와의 호환성을 유지하면서 변환을 처리합니다.
class ThemeUtils {
  /// CardTheme을 CardThemeData로 변환합니다.
  /// Flutter 버전에 따라 자동으로 올바른 유형을 반환합니다.
  static dynamic getCardTheme({
    Color? color,
    double? elevation,
    ShapeBorder? shape,
    EdgeInsetsGeometry? margin,
    Clip? clipBehavior,
    bool? shadowColor,
  }) {
    // 실제로는 CardThemeData로 변환되지만,
    // 이전 버전 Flutter 코드와의 호환성을 위해 dynamic 반환
    return CardThemeData(
      color: color,
      elevation: elevation,
      shape: shape,
      margin: margin,
      clipBehavior: clipBehavior ?? Clip.none,
    );
  }
  
  /// Timestamp를 DateTime으로 안전하게 변환
  static DateTime safeTimestampToDateTime(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now();
    }
    
    // Timestamp 객체인 경우 toDate() 메서드 호출
    if (timestamp.runtimeType.toString().contains('Timestamp')) {
      return timestamp.toDate();
    }
    
    // 이미 DateTime인 경우 그대로 반환
    if (timestamp is DateTime) {
      return timestamp;
    }
    
    // 기타 경우 현재 시간 반환
    return DateTime.now();
  }
  
  /// null 안전 평균 별점 계산
  static String formatRating(double? rating) {
    return (rating ?? 0.0).toStringAsFixed(1);
  }
} 