import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

enum GameMode {
  soloRank,
  flexRank,
  normal,
  aram,
}

class DuoPostModel {
  final String id;
  final String uid;
  final String nickname;
  final String? profileImageUrl;
  final PlayerTier tier;
  final String mainPosition;
  final String? subPosition;
  final bool micEnabled;
  final Timestamp createdAt;
  final Timestamp expiresAt;
  final GameMode gameMode;
  final String? content;
  final int views;
  final bool isOnline;

  DuoPostModel({
    required this.id,
    required this.uid,
    required this.nickname,
    this.profileImageUrl,
    required this.tier,
    required this.mainPosition,
    this.subPosition,
    required this.micEnabled,
    required this.createdAt,
    required this.expiresAt,
    required this.gameMode,
    this.content,
    this.views = 0,
    this.isOnline = true,
  });

  factory DuoPostModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DuoPostModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      tier: PlayerTier.values.firstWhere(
        (e) => e.toString() == data['tier'] || e.index == data['tier'],
        orElse: () => PlayerTier.unranked,
      ),
      mainPosition: data['mainPosition'] ?? 'FILL',
      subPosition: data['subPosition'],
      micEnabled: data['micEnabled'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      expiresAt: data['expiresAt'] ?? Timestamp.now(),
      gameMode: GameMode.values.firstWhere(
        (e) => e.toString() == data['gameMode'] || e.index == data['gameMode'],
        orElse: () => GameMode.soloRank,
      ),
      content: data['content'],
      views: data['views'] ?? 0,
      isOnline: data['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'tier': tier.index,
      'mainPosition': mainPosition,
      'subPosition': subPosition,
      'micEnabled': micEnabled,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'gameMode': gameMode.index,
      'content': content,
      'views': views,
      'isOnline': isOnline,
    };
  }
}

extension GameModeExtension on GameMode {
  String get displayName {
    switch (this) {
      case GameMode.soloRank:
        return '솔로랭크';
      case GameMode.flexRank:
        return '자유랭크';
      case GameMode.normal:
        return '일반';
      case GameMode.aram:
        return '칼바람 나락';
    }
  }
  
  String get shortName {
    switch (this) {
      case GameMode.soloRank:
        return '솔랭';
      case GameMode.flexRank:
        return '자랭';
      case GameMode.normal:
        return '일반';
      case GameMode.aram:
        return '칼바람';
    }
  }
}