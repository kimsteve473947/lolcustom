import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentStatus {
  open,
  full,
  inProgress,
  completed,
  cancelled
}

class TournamentModel {
  final String id;
  final String hostUid;
  final String hostNickname;
  final String? hostProfileImageUrl;
  final Timestamp startsAt;
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
  final Timestamp createdAt;
  final String? description;

  TournamentModel({
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
  });

  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle the slots by role map
    Map<String, int> slotsByRole = {
      'top': 2,
      'jungle': 2,
      'mid': 2,
      'adc': 2,
      'support': 2,
    };
    
    if (data['slotsByRole'] != null) {
      Map<String, dynamic> slotsData = data['slotsByRole'];
      slotsData.forEach((key, value) {
        slotsByRole[key] = value as int;
      });
    }
    
    // Handle the filled slots by role map
    Map<String, int> filledSlotsByRole = {
      'top': 0,
      'jungle': 0,
      'mid': 0,
      'adc': 0,
      'support': 0,
    };
    
    if (data['filledSlotsByRole'] != null) {
      Map<String, dynamic> filledSlotsData = data['filledSlotsByRole'];
      filledSlotsData.forEach((key, value) {
        filledSlotsByRole[key] = value as int;
      });
    }

    return TournamentModel(
      id: doc.id,
      hostUid: data['hostUid'] ?? '',
      hostNickname: data['hostNickname'] ?? 'Unknown',
      hostProfileImageUrl: data['hostProfileImageUrl'],
      startsAt: data['startsAt'] ?? Timestamp.now(),
      location: data['location'] ?? 'Unknown Location',
      locationCoordinates: data['locationCoordinates'],
      distance: null, // To be calculated on client
      ovrLimit: data['ovrLimit'],
      isPaid: data['isPaid'] ?? false,
      price: data['price'],
      premiumBadge: data['premiumBadge'] ?? false,
      slotsByRole: slotsByRole,
      filledSlotsByRole: filledSlotsByRole,
      status: TournamentStatus.values[data['status'] ?? 0],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      description: data['description'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostUid': hostUid,
      'hostNickname': hostNickname,
      'hostProfileImageUrl': hostProfileImageUrl,
      'startsAt': startsAt,
      'location': location,
      'locationCoordinates': locationCoordinates,
      'ovrLimit': ovrLimit,
      'isPaid': isPaid,
      'price': price,
      'premiumBadge': premiumBadge,
      'slotsByRole': slotsByRole,
      'filledSlotsByRole': filledSlotsByRole,
      'status': status.index,
      'createdAt': createdAt,
      'description': description,
    };
  }

  TournamentModel copyWith({
    String? id,
    String? hostUid,
    String? hostNickname,
    String? hostProfileImageUrl,
    Timestamp? startsAt,
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
    Timestamp? createdAt,
    String? description,
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
    );
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
} 