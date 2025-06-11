import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class DirectMessageRoom extends Equatable {
  final String id;
  final String userId1;
  final String userId2;
  final String user1Name;
  final String user2Name;
  final String? user1ProfileUrl;
  final String? user2ProfileUrl;
  final String? lastMessageText;
  final Timestamp? lastMessageTime;
  final Map<String, int> unreadCount;
  final Timestamp createdAt;
  final bool user1Active;
  final bool user2Active;

  const DirectMessageRoom({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.user1Name,
    required this.user2Name,
    this.user1ProfileUrl,
    this.user2ProfileUrl,
    this.lastMessageText,
    this.lastMessageTime,
    required this.unreadCount,
    required this.createdAt,
    required this.user1Active,
    required this.user2Active,
  });

  factory DirectMessageRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectMessageRoom(
      id: doc.id,
      userId1: data['userId1'] ?? '',
      userId2: data['userId2'] ?? '',
      user1Name: data['user1Name'] ?? '',
      user2Name: data['user2Name'] ?? '',
      user1ProfileUrl: data['user1ProfileUrl'],
      user2ProfileUrl: data['user2ProfileUrl'],
      lastMessageText: data['lastMessageText'],
      lastMessageTime: data['lastMessageTime'],
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      user1Active: data['user1Active'] ?? true,
      user2Active: data['user2Active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId1': userId1,
      'userId2': userId2,
      'user1Name': user1Name,
      'user2Name': user2Name,
      'user1ProfileUrl': user1ProfileUrl,
      'user2ProfileUrl': user2ProfileUrl,
      'lastMessageText': lastMessageText,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
      'createdAt': createdAt,
      'user1Active': user1Active,
      'user2Active': user2Active,
    };
  }

  DirectMessageRoom copyWith({
    String? id,
    String? userId1,
    String? userId2,
    String? user1Name,
    String? user2Name,
    String? user1ProfileUrl,
    String? user2ProfileUrl,
    String? lastMessageText,
    Timestamp? lastMessageTime,
    Map<String, int>? unreadCount,
    Timestamp? createdAt,
    bool? user1Active,
    bool? user2Active,
  }) {
    return DirectMessageRoom(
      id: id ?? this.id,
      userId1: userId1 ?? this.userId1,
      userId2: userId2 ?? this.userId2,
      user1Name: user1Name ?? this.user1Name,
      user2Name: user2Name ?? this.user2Name,
      user1ProfileUrl: user1ProfileUrl ?? this.user1ProfileUrl,
      user2ProfileUrl: user2ProfileUrl ?? this.user2ProfileUrl,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      user1Active: user1Active ?? this.user1Active,
      user2Active: user2Active ?? this.user2Active,
    );
  }

  @override
  List<Object?> get props => [
    id, userId1, userId2, user1Name, user2Name, user1ProfileUrl, user2ProfileUrl,
    lastMessageText, lastMessageTime, unreadCount, createdAt, user1Active, user2Active,
  ];
  
  // Helper method to check if a user is part of this room
  bool hasUser(String userId) {
    return userId == userId1 || userId == userId2;
  }
  
  // Helper method to get the other user's ID
  String getOtherUserId(String userId) {
    return userId == userId1 ? userId2 : userId1;
  }
  
  // Helper method to get the other user's name
  String getOtherUserName(String userId) {
    return userId == userId1 ? user2Name : user1Name;
  }
  
  // Helper method to get the other user's profile URL
  String? getOtherUserProfileUrl(String userId) {
    return userId == userId1 ? user2ProfileUrl : user1ProfileUrl;
  }
  
  // Helper method to get the unread count for a specific user
  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }
  
  // Helper method to check if the room is active for a specific user
  bool isActiveFor(String userId) {
    return userId == userId1 ? user1Active : user2Active;
  }
}

class DirectMessage extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderProfileUrl;
  final String text;
  final String? imageUrl;
  final Timestamp timestamp;

  const DirectMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderProfileUrl,
    required this.text,
    this.imageUrl,
    required this.timestamp,
  });

  factory DirectMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectMessage(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderProfileUrl: data['senderProfileUrl'],
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfileUrl': senderProfileUrl,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
    };
  }

  DirectMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderProfileUrl,
    String? text,
    String? imageUrl,
    Timestamp? timestamp,
  }) {
    return DirectMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfileUrl: senderProfileUrl ?? this.senderProfileUrl,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
    id, roomId, senderId, senderName, senderProfileUrl, text, imageUrl, timestamp,
  ];
} 