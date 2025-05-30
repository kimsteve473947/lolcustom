import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TournamentStatus {
  pending,
  active,
  completed,
  cancelled
}

class TournamentModel extends Equatable {
  final String id;
  final String hostUid;
  final String hostNickname;
  final String? hostProfileImageUrl;
  final DateTime startsAt;
  final String location;
  final GeoPoint? locationCoordinates;
  final double? distance; // Not stored, calculated on client
  final int? ovrLimit;
  final bool isPaid;
  final int? price;
  final bool premiumBadge;
  final Map<String, int> slotsByRole;
  final Map<String, int> filledSlotsByRole;
  final TournamentStatus status;
  final DateTime createdAt;
  final String? description;
  final List<String>? participantUids;
  
  const TournamentModel({
    required this.id,
    required this.hostUid,
    required this.hostNickname,
    this.hostProfileImageUrl,
    required this.startsAt,
    required this.location,
    this.locationCoordinates,
    this.distance,
    this.ovrLimit,
    required this.isPaid,
    this.price,
    this.premiumBadge = false,
    required this.slotsByRole,
    required this.filledSlotsByRole,
    required this.status,
    required this.createdAt,
    this.description,
    this.participantUids,
  });
  
  @override
  List<Object?> get props => [
    id, hostUid, hostNickname, hostProfileImageUrl, startsAt, 
    location, locationCoordinates, distance, ovrLimit, 
    isPaid, price, premiumBadge, slotsByRole, filledSlotsByRole,
    status, createdAt, description, participantUids
  ];
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostUid': hostUid,
      'hostNickname': hostNickname,
      'hostProfileImageUrl': hostProfileImageUrl,
      'startsAt': Timestamp.fromDate(startsAt),
      'location': location,
      'locationCoordinates': locationCoordinates,
      'ovrLimit': ovrLimit,
      'isPaid': isPaid,
      'price': price,
      'premiumBadge': premiumBadge,
      'slotsByRole': slotsByRole,
      'filledSlotsByRole': filledSlotsByRole,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'description': description,
      'participantUids': participantUids,
    };
  }
  
  factory TournamentModel.fromMap(Map<String, dynamic> map) {
    return TournamentModel(
      id: map['id'] ?? '',
      hostUid: map['hostUid'] ?? '',
      hostNickname: map['hostNickname'] ?? 'Unknown',
      hostProfileImageUrl: map['hostProfileImageUrl'],
      startsAt: (map['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: map['location'] ?? 'Unknown Location',
      locationCoordinates: map['locationCoordinates'],
      distance: map['distance']?.toDouble(),
      ovrLimit: map['ovrLimit'],
      isPaid: map['isPaid'] ?? false,
      price: map['price'],
      premiumBadge: map['premiumBadge'] ?? false,
      slotsByRole: Map<String, int>.from(map['slotsByRole'] ?? {}),
      filledSlotsByRole: Map<String, int>.from(map['filledSlotsByRole'] ?? {}),
      status: TournamentStatus.values[map['status'] ?? 0],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'],
      participantUids: map['participantUids'] != null ? List<String>.from(map['participantUids']) : null,
    );
  }
  
  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return TournamentModel.fromMap(data);
  }
  
  bool get isFull {
    bool allFull = true;
    slotsByRole.forEach((role, totalSlots) {
      int filled = filledSlotsByRole[role] ?? 0;
      if (filled < totalSlots) {
        allFull = false;
      }
    });
    return allFull;
  }
  
  int get totalSlots {
    int total = 0;
    slotsByRole.forEach((_, count) => total += count);
    return total;
  }
  
  int get totalFilledSlots {
    int total = 0;
    filledSlotsByRole.forEach((_, count) => total += count);
    return total;
  }
  
  // 남은 슬롯 수
  int get remainingSlots => totalSlots - totalFilledSlots;
  
  // 역할별 남은 슬롯 수
  Map<String, int> get remainingSlotsByRole {
    final Map<String, int> remaining = {};
    slotsByRole.forEach((role, total) {
      final filled = filledSlotsByRole[role] ?? 0;
      remaining[role] = total - filled;
    });
    return remaining;
  }
  
  // 해당 포지션에 빈 자리가 있는지 확인
  bool hasAvailableSlot(String role) {
    final total = slotsByRole[role] ?? 0;
    final filled = filledSlotsByRole[role] ?? 0;
    return filled < total;
  }
  
  // 예약 가능 여부 확인
  bool get isBookable {
    return status == TournamentStatus.pending && !isFull && startsAt.isAfter(DateTime.now());
  }
  
  // 예약 완료 후 모델 업데이트
  TournamentModel applyReservation(String role) {
    if (!hasAvailableSlot(role)) {
      throw Exception('This position is already full');
    }
    
    final updatedFilledSlots = Map<String, int>.from(filledSlotsByRole);
    updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 0) + 1;
    
    return copyWith(
      filledSlotsByRole: updatedFilledSlots,
    );
  }
  
  TournamentModel copyWith({
    String? id,
    String? hostUid,
    String? hostNickname,
    String? hostProfileImageUrl,
    DateTime? startsAt,
    String? location,
    GeoPoint? locationCoordinates,
    double? distance,
    int? ovrLimit,
    bool? isPaid,
    int? price,
    bool? premiumBadge,
    Map<String, int>? slotsByRole,
    Map<String, int>? filledSlotsByRole,
    TournamentStatus? status,
    DateTime? createdAt,
    String? description,
    List<String>? participantUids,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      hostUid: hostUid ?? this.hostUid,
      hostNickname: hostNickname ?? this.hostNickname,
      hostProfileImageUrl: hostProfileImageUrl ?? this.hostProfileImageUrl,
      startsAt: startsAt ?? this.startsAt,
      location: location ?? this.location,
      locationCoordinates: locationCoordinates ?? this.locationCoordinates,
      distance: distance ?? this.distance,
      ovrLimit: ovrLimit ?? this.ovrLimit,
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      premiumBadge: premiumBadge ?? this.premiumBadge,
      slotsByRole: slotsByRole ?? this.slotsByRole,
      filledSlotsByRole: filledSlotsByRole ?? this.filledSlotsByRole,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      participantUids: participantUids ?? this.participantUids,
    );
  }
  
  factory TournamentModel.empty() {
    return TournamentModel(
      id: '',
      hostUid: '',
      hostNickname: '',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      location: '',
      isPaid: false,
      slotsByRole: {
        'top': 2,
        'jungle': 2,
        'mid': 2,
        'adc': 2,
        'support': 2,
      },
      filledSlotsByRole: {
        'top': 0,
        'jungle': 0,
        'mid': 0,
        'adc': 0,
        'support': 0,
      },
      status: TournamentStatus.pending,
      createdAt: DateTime.now(),
    );
  }
} 