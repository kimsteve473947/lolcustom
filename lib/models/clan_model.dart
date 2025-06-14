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
  final String ownerName;
  final String? profileUrl;
  final dynamic emblem; // 사용자 정의 이미지(File) 또는 Map<String, dynamic>
  final List<String> activityDays; // ['월', '화', '수', '목', '금', '토', '일']
  final List<PlayTimeType> activityTimes; // [PlayTimeType.morning, PlayTimeType.evening]
  final List<AgeGroup> ageGroups; // [AgeGroup.twenties, AgeGroup.thirties]
  final GenderPreference genderPreference;
  final ClanFocus focus;
  final int focusRating; // 1-10 scale where 1 is fully casual, 10 is fully competitive
  final String? discordUrl;
  final Timestamp createdAt;
  final int maxMembers;
  final List<String> members;
  int get memberCount => members.length;
  final List<String> pendingMembers;
  final bool areMembersPublic;
  final bool isRecruiting;
  final int level;
  final int xp;
  final int xpToNextLevel;

  const ClanModel({
    required this.id,
    required this.name,
    this.code,
    this.description,
    required this.ownerId,
    required this.ownerName,
    this.profileUrl,
    this.emblem,
    this.activityDays = const [],
    this.activityTimes = const [],
    this.ageGroups = const [],
    this.genderPreference = GenderPreference.any,
    this.focus = ClanFocus.balanced,
    this.focusRating = 5,
    this.discordUrl,
    required this.createdAt,
    this.maxMembers = 15,
    this.members = const [],
    this.pendingMembers = const [],
    this.areMembersPublic = true,
    this.isRecruiting = true,
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 100,
  });

  ClanModel copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? ownerId,
    String? ownerName,
    String? profileUrl,
    dynamic emblem,
    List<String>? activityDays,
    List<PlayTimeType>? activityTimes,
    List<AgeGroup>? ageGroups,
    GenderPreference? genderPreference,
    ClanFocus? focus,
    int? focusRating,
    String? discordUrl,
    Timestamp? createdAt,
    int? maxMembers,
    List<String>? members,
    List<String>? pendingMembers,
    bool? areMembersPublic,
    bool? isRecruiting,
    int? level,
    int? xp,
    int? xpToNextLevel,
  }) {
    return ClanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      profileUrl: profileUrl ?? this.profileUrl,
      emblem: emblem ?? this.emblem,
      activityDays: activityDays ?? this.activityDays,
      activityTimes: activityTimes ?? this.activityTimes,
      ageGroups: ageGroups ?? this.ageGroups,
      genderPreference: genderPreference ?? this.genderPreference,
      focus: focus ?? this.focus,
      focusRating: focusRating ?? this.focusRating,
      discordUrl: discordUrl ?? this.discordUrl,
      createdAt: createdAt ?? this.createdAt,
      maxMembers: maxMembers ?? this.maxMembers,
      members: members ?? this.members,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      areMembersPublic: areMembersPublic ?? this.areMembersPublic,
      isRecruiting: isRecruiting ?? this.isRecruiting,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'profileUrl': profileUrl,
      'activityDays': activityDays,
      'activityTimes': activityTimes.map((t) => t.index).toList(),
      'ageGroups': ageGroups.map((a) => a.index).toList(),
      'genderPreference': genderPreference.index,
      'focus': focus.index,
      'focusRating': focusRating,
      'discordUrl': discordUrl,
      'createdAt': createdAt,
      'maxMembers': maxMembers,
      'members': members,
      'pendingMembers': pendingMembers,
      'areMembersPublic': areMembersPublic,
      'isRecruiting': isRecruiting,
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpToNextLevel,
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

  static int _dynamicToInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsedValue = int.tryParse(value);
      return parsedValue ?? defaultValue;
    }
    return defaultValue;
  }

  factory ClanModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

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
      id: doc.id,
      name: map['name'] as String,
      code: map['code'] as String?,
      description: map['description'] as String?,
      ownerId: map['ownerId'] as String,
      ownerName: map['ownerName'] as String? ?? '이름 없음',
      profileUrl: map['profileUrl'] as String?,
      emblem: emblemData,
      activityDays: List<String>.from(map['activityDays'] ?? []),
      activityTimes: (map['activityTimes'] as List<dynamic>?)
          ?.map((e) => PlayTimeType.values[_dynamicToInt(e, defaultValue: 0)])
          .toList() ?? [],
      ageGroups: (map['ageGroups'] as List<dynamic>?)
          ?.map((e) => _convertLegacyAgeGroup(_dynamicToInt(e, defaultValue: 0)))
          .toList() ?? [],
      genderPreference: map['genderPreference'] != null
          ? GenderPreference.values[_dynamicToInt(map['genderPreference'], defaultValue: 2)] // any
          : GenderPreference.any,
      focus: map['focus'] != null
          ? ClanFocus.values[_dynamicToInt(map['focus'], defaultValue: 2)] // balanced
          : ClanFocus.balanced,
      focusRating: _dynamicToInt(map['focusRating'], defaultValue: 5),
      discordUrl: map['discordUrl'] as String?,
      createdAt: map['createdAt'] as Timestamp,
      maxMembers: _dynamicToInt(map['maxMembers'], defaultValue: 15),
      members: List<String>.from(map['members'] ?? []),
      pendingMembers: List<String>.from(map['pendingMembers'] ?? []),
      areMembersPublic: map['areMembersPublic'] as bool? ?? true,
      isRecruiting: map['isRecruiting'] as bool? ?? true,
      level: _dynamicToInt(map['level'], defaultValue: 1),
      xp: _dynamicToInt(map['xp'], defaultValue: 0),
      xpToNextLevel: _dynamicToInt(map['xpToNextLevel'], defaultValue: 100),
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
    id, name, code, description, ownerId, ownerName, profileUrl, emblem,
    activityDays, activityTimes, ageGroups, genderPreference,
    focus, focusRating, discordUrl, createdAt,
    maxMembers, members, pendingMembers, areMembersPublic, isRecruiting,
    level, xp, xpToNextLevel
  ];
}