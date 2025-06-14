import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/clan_recruitment_post_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:uuid/uuid.dart';

class ClanRecruitmentProvider with ChangeNotifier {
  final ClanService _clanService = ClanService();
  final Uuid _uuid = const Uuid();
  // Page 1 Data
  Set<String> _teamFeatures = {};
  Set<String> _activityDays = {};
  Set<String> _activityTimes = {};
  Set<String> _preferredPositions = {};

  // Page 2 Data
  String? _preferredGender;
  Set<String> _preferredTiers = {};
  Set<String> _preferredAgeGroups = {};

  // Page 3 Data
  String _title = '';
  String _description = '';
  // TODO: Add image handling logic
  // String? _teamImageUrl;

  // Getters
  Set<String> get teamFeatures => _teamFeatures;
  Set<String> get activityDays => _activityDays;
  Set<String> get activityTimes => _activityTimes;
  Set<String> get preferredPositions => _preferredPositions;
  String? get preferredGender => _preferredGender;
  Set<String> get preferredTiers => _preferredTiers;
  Set<String> get preferredAgeGroups => _preferredAgeGroups;
  String get title => _title;
  String get description => _description;

  // Methods for Page 1
  void toggleTeamFeature(String feature) {
    _toggleSetValue(_teamFeatures, feature);
  }

  void toggleActivityDay(String day) {
    _toggleSetValue(_activityDays, day);
  }

  void toggleActivityTime(String time) {
    _toggleSetValue(_activityTimes, time);
  }

  void togglePosition(String position) {
    _toggleSetValue(_preferredPositions, position);
  }

  // Methods for Page 2
  void setGender(String gender) {
    _preferredGender = gender;
    notifyListeners();
  }

  void toggleTier(String tier) {
    _toggleSetValue(_preferredTiers, tier);
  }

  void toggleAgeGroup(String age) {
    _toggleSetValue(_preferredAgeGroups, age);
  }

  // Methods for Page 3
  void updateTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void updateDescription(String value) {
    _description = value;
    notifyListeners();
  }

  // Helper method to toggle a value in a set
  void _toggleSetValue(Set<String> set, String value) {
    if (set.contains(value)) {
      set.remove(value);
    } else {
      set.add(value);
    }
    notifyListeners();
  }

  // Reset all data
  void clear() {
    _teamFeatures.clear();
    _activityDays.clear();
    _activityTimes.clear();
    _preferredPositions.clear();
    _preferredGender = null;
    _preferredTiers.clear();
    _preferredAgeGroups.clear();
    _title = '';
    _description = '';
    notifyListeners();
  }

  Future<void> publishPost({
    required UserModel currentUser,
    required ClanModel currentClan,
  }) async {
    if (_title.isEmpty || _description.isEmpty) {
      throw Exception('제목과 상세 설명을 모두 입력해주세요.');
    }

    final post = ClanRecruitmentPostModel(
      id: _uuid.v4(),
      clanId: currentClan.id,
      clanName: currentClan.name,
      clanEmblem: currentClan.emblem.toString(), // Assuming emblem can be converted to string
      title: _title,
      description: _description,
      teamFeatures: _teamFeatures.toList(),
      preferredPositions: _preferredPositions.toList(),
      preferredTiers: _preferredTiers.toList(),
      preferredAgeGroups: _preferredAgeGroups.toList(),
      preferredGender: _preferredGender ?? '무관',
      activityDays: _activityDays.toList(),
      activityTimes: _activityTimes.toList(),
      authorId: currentUser.uid,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

    await _clanService.publishRecruitmentPost(post);
    clear(); // Clear the form after successful submission
  }
}