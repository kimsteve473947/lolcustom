import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

enum TournamentStatus {
  draft,    // 초안 상태
  open,     // 참가자 모집 중
  full,     // 모집 완료
  inProgress, // 진행 중
  ongoing,  // 진행 중 (레거시 - 호환성 유지)
  completed,// 완료됨
  cancelled // 취소됨
}

// 경기 방식을 정의하는 열거형
enum GameFormat {
  single,   // 단판
  bestOfThree, // 3판 2선승제
  bestOfFive, // 5판 3선승제
}

// 게임 서버 지역
enum GameServer {
  kr,       // 한국 서버
  jp,       // 일본 서버
  na,       // 북미 서버
  eu,       // 유럽 서버
}

// 토너먼트 타입 정의
enum TournamentType {
  casual,   // 일반전 (무료)
  competitive,  // 경쟁전 (크레딧 사용)
}

// 게임 카테고리 정의 - 개인전/클랜전/대학리그전 구분
enum GameCategory {
  individual,   // 개인전
  clan,        // 클랜전
  university,  // 대학리그전
}

class TournamentModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String hostId;
  final String hostName;
  final String? hostProfileImageUrl;
  final String? hostNickname;
  final Timestamp startsAt;
  final String location; // 게임 서버 지역 정보로 사용
  final TournamentType tournamentType; // 토너먼트 타입 (일반전/경쟁전)
  final GameCategory gameCategory; // 게임 카테고리 (개인전/클랜전/대학리그전)
  final int? creditCost; // 경쟁전 참가 시 필요한 크레딧 (경쟁전인 경우에만 사용)
  final int? ovrLimit; // 기존 제한 필드 (하위 호환성 유지)
  final PlayerTier? tierLimit; // 추가: 티어 제한
  final bool premiumBadge;
  final TournamentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, int> slots;
  final Map<String, int> filledSlots;
  final Map<String, int> slotsByRole;
  final Map<String, int> filledSlotsByRole;
  final List<String> participants;
  final Map<String, List<String>> participantsByRole; // 역할별 참가자 목록
  final Map<String, dynamic>? rules;
  final Map<String, dynamic>? results;
  final double? distance;
  
  // Discord 채널 정보
  final Map<String, dynamic>? discordChannels;
  
  // 리그 오브 레전드 특화 필드
  final GameFormat gameFormat; // 경기 방식
  final GameServer gameServer; // 게임 서버
  final String? customRoomName; // 커스텀 방 이름
  final String? customRoomPassword; // 커스텀 방 비밀번호
  
  // 심판 기능 관련 필드
  final List<String> referees; // 심판 권한이 있는 사용자 목록
  final bool isRefereed; // 심판이 필요한 토너먼트인지 여부 (경쟁전인 경우 true)
  
  // hostId 대신 hostUid를 사용할 수 있도록 게터 추가
  String get hostUid => hostId;
  
  // 하위 호환성을 위한 게터 추가
  bool get isPaid => tournamentType == TournamentType.competitive;
  
  int? get price => tournamentType == TournamentType.competitive ? 20 : null;
  
  // 총 슬롯 수 계산 (모든 역할의 슬롯 합계)
  int get totalSlots {
    return slotsByRole.values.fold(0, (sum, slots) => sum + slots);
  }
  
  // 호스트 포지션 게터 추가
  String? get hostPosition {
    // 실제 호스트 포지션 값 반환
    if (_hostPosition != null) {
      return _hostPosition;
    }
    
    // participantsByRole에서 hostId를 가진 참가자의 역할 찾기
    for (final entry in participantsByRole.entries) {
      final role = entry.key;
      final participants = entry.value;
      if (participants.contains(hostId)) {
        return role;
      }
    }
    
    return null;
  }
  
  // 호스트 포지션 저장용 내부 필드
  final String? _hostPosition;
  
  const TournamentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.hostId,
    required this.hostName,
    this.hostProfileImageUrl,
    this.hostNickname,
    required this.startsAt,
    required this.location,
    required this.tournamentType,
    required this.gameCategory,
    this.creditCost,
    this.ovrLimit,
    this.tierLimit,
    this.premiumBadge = false,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.slots,
    required this.filledSlots,
    required this.slotsByRole,
    required this.filledSlotsByRole,
    required this.participants,
    required this.participantsByRole,
    this.rules,
    this.results,
    this.distance,
    this.discordChannels,
    this.gameFormat = GameFormat.single,
    this.gameServer = GameServer.kr,
    this.customRoomName,
    this.customRoomPassword,
    this.referees = const [],
    this.isRefereed = false,
    String? hostPosition,
  }) : _hostPosition = hostPosition;
  
  // 기본 값으로 역할별 슬롯을 생성하는 팩토리 메서드
  factory TournamentModel.withDefaultRoleSlots({
    required String id,
    required String title,
    required String description,
    required String hostId,
    required String hostName,
    String? hostProfileImageUrl,
    String? hostNickname,
    required Timestamp startsAt,
    required String location,
    required TournamentType tournamentType,
    int? creditCost,
    int? ovrLimit,
    PlayerTier? tierLimit,
    bool premiumBadge = false,
    required TournamentStatus status,
    required DateTime createdAt,
    DateTime? updatedAt,
    required Map<String, int> slots,
    required Map<String, int> filledSlots,
    required List<String> participants,
    Map<String, dynamic>? rules,
    Map<String, dynamic>? results,
    double? distance,
    Map<String, dynamic>? discordChannels,
    GameFormat gameFormat = GameFormat.single,
    GameServer gameServer = GameServer.kr,
    String? customRoomName,
    String? customRoomPassword,
    List<String> referees = const [],
    bool isRefereed = false,
    String? hostPosition,
    required GameCategory gameCategory,
  }) {
    // 리그 오브 레전드 내전을 위한 기본 슬롯 - 각 라인 2명씩
    final defaultSlotsByRole = <String, int>{
      'top': 2,
      'jungle': 2,
      'mid': 2,
      'adc': 2,
      'support': 2,
    };
    
    final defaultFilledSlotsByRole = <String, int>{
      'top': 0,
      'jungle': 0,
      'mid': 0,
      'adc': 0,
      'support': 0,
    };

    final defaultParticipantsByRole = <String, List<String>>{
      'top': [],
      'jungle': [],
      'mid': [],
      'adc': [],
      'support': [],
    };
    
    return TournamentModel(
      id: id,
      title: title,
      description: description,
      hostId: hostId,
      hostName: hostName,
      hostProfileImageUrl: hostProfileImageUrl,
      hostNickname: hostNickname,
      startsAt: startsAt,
      location: location,
      tournamentType: tournamentType,
      gameCategory: gameCategory,
      creditCost: creditCost,
      ovrLimit: ovrLimit,
      tierLimit: tierLimit,
      premiumBadge: premiumBadge,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      slots: slots,
      filledSlots: filledSlots,
      slotsByRole: defaultSlotsByRole,
      filledSlotsByRole: defaultFilledSlotsByRole,
      participants: participants,
      participantsByRole: defaultParticipantsByRole,
      rules: rules,
      results: results,
      distance: distance,
      discordChannels: discordChannels,
      gameFormat: gameFormat,
      gameServer: gameServer,
      customRoomName: customRoomName,
      customRoomPassword: customRoomPassword,
      referees: referees,
      isRefereed: isRefereed || tournamentType == TournamentType.competitive,
      hostPosition: hostPosition,
    );
  }
  
  // Firestore에서 데이터 로드
  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Helper to safely convert dynamic values to int
    int _dynamicToInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }
    
    // 필수 타임스탬프 필드 안전하게 변환
    Timestamp startsAt;
    try {
      if (data['startsAt'] is Timestamp) {
        startsAt = data['startsAt'] as Timestamp;
      } else {
        startsAt = Timestamp.now();
        print('Warning: Invalid startsAt format for tournament ${doc.id}');
      }
    } catch (e) {
      print('Error parsing startsAt: $e');
      startsAt = Timestamp.now();
    }
    
    DateTime createdAt;
    try {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now();
        print('Warning: Invalid createdAt format for tournament ${doc.id}');
      }
    } catch (e) {
      print('Error parsing createdAt: $e');
      createdAt = DateTime.now();
    }
    
    DateTime? updatedAt;
    if (data['updatedAt'] != null) {
      try {
        if (data['updatedAt'] is Timestamp) {
          updatedAt = (data['updatedAt'] as Timestamp).toDate();
        }
      } catch (e) {
        print('Error parsing updatedAt: $e');
      }
    }
    
    // Status 안전하게 변환
    TournamentStatus status;
    try {
      final statusIndex = _dynamicToInt(data['status'], defaultValue: TournamentStatus.open.index);
      if (statusIndex >= 0 && statusIndex < TournamentStatus.values.length) {
        status = TournamentStatus.values[statusIndex];
      } else {
        status = TournamentStatus.open;
      }
    } catch (e) {
      print('Error parsing status: $e');
      status = TournamentStatus.open;
    }
    
    // GameFormat 안전하게 변환
    GameFormat gameFormat;
    try {
      final formatIndex = _dynamicToInt(data['gameFormat'], defaultValue: GameFormat.single.index);
      if (formatIndex >= 0 && formatIndex < GameFormat.values.length) {
        gameFormat = GameFormat.values[formatIndex];
      } else {
        gameFormat = GameFormat.single;
      }
    } catch (e) {
      print('Error parsing gameFormat: $e');
      gameFormat = GameFormat.single;
    }
    
    // GameServer 안전하게 변환
    GameServer gameServer;
    try {
      final serverIndex = _dynamicToInt(data['gameServer'], defaultValue: GameServer.kr.index);
      if (serverIndex >= 0 && serverIndex < GameServer.values.length) {
        gameServer = GameServer.values[serverIndex];
      } else {
        gameServer = GameServer.kr;
      }
    } catch (e) {
      print('Error parsing gameServer: $e');
      gameServer = GameServer.kr;
    }
    
    // 안전한 Map 변환 함수
    Map<String, int> getSafeIntMap(String key, Map<String, int> defaultValue) {
      if (data[key] == null) return defaultValue;
      try {
        if (data[key] is Map) {
          final rawMap = data[key] as Map;
          final result = <String, int>{};
          
          for (final entry in rawMap.entries) {
            result[entry.key.toString()] = _dynamicToInt(entry.value);
          }
          return result;
        }
        return defaultValue;
      } catch (e) {
        print('Error parsing $key: $e');
        return defaultValue;
      }
    }
    
    // 리그 오브 레전드 내전을 위한 기본 슬롯 - 각 라인 2명씩
    final defaultSlotsByRole = <String, int>{
      'top': 2,
      'jungle': 2,
      'mid': 2,
      'adc': 2,
      'support': 2,
    };
    
    final defaultFilledSlotsByRole = <String, int>{
      'top': 0,
      'jungle': 0,
      'mid': 0,
      'adc': 0,
      'support': 0,
    };

    final defaultParticipantsByRole = <String, List<String>>{
      'top': [],
      'jungle': [],
      'mid': [],
      'adc': [],
      'support': [],
    };
    
    // tierLimit을 문자열에서 PlayerTier enum으로 변환
    PlayerTier? tierLimit;
    if (data['tierLimit'] != null) {
      if (data['tierLimit'] is String) {
        tierLimit = UserModel.tierFromString(data['tierLimit'] as String);
      } else {
        final tierIndex = _dynamicToInt(data['tierLimit'], defaultValue: -1);
        if (tierIndex >= 0 && tierIndex < PlayerTier.values.length) {
          tierLimit = PlayerTier.values[tierIndex];
        }
      }
    }

    // 이전 버전 호환성 위한 코드
    // 더 명확한 로직으로 tournamentType 설정
    TournamentType tournamentType;
    
    // 1. 명시적 tournamentType 필드가 있는 경우
    if (data.containsKey('tournamentType')) {
      final typeIndex = _dynamicToInt(data['tournamentType'], defaultValue: TournamentType.casual.index);
      if (typeIndex >= 0 && typeIndex < TournamentType.values.length) {
        tournamentType = TournamentType.values[typeIndex];
      } else {
        // 인덱스가 범위를 벗어나면 기본값 사용
        tournamentType = TournamentType.casual;
      }
    }
    // 2. isPaid 필드가 있는 경우 (레거시 호환성)
    else if (data.containsKey('isPaid')) {
      tournamentType = data['isPaid'] == true
          ? TournamentType.competitive
          : TournamentType.casual;
    }
    // 3. 기본값 설정
    else {
      tournamentType = TournamentType.casual;
    }

    // GameCategory 파싱
    GameCategory gameCategory;
    if (data.containsKey('gameCategory')) {
      final categoryIndex = _dynamicToInt(data['gameCategory'], defaultValue: GameCategory.individual.index);
      if (categoryIndex >= 0 && categoryIndex < GameCategory.values.length) {
        gameCategory = GameCategory.values[categoryIndex];
      } else {
        gameCategory = GameCategory.individual;
      }
    } else {
      // 기본값: 개인전으로 설정 (하위 호환성)
      gameCategory = GameCategory.individual;
    }

    // 참가비를 크레딧으로 변환
    int? creditCost;
    if (tournamentType == TournamentType.competitive) {
      if (data.containsKey('creditCost')) {
        creditCost = _dynamicToInt(data['creditCost']);
      } else if (data.containsKey('price')) {
        creditCost = _dynamicToInt(data['price']);
      }
      
      // 경쟁전은 항상 크레딧 비용이 있어야 함 (기본값 20)
      creditCost ??= 20;
    }

    // 참가자 목록 처리 - List<dynamic>을 List<String>으로 안전하게 변환
    List<String> participants = [];
    if (data['participants'] != null) {
      participants = (data['participants'] as List)
          .map((item) => item.toString())
          .toList();
    }

    // 역할별 참가자 목록 변환
    Map<String, List<String>> participantsByRole = {};
    if (data['participantsByRole'] != null) {
      try {
        final rawMap = data['participantsByRole'] as Map<String, dynamic>;
        for (final entry in rawMap.entries) {
          if (entry.value is List) {
            participantsByRole[entry.key] = (entry.value as List)
                .map((item) => item.toString())
                .toList();
          } else {
            participantsByRole[entry.key] = [];
          }
        }
      } catch (e) {
        print('Error parsing participantsByRole: $e');
        participantsByRole = defaultParticipantsByRole;
      }
    } else {
      participantsByRole = defaultParticipantsByRole;
    }
    
    // 이전 데이터 구조에서 업데이트 (참가자 배열이 있지만 역할별 참가자 목록이 없는 경우)
    if (participants.isNotEmpty &&
        participantsByRole.values.every((list) => list.isEmpty)) {
      participantsByRole = defaultParticipantsByRole;
    }
    
    // 심판 관련 데이터 추출
    List<String> referees = [];
    if (data['rules'] != null && data['rules'] is Map<String, dynamic>) {
      final rulesMap = data['rules'] as Map<String, dynamic>;
      if (rulesMap.containsKey('referees') && rulesMap['referees'] is List) {
        try {
          referees = (rulesMap['referees'] as List)
              .map((item) => item.toString())
              .toList();
        } catch (e) {
          print('Error parsing referees: $e');
        }
      }
    }
    
    bool isRefereed = false;
    if (data['rules'] != null && data['rules'] is Map<String, dynamic>) {
      final rulesMap = data['rules'] as Map<String, dynamic>;
      if (rulesMap.containsKey('isRefereed') && rulesMap['isRefereed'] is bool) {
        isRefereed = rulesMap['isRefereed'];
      } else {
        isRefereed = tournamentType == TournamentType.competitive;
      }
    } else {
      isRefereed = tournamentType == TournamentType.competitive;
    }
    
    // hostProfileImageUrl 처리 - 빈 문자열이나 유효하지 않은 URL 처리
    String? hostProfileImageUrl = data['hostProfileImageUrl'];
    if (hostProfileImageUrl != null && (hostProfileImageUrl.isEmpty || !hostProfileImageUrl.startsWith('http'))) {
      hostProfileImageUrl = null;
    }
    
    return TournamentModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      hostProfileImageUrl: hostProfileImageUrl,
      hostNickname: data['hostNickname'] ?? data['hostName'] ?? '',
      startsAt: startsAt,
      location: data['location'] ?? '',
      tournamentType: tournamentType,
      creditCost: creditCost,
      ovrLimit: data.containsKey('ovrLimit') ? _dynamicToInt(data['ovrLimit']) : null,
      tierLimit: tierLimit,
      premiumBadge: data['premiumBadge'] ?? false,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      slots: getSafeIntMap('slots', {}),
      filledSlots: getSafeIntMap('filledSlots', {}),
      slotsByRole: getSafeIntMap('slotsByRole', defaultSlotsByRole),
      filledSlotsByRole: getSafeIntMap('filledSlotsByRole', defaultFilledSlotsByRole),
      participants: participants,
      participantsByRole: participantsByRole,
      rules: data['rules'],
      results: data['results'],
      distance: (data['distance'] as num?)?.toDouble(),
      discordChannels: data['discordChannels'],
      gameFormat: gameFormat,
      gameServer: gameServer,
      customRoomName: data['customRoomName'],
      customRoomPassword: data['customRoomPassword'],
      referees: referees,
      isRefereed: isRefereed,
      hostPosition: data['hostPosition'],
      gameCategory: GameCategory.values[data['gameCategory'] ?? 0],
    );
  }
  
  // Firestore에 저장할 데이터 변환
  Map<String, dynamic> toFirestore() {
    // 필수 필드 검증
    if (title.isEmpty) {
      throw Exception('제목이 비어있습니다');
    }
    
    if (hostId.isEmpty) {
      throw Exception('호스트 ID가 비어있습니다');
    }
    
    // 현재 rules 맵에 referees와 isRefereed 추가 (안전하게)
    final Map<String, dynamic> updatedRules = Map<String, dynamic>.from(rules ?? {});
    updatedRules['referees'] = referees;
    updatedRules['isRefereed'] = isRefereed;
    
    // 결과 데이터 준비 (null 필드 제외)
    final result = <String, dynamic>{
      'title': title,
      'description': description,
      'hostId': hostId,
      'hostName': hostName,
      'startsAt': startsAt,
      'location': location,
      'tournamentType': tournamentType.index,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'slots': slots,
      'filledSlots': filledSlots,
      'slotsByRole': slotsByRole,
      'filledSlotsByRole': filledSlotsByRole,
      'participants': participants,
      'participantsByRole': participantsByRole,
      'rules': updatedRules,
      'gameFormat': gameFormat.index,
      'gameServer': gameServer.index,
      'premiumBadge': premiumBadge,
      'gameCategory': gameCategory.index,
    };
    
    // 선택적 필드 추가 (null이 아닌 경우만)
    if (hostProfileImageUrl != null) result['hostProfileImageUrl'] = hostProfileImageUrl;
    if (hostNickname != null) result['hostNickname'] = hostNickname;
    if (creditCost != null) result['creditCost'] = creditCost;
    if (ovrLimit != null) result['ovrLimit'] = ovrLimit;
    if (tierLimit != null) result['tierLimit'] = tierLimit!.index;
    if (updatedAt != null) result['updatedAt'] = Timestamp.fromDate(updatedAt!);
    if (results != null) result['results'] = results;
    if (distance != null) result['distance'] = distance;
    if (discordChannels != null) result['discordChannels'] = discordChannels;
    if (customRoomName != null) result['customRoomName'] = customRoomName;
    if (customRoomPassword != null) result['customRoomPassword'] = customRoomPassword;
    if (_hostPosition != null) result['hostPosition'] = _hostPosition;
    
    return result;
  }
  
  // 업데이트된 TournamentModel 생성
  TournamentModel copyWith({
    String? title,
    String? description,
    String? hostId,
    String? hostName,
    String? hostProfileImageUrl,
    String? hostNickname,
    Timestamp? startsAt,
    String? location,
    TournamentType? tournamentType,
    int? creditCost,
    int? ovrLimit,
    PlayerTier? tierLimit,
    bool? premiumBadge,
    TournamentStatus? status,
    DateTime? updatedAt,
    Map<String, int>? slots,
    Map<String, int>? filledSlots,
    Map<String, int>? slotsByRole,
    Map<String, int>? filledSlotsByRole,
    List<String>? participants,
    Map<String, List<String>>? participantsByRole,
    Map<String, dynamic>? rules,
    Map<String, dynamic>? results,
    double? distance,
    Map<String, dynamic>? discordChannels,
    GameFormat? gameFormat,
    GameServer? gameServer,
    String? customRoomName,
    String? customRoomPassword,
    List<String>? referees,
    bool? isRefereed,
    String? hostPosition,
    GameCategory? gameCategory,
  }) {
    return TournamentModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostProfileImageUrl: hostProfileImageUrl ?? this.hostProfileImageUrl,
      hostNickname: hostNickname ?? this.hostNickname,
      startsAt: startsAt ?? this.startsAt,
      location: location ?? this.location,
      tournamentType: tournamentType ?? this.tournamentType,
      creditCost: creditCost ?? this.creditCost,
      ovrLimit: ovrLimit ?? this.ovrLimit,
      tierLimit: tierLimit ?? this.tierLimit,
      premiumBadge: premiumBadge ?? this.premiumBadge,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      slots: slots ?? this.slots,
      filledSlots: filledSlots ?? this.filledSlots,
      slotsByRole: slotsByRole ?? this.slotsByRole,
      filledSlotsByRole: filledSlotsByRole ?? this.filledSlotsByRole,
      participants: participants ?? this.participants,
      participantsByRole: participantsByRole ?? this.participantsByRole,
      rules: rules ?? this.rules,
      results: results ?? this.results,
      distance: distance ?? this.distance,
      discordChannels: discordChannels ?? this.discordChannels,
      gameFormat: gameFormat ?? this.gameFormat,
      gameServer: gameServer ?? this.gameServer,
      customRoomName: customRoomName ?? this.customRoomName,
      customRoomPassword: customRoomPassword ?? this.customRoomPassword,
      referees: referees ?? this.referees,
      isRefereed: isRefereed ?? this.isRefereed,
      hostPosition: hostPosition ?? this._hostPosition,
      gameCategory: gameCategory ?? this.gameCategory,
    );
  }
  
  // 모집 상태 계산
  bool get isFull {
    return slots.entries.every((entry) {
      final position = entry.key;
      final totalSlots = entry.value;
      final filled = filledSlots[position] ?? 0;
      return filled >= totalSlots;
    });
  }
  
  // 역할별 참가 가능 여부 확인
  bool canJoinRole(String role) {
    final totalSlots = slotsByRole[role] ?? 0;
    final filled = filledSlotsByRole[role] ?? 0;
    return filled < totalSlots && status == TournamentStatus.open;
  }
  
  // 사용자의 티어가 참가 가능 범위인지 확인
  bool isUserTierEligible(PlayerTier userTier) {
    // 티어 제한이 없거나 랜덤 멸망전인 경우 모든 티어 참가 가능
    if (tierLimit == null || tierLimit == PlayerTier.unranked) {
      return true;
    }
    
    // 티어 범위 규칙 확인 (rules에서 tierRules 가져오기)
    if (rules != null && rules is Map<String, dynamic>) {
      final rulesMap = rules!;
      if (rulesMap.containsKey('tierRules')) {
        final tierRules = rulesMap['tierRules'];
        if (tierRules is Map<String, dynamic>) {
          final minTierIndex = tierRules['minTier'] as int?;
          final maxTierIndex = tierRules['maxTier'] as int?;
          
          if (minTierIndex != null && maxTierIndex != null) {
            // 티어 인덱스가 허용 범위 내에 있는지 확인
            final userTierIndex = userTier.index;
            return userTierIndex >= minTierIndex && userTierIndex <= maxTierIndex;
          }
        }
      }
    }
    
    // 기존 로직: tierLimit 이상 (하위 호환성 유지)
    if (tierLimit != null) {
      return userTier.index >= tierLimit!.index;
    }
    
    // 모든 조건을 충족하지 않으면 기본적으로 참가 가능
    return true;
  }
  
  // 특정 역할에 참가자 추가 가능 여부 확인
  bool hasSpaceForRole(String role) {
    final maxParticipants = slotsByRole[role] ?? 0;
    final currentParticipants = participantsByRole[role]?.length ?? 0;
    return currentParticipants < maxParticipants;
  }
  
  // 누락된 게터 추가
  int get totalFilledSlots {
    return filledSlots.values.fold(0, (sum, count) => sum + count);
  }
  
  @override
  List<Object?> get props => [
    id, title, description, hostId, hostName, hostProfileImageUrl, hostNickname,
    startsAt, location, tournamentType, creditCost, ovrLimit, tierLimit, premiumBadge, 
    status, createdAt, updatedAt, slots, filledSlots, slotsByRole, filledSlotsByRole,
    participants, participantsByRole, rules, results, distance, 
    discordChannels, gameFormat, gameServer, customRoomName, customRoomPassword,
    referees, isRefereed, _hostPosition, gameCategory
  ];
} 