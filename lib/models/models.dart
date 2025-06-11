export 'user_model.dart';
export 'mercenary_model.dart';
export 'tournament_model.dart';
export 'application_model.dart';
export 'chat_model.dart';
export 'rating_model.dart';
export 'direct_message_model.dart';

// Simple model definitions for missing classes
// ClanModel - 클랜 관련 모델
class ClanModel {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  
  ClanModel({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
  });
}

// NotificationModel - 알림 관련 모델
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  
  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });
} 