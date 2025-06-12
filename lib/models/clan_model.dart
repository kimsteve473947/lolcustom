import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:flutter/material.dart';

enum ClanFocus {
  casual,   // 친목 위주
  competitive,  // 실력 위주
  balanced  // 균형
}

enum PlayTimeType {
  morning,  // 아침 (6-10시)
  daytime,  // 낮 (10-18시)
  evening,  // 저녁 (18-24시)
  night     // 심야 (24-6시)
}

enum AgeGroup {
  teens,    // 10대
  twenties, // 20대
  thirties, // 30대
  fortyPlus  // 40대 이상
}

enum GenderPreference {
  male,     // 남자
  female,   // 여자
  any       // 남녀 모두
}

class ClanModel extends Equatable {
  final String id;
  final String name;
  final String? code;
  final String? description;
  final String ownerId;
  final String? profileUrl;
  final dynamic emblem; // 사용자 정의 이미지(File) 또는 Map<String, dynamic>
  final List<String> activityDays; // ['월', '화', '수', '목', '금', '토', '일']
  final List<PlayTimeType> activityTimes; // [PlayTimeType.morning, PlayTimeType.evening]
  final List<AgeGroup> ageGroups; // [AgeGroup.twenties, AgeGroup.thirties]
  final GenderPreference genderPreference;
  final ClanFocus focus;
  final int focusRating; // 1-10 scale where 1 is fully casual, 10 is fully competitive
  final String? websiteUrl;
  final Timestamp createdAt;
  final int memberCount;
  final int maxMembers;
  final List<String> members;
  final List<String> pendingMembers;
  final bool isPublic;
  final bool isRecruiting;

  const ClanModel({
    required this.id,
    required this.name,
    this.code,
    this.description,
    required this.ownerId,
    this.profileUrl,
    this.emblem,
    this.activityDays = const [],
    this.activityTimes = const [],
    this.ageGroups = const [],
    this.genderPreference = GenderPreference.any,
    this.focus = ClanFocus.balanced,
    this.focusRating = 5,
    this.websiteUrl,
    required this.createdAt,
    this.memberCount = 1,
    this.maxMembers = 20,
    this.members = const [],
    this.pendingMembers = const [],
    this.isPublic = true,
    this.isRecruiting = true,
  });

  ClanModel copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? ownerId,
    String? profileUrl,
    dynamic emblem,
    List<String>? activityDays,
    List<PlayTimeType>? activityTimes,
    List<AgeGroup>? ageGroups,
    GenderPreference? genderPreference,
    ClanFocus? focus,
    int? focusRating,
    String? websiteUrl,
    Timestamp? createdAt,
    int? memberCount,
    int? maxMembers,
    List<String>? members,
    List<String>? pendingMembers,
    bool? isPublic,
    bool? isRecruiting,
  }) {
    return ClanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      profileUrl: profileUrl ?? this.profileUrl,
      emblem: emblem ?? this.emblem,
      activityDays: activityDays ?? this.activityDays,
      activityTimes: activityTimes ?? this.activityTimes,
      ageGroups: ageGroups ?? this.ageGroups,
      genderPreference: genderPreference ?? this.genderPreference,
      focus: focus ?? this.focus,
      focusRating: focusRating ?? this.focusRating,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      members: members ?? this.members,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      isPublic: isPublic ?? this.isPublic,
      isRecruiting: isRecruiting ?? this.isRecruiting,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'ownerId': ownerId,
      'profileUrl': profileUrl,
      'activityDays': activityDays,
      'activityTimes': activityTimes.map((t) => t.index).toList(),
      'ageGroups': ageGroups.map((a) => a.index).toList(),
      'genderPreference': genderPreference.index,
      'focus': focus.index,
      'focusRating': focusRating,
      'websiteUrl': websiteUrl,
      'createdAt': createdAt,
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'members': members,
      'pendingMembers': pendingMembers,
      'isPublic': isPublic,
      'isRecruiting': isRecruiting,
    };
    
    // 엠블럼 데이터 처리
    if (emblem != null) {
      if (emblem is Map) {
        // 맵 형태의 엠블럼인 경우 (Color 객체 처리)
        final Map<String, dynamic> emblemData = Map<String, dynamic>.from(emblem as Map);
        // Color 객체를 정수로 변환
        if (emblemData.containsKey('backgroundColor') && emblemData['backgroundColor'] is Color) {
          emblemData['backgroundColor'] = (emblemData['backgroundColor'] as Color).value;
        }
        data['emblem'] = emblemData;
        data['customEmblem'] = false;
      } else if (emblem is String) {
        // Firebase Storage 경로인 경우
        data['emblemUrl'] = emblem;
        data['customEmblem'] = true;
      }
    }
    
    return data;
  }

  factory ClanModel.fromMap(Map<String, dynamic> map) {
    // 엠블럼 데이터 처리
    dynamic emblemData;
    if (map['emblem'] != null) {
      final emblemMap = Map<String, dynamic>.from(map['emblem'] as Map);
      // 색상 값을 Color 객체로 변환
      if (emblemMap.containsKey('backgroundColor') && emblemMap['backgroundColor'] is int) {
        emblemMap['backgroundColor'] = Color(emblemMap['backgroundColor']);
      }
      emblemData = emblemMap;
    } else if (map['emblemUrl'] != null) {
      emblemData = map['emblemUrl'] as String;
    }
    
    return ClanModel(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String?,
      description: map['description'] as String?,
      ownerId: map['ownerId'] as String,
      profileUrl: map['profileUrl'] as String?,
      emblem: emblemData,
      activityDays: List<String>.from(map['activityDays'] ?? []),
      activityTimes: (map['activityTimes'] as List<dynamic>?)
          ?.map((e) => PlayTimeType.values[e as int])
          .toList() ?? [],
      ageGroups: (map['ageGroups'] as List<dynamic>?)
          ?.map((e) => AgeGroup.values[e as int])
          .toList() ?? [],
      genderPreference: map['genderPreference'] != null
          ? GenderPreference.values[map['genderPreference'] as int]
          : GenderPreference.any,
      focus: map['focus'] != null
          ? ClanFocus.values[map['focus'] as int]
          : ClanFocus.balanced,
      focusRating: map['focusRating'] as int? ?? 5,
      websiteUrl: map['websiteUrl'] as String?,
      createdAt: map['createdAt'] as Timestamp,
      memberCount: map['memberCount'] as int? ?? 1,
      maxMembers: map['maxMembers'] as int? ?? 20,
      members: List<String>.from(map['members'] ?? []),
      pendingMembers: List<String>.from(map['pendingMembers'] ?? []),
      isPublic: map['isPublic'] as bool? ?? true,
      isRecruiting: map['isRecruiting'] as bool? ?? true,
    );
  }
  
  // 기존 나이대 데이터를 새 모델로 변환
  static AgeGroup _convertLegacyAgeGroup(int value) {
    // 기존 모델에서 40대 이상(3, 4, 5)은 모두 fortyPlus로 매핑
    if (value >= 3) {
      return AgeGroup.fortyPlus;
    }
    return AgeGroup.values[value];
  }

  @override
  List<Object?> get props => [
    id, name, code, description, ownerId, profileUrl, emblem,
    activityDays, activityTimes, ageGroups, genderPreference,
    focus, focusRating, websiteUrl, createdAt, memberCount,
    maxMembers, members, pendingMembers, isPublic, isRecruiting
  ];
} 