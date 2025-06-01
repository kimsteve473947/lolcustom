import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TournamentStatus {
  draft,    // 초안 상태
  open,     // 참가자 모집 중
  full,     // 모집 완료
  inProgress, // 진행 중
  ongoing,  // 진행 중 (레거시 - 호환성 유지)
  completed,// 완료됨
  cancelled // 취소됨
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
  final String location;
  final bool isPaid;
  final int? price;
  final int? ovrLimit;
  final bool premiumBadge;
  final TournamentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, int> slots;
  final Map<String, int> filledSlots;
  final Map<String, int> slotsByRole;
  final Map<String, int> filledSlotsByRole;
  final List<String> participants;
  final Map<String, dynamic>? rules;
  final Map<String, dynamic>? results;
  final double? distance;
  
  // hostId 대신 hostUid를 사용할 수 있도록 게터 추가
  String get hostUid => hostId;
  
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
    required this.isPaid,
    this.price,
    this.ovrLimit,
    this.premiumBadge = false,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.slots,
    required this.filledSlots,
    required this.slotsByRole,
    required this.filledSlotsByRole,
    required this.participants,
    this.rules,
    this.results,
    this.distance,
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
    required bool isPaid,
    int? price,
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
  }) {
    final defaultSlotsByRole = <String, int>{
      'top': 1,
      'jungle': 1,
      'mid': 1,
      'adc': 1,
      'support': 1,
    };
    
    final defaultFilledSlotsByRole = <String, int>{
      'top': 0,
      'jungle': 0,
      'mid': 0,
      'adc': 0,
      'support': 0,
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
      isPaid: isPaid,
      price: price,
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
      rules: rules,
      results: results,
      distance: distance,
    );
  }
  
  // Firestore에서 데이터 로드
  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final defaultSlotsByRole = <String, int>{
      'top': 1,
      'jungle': 1,
      'mid': 1,
      'adc': 1,
      'support': 1,
    };
    
    final defaultFilledSlotsByRole = <String, int>{
      'top': 0,
      'jungle': 0,
      'mid': 0,
      'adc': 0,
      'support': 0,
    };
    
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
      isPaid: data['isPaid'] ?? false,
      price: data['price'],
      ovrLimit: data['ovrLimit'],
      premiumBadge: data['premiumBadge'] ?? false,
      status: TournamentStatus.values[data['status'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      slots: Map<String, int>.from(data['slots'] ?? {}),
      filledSlots: Map<String, int>.from(data['filledSlots'] ?? {}),
      slotsByRole: Map<String, int>.from(data['slotsByRole'] ?? defaultSlotsByRole),
      filledSlotsByRole: Map<String, int>.from(data['filledSlotsByRole'] ?? defaultFilledSlotsByRole),
      participants: List<String>.from(data['participants'] ?? []),
      rules: data['rules'],
      results: data['results'],
      distance: data['distance']?.toDouble(),
    );
  }
  
  // Firestore에 저장할 데이터 변환
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'hostId': hostId,
      'hostName': hostName,
      'hostProfileImageUrl': hostProfileImageUrl,
      'hostNickname': hostNickname,
      'startsAt': startsAt,
      'location': location,
      'isPaid': isPaid,
      'price': price,
      'ovrLimit': ovrLimit,
      'premiumBadge': premiumBadge,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'slots': slots,
      'filledSlots': filledSlots,
      'slotsByRole': slotsByRole,
      'filledSlotsByRole': filledSlotsByRole,
      'participants': participants,
      'rules': rules,
      'results': results,
      'distance': distance,
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
    bool? isPaid,
    int? price,
    int? ovrLimit,
    bool? premiumBadge,
    TournamentStatus? status,
    DateTime? updatedAt,
    Map<String, int>? slots,
    Map<String, int>? filledSlots,
    Map<String, int>? slotsByRole,
    Map<String, int>? filledSlotsByRole,
    List<String>? participants,
    Map<String, dynamic>? rules,
    Map<String, dynamic>? results,
    double? distance,
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
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      ovrLimit: ovrLimit ?? this.ovrLimit,
      premiumBadge: premiumBadge ?? this.premiumBadge,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      slots: slots ?? this.slots,
      filledSlots: filledSlots ?? this.filledSlots,
      slotsByRole: slotsByRole ?? this.slotsByRole,
      filledSlotsByRole: filledSlotsByRole ?? this.filledSlotsByRole,
      participants: participants ?? this.participants,
      rules: rules ?? this.rules,
      results: results ?? this.results,
      distance: distance ?? this.distance,
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
  
  // 예약 가능 여부 확인
  bool canJoin(String position) {
    final totalSlots = slots[position] ?? 0;
    final filled = filledSlots[position] ?? 0;
    return filled < totalSlots && status == TournamentStatus.open;
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
    startsAt, location, isPaid, price, ovrLimit, premiumBadge, status, createdAt, 
    updatedAt, slots, filledSlots, slotsByRole, filledSlotsByRole,
    participants, rules, results, distance
  ];
} 