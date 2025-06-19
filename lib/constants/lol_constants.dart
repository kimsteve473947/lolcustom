import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';

// 앱 공통 이미지 경로 (효율적인 단일 파일 사용)
class AppImages {
  // 메인 로고 - 하나의 파일로 모든 곳에서 재사용
  static const String logo = 'assets/images/app_logo.png';
  
  // 기본 프로필 이미지 (로고 재사용으로 저장공간 절약)
  static const String defaultProfile = logo;
  
  // 플레이스홀더 이미지 (로고 재사용)
  static const String placeholder = logo;
  
  // 에러 시 대체 이미지 (로고 재사용)
  static const String fallback = logo;
}

// 롤 라인 정보
enum LolLane {
  top,
  jungle,
  mid,
  adc,
  support,
}

// 롤 라인별 이름
class LolLaneNames {
  static const Map<LolLane, String> kr = {
    LolLane.top: '탑',
    LolLane.jungle: '정글',
    LolLane.mid: '미드',
    LolLane.adc: '원딜',
    LolLane.support: '서포터',
  };
  
  static const Map<LolLane, String> en = {
    LolLane.top: 'Top',
    LolLane.jungle: 'Jungle',
    LolLane.mid: 'Mid',
    LolLane.adc: 'ADC',
    LolLane.support: 'Support',
  };
}

// 롤 라인별 아이콘 경로
class LolLaneIcons {
  static const String top = 'assets/images/lanes/lane_top.png';
  static const String jungle = 'assets/images/lanes/lane_jungle.png';
  static const String mid = 'assets/images/lanes/lane_mid.png';
  static const String adc = 'assets/images/lanes/lane_adc.png';
  static const String support = 'assets/images/lanes/lane_support.png';
  
  static const Map<LolLane, String> paths = {
    LolLane.top: top,
    LolLane.jungle: jungle,
    LolLane.mid: mid,
    LolLane.adc: adc,
    LolLane.support: support,
  };
}

// 롤 게임 방식
class LolGameFormats {
  static const Map<GameFormat, String> names = {
    GameFormat.single: '단판',
    GameFormat.bestOfThree: '3판 2선승제',
    GameFormat.bestOfFive: '5판 3선승제',
  };
}

// 롤 서버 지역
class LolGameServers {
  static const Map<GameServer, String> names = {
    GameServer.kr: '한국 서버',
    GameServer.jp: '일본 서버',
    GameServer.na: '북미 서버',
    GameServer.eu: '유럽 서버',
  };
}

// 롤 티어 정보
class LolTiers {
  static const List<String> names = [
    'Iron', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Emerald', 'Diamond', 'Master', 'Grandmaster', 'Challenger'
  ];

  static const Map<String, int> scores = {
    'Iron': 0,
    'Bronze': 4,
    'Silver': 8,
    'Gold': 12,
    'Platinum': 16,
    'Emerald': 20,
    'Diamond': 24,
    'Master': 28,
    'Grandmaster': 28, // Master 이상은 동일 점수 부여
    'Challenger': 28,
  };

  static const Map<String, String> kr = {
    'Iron': '아이언',
    'Bronze': '브론즈',
    'Silver': '실버',
    'Gold': '골드',
    'Platinum': '플래티넘',
    'Emerald': '에메랄드',
    'Diamond': '다이아몬드',
    'Master': '마스터',
    'Grandmaster': '그랜드마스터',
    'Challenger': '챌린저',
  };

  static String getTierFromScore(double score) {
    if (score >= 28) return 'Master';
    if (score >= 24) return 'Diamond';
    if (score >= 20) return 'Emerald';
    if (score >= 16) return 'Platinum';
    if (score >= 12) return 'Gold';
    if (score >= 8) return 'Silver';
    if (score >= 4) return 'Bronze';
    return 'Iron';
  }
}

// 롤 티어 아이콘 경로
class LolTierIcons {
  static const String iron = 'assets/images/tiers/아이언로고.png';
  static const String bronze = 'assets/images/tiers/브론즈로고.png';
  static const String silver = 'assets/images/tiers/실버로고.png';
  static const String gold = 'assets/images/tiers/골드로고.png';
  static const String platinum = 'assets/images/tiers/플레티넘로고.png';
  static const String emerald = 'assets/images/tiers/에메랄드로고.png';
  static const String diamond = 'assets/images/tiers/다이아로고.png';
  static const String master = 'assets/images/tiers/마스터로고.png';

  static String getIconPath(String tier) {
    switch (tier.toLowerCase()) {
      case 'iron': return iron;
      case 'bronze': return bronze;
      case 'silver': return silver;
      case 'gold': return gold;
      case 'platinum': return platinum;
      case 'emerald': return emerald;
      case 'diamond': return diamond;
      case 'master':
      case 'grandmaster':
      case 'challenger':
        return master;
      default:
        return iron;
    }
  }
}