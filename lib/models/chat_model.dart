import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatRoomType {
  tournamentRecruitment,
  mercenaryOffer,
  direct
}

class ChatRoomModel {
  final String id;
  final String title;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantProfileImages;
  final String? lastMessageText;
  final Timestamp? lastMessageTime;
  final Map<String, int> unreadCount;
  final ChatRoomType type;
  final String? tournamentId;
  final Timestamp createdAt;
  final int participantCount; // Number of participants
  final List<String> hiddenFor; // List of user UIDs who have "left" the chat

  ChatRoomModel({
    required this.id,
    required this.title,
    required this.participantIds,
    required this.participantNames,
    required this.participantProfileImages,
    this.lastMessageText,
    this.lastMessageTime,
    required this.unreadCount,
    required this.type,
    this.tournamentId,
    required this.createdAt,
    this.participantCount = 0, // Default to 0 if not provided
    this.hiddenFor = const [],
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle participants
    List<String> participantIds = [];
    if (data['participantIds'] != null) {
      for (var id in data['participantIds']) {
        participantIds.add(id as String);
      }
    }
    
    // Handle participant names
    Map<String, String> participantNames = {};
    if (data['participantNames'] != null) {
      Map<String, dynamic> namesData = data['participantNames'];
      namesData.forEach((key, value) {
        participantNames[key] = value as String;
      });
    }
    
    // Handle participant profile images
    Map<String, String?> participantProfileImages = {};
    if (data['participantProfileImages'] != null) {
      Map<String, dynamic> imagesData = data['participantProfileImages'];
      imagesData.forEach((key, value) {
        participantProfileImages[key] = value as String?;
      });
    }
    
    // Handle unread count
    Map<String, int> unreadCount = {};
    if (data['unreadCount'] != null) {
      Map<String, dynamic> countData = data['unreadCount'];
      countData.forEach((key, value) {
        unreadCount[key] = value as int;
      });
    }

    return ChatRoomModel(
      id: doc.id,
      title: data['title'] ?? 'Chat Room',
      participantIds: participantIds,
      participantNames: participantNames,
      participantProfileImages: participantProfileImages,
      lastMessageText: data['lastMessageText'],
      lastMessageTime: data['lastMessageTime'],
      unreadCount: unreadCount,
      type: ChatRoomType.values[data['type'] ?? 0],
      tournamentId: data['tournamentId'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      participantCount: data['participantCount'] ?? participantIds.length, // Use length as fallback
      hiddenFor: List<String>.from(data['hiddenFor'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantProfileImages': participantProfileImages,
      'lastMessageText': lastMessageText,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
      'type': type.index,
      'tournamentId': tournamentId,
      'createdAt': createdAt,
      'participantCount': participantCount,
      'hiddenFor': hiddenFor,
    };
  }

  ChatRoomModel copyWith({
    String? id,
    String? title,
    List<String>? participantIds,
    Map<String, String>? participantNames,
    Map<String, String?>? participantProfileImages,
    String? lastMessageText,
    Timestamp? lastMessageTime,
    Map<String, int>? unreadCount,
    ChatRoomType? type,
    String? tournamentId,
    Timestamp? createdAt,
    int? participantCount,
    List<String>? hiddenFor,
  }) {
    return ChatRoomModel(
      id: id ?? this.id,
      title: title ?? this.title,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      participantProfileImages: participantProfileImages ?? this.participantProfileImages,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      type: type ?? this.type,
      tournamentId: tournamentId ?? this.tournamentId,
      createdAt: createdAt ?? this.createdAt,
      participantCount: participantCount ?? this.participantCount,
      hiddenFor: hiddenFor ?? this.hiddenFor,
    );
  }
}

class MessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String? senderProfileImageUrl;
  final String text;
  final Map<String, bool> readStatus;
  final Timestamp timestamp;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    this.senderProfileImageUrl,
    required this.text,
    required this.readStatus,
    required this.timestamp,
    this.imageUrl,
    this.metadata,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle read status
    Map<String, bool> readStatus = {};
    if (data['readStatus'] != null) {
      Map<String, dynamic> statusData = data['readStatus'];
      statusData.forEach((key, value) {
        readStatus[key] = value as bool;
      });
    }

    return MessageModel(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderProfileImageUrl: data['senderProfileImageUrl'],
      text: data['text'] ?? '',
      readStatus: readStatus,
      timestamp: data['timestamp'] ?? Timestamp.now(),
      imageUrl: data['imageUrl'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfileImageUrl': senderProfileImageUrl,
      'text': text,
      'readStatus': readStatus,
      'timestamp': timestamp,
      'imageUrl': imageUrl,
      'metadata': metadata,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? senderName,
    String? senderProfileImageUrl,
    String? text,
    Map<String, bool>? readStatus,
    Timestamp? timestamp,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfileImageUrl: senderProfileImageUrl ?? this.senderProfileImageUrl,
      text: text ?? this.text,
      readStatus: readStatus ?? this.readStatus,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      metadata: metadata ?? this.metadata,
    );
  }
} 