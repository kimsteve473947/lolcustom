import 'package:cloud_firestore/cloud_firestore.dart';

class ClanRecruitmentPostModel {
  final String id;
  final String clanId;
  final String clanName;
  final dynamic clanEmblem;
  final int clanMemberCount;
  final String title;
  final String description;
  final List<String> teamFeatures; // 팀 특징
  final List<String> preferredPositions; // 주요 포지션
  final List<String> preferredTiers; // 레벨(티어)
  final List<String> preferredAgeGroups; // 나이
  final String preferredGender; // 성별
  final List<String> activityDays; // 주요 활동 요일
  final List<String> activityTimes; // 주요 활동 시간
  final String? teamImageUrl; // 팀 단체 사진
  final String authorId;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final bool isRecruiting;
  final int applicantsCount;

  ClanRecruitmentPostModel({
    required this.id,
    required this.clanId,
    required this.clanName,
    required this.clanEmblem,
    required this.clanMemberCount,
    required this.title,
    required this.description,
    required this.teamFeatures,
    required this.preferredPositions,
    required this.preferredTiers,
    required this.preferredAgeGroups,
    required this.preferredGender,
    required this.activityDays,
    required this.activityTimes,
    this.teamImageUrl,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    this.isRecruiting = true,
    this.applicantsCount = 0,
  });

  factory ClanRecruitmentPostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ClanRecruitmentPostModel(
      id: doc.id,
      clanId: data['clanId'] ?? '',
      clanName: data['clanName'] ?? '',
      clanEmblem: data['clanEmblem'],
      clanMemberCount: data['clanMemberCount'] ?? 0,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      teamFeatures: List<String>.from(data['teamFeatures'] ?? []),
      preferredPositions: List<String>.from(data['preferredPositions'] ?? []),
      preferredTiers: List<String>.from(data['preferredTiers'] ?? []),
      preferredAgeGroups: List<String>.from(data['preferredAgeGroups'] ?? []),
      preferredGender: data['preferredGender'] ?? '무관',
      activityDays: List<String>.from(data['activityDays'] ?? []),
      activityTimes: List<String>.from(data['activityTimes'] ?? []),
      teamImageUrl: data['teamImageUrl'],
      authorId: data['authorId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      isRecruiting: data['isRecruiting'] ?? true,
      applicantsCount: data['applicantsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clanId': clanId,
      'clanName': clanName,
      'clanEmblem': clanEmblem,
      'clanMemberCount': clanMemberCount,
      'title': title,
      'description': description,
      'teamFeatures': teamFeatures,
      'preferredPositions': preferredPositions,
      'preferredTiers': preferredTiers,
      'preferredAgeGroups': preferredAgeGroups,
      'preferredGender': preferredGender,
      'activityDays': activityDays,
      'activityTimes': activityTimes,
      'teamImageUrl': teamImageUrl,
      'authorId': authorId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isRecruiting': isRecruiting,
      'applicantsCount': applicantsCount,
    };
  }
}