import 'package:flutter/material.dart';

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
  static const String top = 'assets/images/lane_top.png';
  static const String jungle = 'assets/images/lane_jungle.png';
  static const String mid = 'assets/images/lane_mid.png';
  static const String adc = 'assets/images/lane_adc.png';
  static const String support = 'assets/images/lane_support.png';
  
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

// 게임 형식 열거형 (TournamentModel.dart에서 가져온 것)
enum GameFormat {
  single,
  bestOfThree,
  bestOfFive,
}

// 게임 서버 열거형 (TournamentModel.dart에서 가져온 것)
enum GameServer {
  kr,
  jp,
  na,
  eu,
} 