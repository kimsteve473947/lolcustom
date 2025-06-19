import 'package:flutter/material.dart';

class AppColors {
  // 메인 컬러 - 토스 스타일의 깔끔한 색상
  static const Color primary = Color(0xFFFF6B35);  // jud.gg 오렌지 (유지)
  static const Color primaryLight = Color(0xFFFF9068);  // 밝은 오렌지
  static const Color primaryDark = Color(0xFFE85A2C);   // 진한 오렌지
  
  // 배경 색상 - 토스 스타일의 부드러운 화이트/그레이
  static const Color background = Color(0xFFFAFAFA);     // 아주 연한 그레이 (토스 스타일)
  static const Color backgroundCard = Color(0xFFFFFFFF); // 카드 배경은 순백색
  static const Color backgroundGrey = Color(0xFFF5F5F5); // 섹션 구분용 연한 그레이
  
  // 시스템 색상 - 모던하고 부드러운 톤
  static const Color success = Color(0xFF07C160);   // 토스 스타일 그린
  static const Color error = Color(0xFFFA5151);     // 부드러운 레드
  static const Color warning = Color(0xFFFFC300);   // 밝은 옐로우
  static const Color info = Color(0xFF1890FF);      // 밝은 블루
  
  // 중립 색상 - 토스 스타일의 그레이 스케일
  static const Color black = Color(0xFF191919);         // 순수 검정 대신 부드러운 검정
  static const Color textPrimary = Color(0xFF191919);   // 주요 텍스트
  static const Color textSecondary = Color(0xFF8B8B8B); // 보조 텍스트
  static const Color textTertiary = Color(0xFFB8B8B8);  // 3차 텍스트
  static const Color textDisabled = Color(0xFFD4D4D4);  // 비활성 텍스트
  
  // 테두리 및 구분선
  static const Color border = Color(0xFFE8E8E8);        // 일반 테두리
  static const Color divider = Color(0xFFF0F0F0);       // 구분선
  static const Color borderLight = Color(0xFFF5F5F5);   // 연한 테두리
  
  // 기능 색상
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF8B8B8B);          // textSecondary와 통일
  static const Color lightGrey = Color(0xFFE8E8E8);     // border와 통일
  static const Color darkGrey = Color(0xFF4A4A4A);      // 진한 그레이
  static const Color disabled = Color(0xFFD4D4D4);      // textDisabled와 통일
  static const Color link = Color(0xFF1890FF);          // info와 통일
  
  // 롤 포지션 컬러 - 2024 트렌드를 반영한 생동감 있는 색상
  static const Color top = Color(0xFFFF654F);       // Neon Flare 계열 레드
  static const Color jungle = Color(0xFF07C160);    // 모던 그린
  static const Color mid = Color(0xFF4C5578);       // Future Dusk (2024 트렌드)
  static const Color adc = Color(0xFFFF9068);       // 주황색 (primaryLight와 통일)
  static const Color support = Color(0xFF9B59B6);   // 밝은 보라색
  
  // 롤 포지션 컬러 (TournamentCard 사용) - 위와 동일하게 통일
  static const Color roleTop = Color(0xFFFF654F);
  static const Color roleJungle = Color(0xFF07C160);
  static const Color roleMid = Color(0xFF4C5578);
  static const Color roleAdc = Color(0xFFFF9068);
  static const Color roleSupport = Color(0xFF9B59B6);
  
  // 그림자 색상
  static const Color shadow = Color(0x0A000000);        // 10% 투명도 검정
  static const Color shadowLight = Color(0x05000000);   // 5% 투명도 검정
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        secondary: AppColors.link,
        error: AppColors.error,
        background: AppColors.background,
      ),
      textTheme: const TextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundCard,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.white,
          side: BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.backgroundCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: AppColors.backgroundCard,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 16,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundCard,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.grey,
        indicatorColor: AppColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.black,
      // Dark 테마도 필요하면 이후 구현
    );
  }
} 