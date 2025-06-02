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
    this.gameFormat = GameFormat.single,
    this.gameServer = GameServer.kr,
    this.customRoomName,
    this.customRoomPassword,
    this.referees = const [],
    this.isRefereed = false,
  });
  
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
    GameFormat gameFormat = GameFormat.single,
    GameServer gameServer = GameServer.kr,
    String? customRoomName,
    String? customRoomPassword,
    List<String> referees = const [],
    bool isRefereed = false,
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
      creditCost: creditCost,
      ovrLimit: ovrLimit,
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
      gameFormat: gameFormat,
      gameServer: gameServer,
      customRoomName: customRoomName,
      customRoomPassword: customRoomPassword,
      referees: referees,
      isRefereed: isRefereed || tournamentType == TournamentType.competitive,
    );
  }
  
  // Firestore에서 데이터 로드
  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 롤 내전을 위한 기본 슬롯 - 각 라인 2명씩
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
      if (data['tierLimit'] is int) {
        tierLimit = PlayerTier.values[data['tierLimit'] as int];
      } else if (data['tierLimit'] is String) {
        tierLimit = UserModel.tierFromString(data['tierLimit'] as String);
      }
    }

    // 이전 버전 호환성 유지를 위한 코드
    // isPaid 필드가 있으면 그에 따라 tournamentType 설정
    TournamentType tournamentType;
    if (data.containsKey('isPaid')) {
      tournamentType = data['isPaid'] == true 
          ? TournamentType.competitive 
          : TournamentType.casual;
    } else {
      tournamentType = data['tournamentType'] != null
          ? TournamentType.values[data['tournamentType'] as int]
          : TournamentType.casual;
    }

    // 참가비를 크레딧으로 변환
    int? creditCost;
    if (tournamentType == TournamentType.competitive) {
      if (data.containsKey('price')) {
        creditCost = data['creditCost'] ?? data['price'] ?? 20; // 기본값 20 크레딧
      } else {
        creditCost = data['creditCost'] ?? 20;
      }
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
    if (data['rules'] != null && data['rules']['referees'] is List) {
      try {
        referees = (data['rules']['referees'] as List)
            .map((item) => item.toString())
            .toList();
      } catch (e) {
        print('Error parsing referees: $e');
      }
    }
    
    bool isRefereed = false;
    if (data['rules'] != null && data['rules']['isRefereed'] is bool) {
      isRefereed = data['rules']['isRefereed'];
    } else {
      isRefereed = tournamentType == TournamentType.competitive;
    }
    
    return TournamentModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      hostProfileImageUrl: data['hostProfileImageUrl'],
      hostNickname: data['hostNickname'] ?? data['hostName'] ?? '',
      startsAt: data['startsAt'] as Timestamp,
      location: data['location'] ?? '',
      tournamentType: tournamentType,
      creditCost: creditCost,
      ovrLimit: data['ovrLimit'],
      tierLimit: tierLimit,
      premiumBadge: data['premiumBadge'] ?? false,
      status: TournamentStatus.values[data['status'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      slots: Map<String, int>.from(data['slots'] ?? {}),
      filledSlots: Map<String, int>.from(data['filledSlots'] ?? {}),
      slotsByRole: Map<String, int>.from(data['slotsByRole'] ?? defaultSlotsByRole),
      filledSlotsByRole: Map<String, int>.from(data['filledSlotsByRole'] ?? defaultFilledSlotsByRole),
      participants: participants,
      participantsByRole: participantsByRole,
      rules: data['rules'],
      results: data['results'],
      distance: data['distance']?.toDouble(),
      gameFormat: GameFormat.values[data['gameFormat'] ?? 0],
      gameServer: GameServer.values[data['gameServer'] ?? 0],
      customRoomName: data['customRoomName'],
      customRoomPassword: data['customRoomPassword'],
      referees: referees,
      isRefereed: isRefereed,
    );
  }
  
  // Firestore에 저장할 데이터 변환
  Map<String, dynamic> toFirestore() {
    // 현재 rules 맵에 referees와 isRefereed 추가
    final Map<String, dynamic> updatedRules = Map<String, dynamic>.from(rules ?? {});
    updatedRules['referees'] = referees;
    updatedRules['isRefereed'] = isRefereed;
    
    return {
      'title': title,
      'description': description,
      'hostId': hostId,
      'hostName': hostName,
      'hostProfileImageUrl': hostProfileImageUrl,
      'hostNickname': hostNickname,
      'startsAt': startsAt,
      'location': location,
      'tournamentType': tournamentType.index,
      'creditCost': creditCost,
      'ovrLimit': ovrLimit,
      'tierLimit': tierLimit?.index,
      'premiumBadge': premiumBadge,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'slots': slots,
      'filledSlots': filledSlots,
      'slotsByRole': slotsByRole,
      'filledSlotsByRole': filledSlotsByRole,
      'participants': participants,
      'participantsByRole': participantsByRole,
      'rules': updatedRules,
      'results': results,
      'distance': distance,
      'gameFormat': gameFormat.index,
      'gameServer': gameServer.index,
      'customRoomName': customRoomName,
      'customRoomPassword': customRoomPassword,
    };
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
    GameFormat? gameFormat,
    GameServer? gameServer,
    String? customRoomName,
    String? customRoomPassword,
    List<String>? referees,
    bool? isRefereed,
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
      gameFormat: gameFormat ?? this.gameFormat,
      gameServer: gameServer ?? this.gameServer,
      customRoomName: customRoomName ?? this.customRoomName,
      customRoomPassword: customRoomPassword ?? this.customRoomPassword,
      referees: referees ?? this.referees,
      isRefereed: isRefereed ?? this.isRefereed,
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
  
  // 특정 역할에 참가자 추가 가능 여부 확인
  bool hasSpaceForRole(String role) {
    final maxParticipants = slotsByRole[role] ?? 0;
    final currentParticipants = participantsByRole[role]?.length ?? 0;
    return currentParticipants < maxParticipants;
  }
  
  // 누락된 게터 추가
  int get totalSlots {
    return slots.values.fold(0, (sum, count) => sum + count);
  }
  
  int get totalFilledSlots {
    return filledSlots.values.fold(0, (sum, count) => sum + count);
  }
  
  @override
  List<Object?> get props => [
    id, title, description, hostId, hostName, hostProfileImageUrl, hostNickname,
    startsAt, location, tournamentType, creditCost, ovrLimit, tierLimit, premiumBadge, 
    status, createdAt, updatedAt, slots, filledSlots, slotsByRole, filledSlotsByRole,
    participants, participantsByRole, rules, results, distance, 
    gameFormat, gameServer, customRoomName, customRoomPassword,
    referees, isRefereed
  ];
} 