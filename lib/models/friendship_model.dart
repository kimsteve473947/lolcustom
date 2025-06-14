import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  pending,
  accepted,
  rejected,
  none, // No request exists
}

class Friendship {
  final String id;
  final String requesterId;
  final String receiverId;
  final FriendshipStatus status;
  final Timestamp createdAt;

  Friendship({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  factory Friendship.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friendship(
      id: doc.id,
      requesterId: data['requesterId'],
      receiverId: data['receiverId'],
      status: FriendshipStatus.values[data['status'] ?? FriendshipStatus.none.index],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'receiverId': receiverId,
      'status': status.index,
      'createdAt': createdAt,
    };
  }
}