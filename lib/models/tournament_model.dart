import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TournamentStatus {
  draft,    // 초안 상태
  open,     // 참가자 모집 중
  full,     // 모집 완료
  ongoing,  // 진행 중
  completed,// 완료됨
  cancelled // 취소됨
}

class TournamentModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String hostId;
  final String hostName;
  final DateTime startsAt;
  final String location;
  final bool isPaid;
  final int? price;
  final TournamentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, int> slots;
  final Map<String, int> filledSlots;
  final List<String> participants;
  final Map<String, dynamic>? rules;
  final Map<String, dynamic>? results;
  
  const TournamentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.hostId,
    required this.hostName,
    required this.startsAt,
    required this.location,
    required this.isPaid,
    this.price,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.slots,
    required this.filledSlots,
    required this.participants,
    this.rules,
    this.results,
  });
  
  // Firestore에서 데이터 로드
  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TournamentModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      startsAt: (data['startsAt'] as Timestamp).toDate(),
      location: data['location'] ?? '',
      isPaid: data['isPaid'] ?? false,
      price: data['price'],
      status: TournamentStatus.values[data['status'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      slots: Map<String, int>.from(data['slots'] ?? {}),
      filledSlots: Map<String, int>.from(data['filledSlots'] ?? {}),
      participants: List<String>.from(data['participants'] ?? []),
      rules: data['rules'],
      results: data['results'],
    );
  }
  
  // Firestore에 저장할 데이터 변환
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'hostId': hostId,
      'hostName': hostName,
      'startsAt': Timestamp.fromDate(startsAt),
      'location': location,
      'isPaid': isPaid,
      'price': price,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'slots': slots,
      'filledSlots': filledSlots,
      'participants': participants,
      'rules': rules,
      'results': results,
    };
  }
  
  // 업데이트된 TournamentModel 생성
  TournamentModel copyWith({
    String? title,
    String? description,
    String? hostId,
    String? hostName,
    DateTime? startsAt,
    String? location,
    bool? isPaid,
    int? price,
    TournamentStatus? status,
    DateTime? updatedAt,
    Map<String, int>? slots,
    Map<String, int>? filledSlots,
    List<String>? participants,
    Map<String, dynamic>? rules,
    Map<String, dynamic>? results,
  }) {
    return TournamentModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      startsAt: startsAt ?? this.startsAt,
      location: location ?? this.location,
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      slots: slots ?? this.slots,
      filledSlots: filledSlots ?? this.filledSlots,
      participants: participants ?? this.participants,
      rules: rules ?? this.rules,
      results: results ?? this.results,
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
  
  @override
  List<Object?> get props => [
    id, title, description, hostId, hostName, startsAt, location,
    isPaid, price, status, createdAt, updatedAt, slots, filledSlots,
    participants, rules, results
  ];
} 