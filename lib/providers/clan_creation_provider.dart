import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';

enum ClanCreationStep {
  basicInfo,
  emblem,
  activityTimes,
  memberPreferences,
  focusSelection,
  confirmation
}

class ClanCreationProvider extends ChangeNotifier {
  final ClanService _clanService = ClanService();
  
  ClanModel? _clanData;
  
  ClanModel? get clanData => _clanData;
  
  void setClanData(ClanModel clan) {
    _clanData = clan;
    notifyListeners();
  }
  
  void updateClanData({
    String? name,
    String? description,
    String? ownerId,
    dynamic emblem,
    List<String>? activityDays,
    List<PlayTimeType>? activityTimes,
    List<AgeGroup>? ageGroups,
    GenderPreference? genderPreference,
    ClanFocus? focus,
    int? focusRating,
    String? websiteUrl,
    bool? isPublic,
    bool? isRecruiting,
  }) {
    if (_clanData == null) {
      return;
    }
    
    _clanData = _clanData!.copyWith(
      name: name,
      description: description,
      ownerId: ownerId,
      emblem: emblem,
      activityDays: activityDays,
      activityTimes: activityTimes,
      ageGroups: ageGroups,
      genderPreference: genderPreference,
      focus: focus,
      focusRating: focusRating,
      websiteUrl: websiteUrl,
      isPublic: isPublic,
      isRecruiting: isRecruiting,
    );
    
    notifyListeners();
  }
  
  Future<ClanModel> createClan(String userId) async {
    if (_clanData == null) {
      throw Exception('클랜 데이터가 없습니다');
    }
    
    // 클랜 ID 생성
    final clanId = await _clanService.createClan(
      _clanData!.name,
      userId,
      description: _clanData!.description,
      emblem: _clanData!.emblem,
      activityDays: _clanData!.activityDays,
      activityTimes: _clanData!.activityTimes,
      ageGroups: _clanData!.ageGroups,
      genderPreference: _clanData!.genderPreference,
      focus: _clanData!.focus,
      focusRating: _clanData!.focusRating,
      websiteUrl: _clanData!.websiteUrl,
      isPublic: _clanData!.isPublic,
      isRecruiting: _clanData!.isRecruiting,
      memberCount: _clanData!.memberCount,
    );
    
    // 생성된 클랜 정보 가져오기
    final clan = await _clanService.getClanById(clanId);
    if (clan == null) {
      throw Exception('클랜 생성 후 정보를 가져오는데 실패했습니다');
    }
    
    return clan;
  }
  
  bool isFormValid() {
    if (_clanData == null) {
      return false;
    }
    
    return _clanData!.name.isNotEmpty;
  }
  
  void reset() {
    _clanData = null;
    notifyListeners();
  }

  // Basic Info
  String _name = '';
  String _code = '';
  String _description = '';
  String? _websiteUrl;
  String? _region;
  int _maxMembers = 20;
  bool _isPublic = true;
  bool _isRecruiting = true;

  // Emblem Info
  dynamic _emblem;
  bool _hasEmblem = false;
  
  // Activity Times
  List<String> _activityDays = [];
  List<PlayTimeType> _activityTimes = [];
  
  // Member Preferences
  List<AgeGroup> _ageGroups = [];
  GenderPreference _genderPreference = GenderPreference.any;
  
  // Focus
  ClanFocus _focus = ClanFocus.balanced;
  int _focusRating = 5; // 1-10 where 1 is fully casual, 10 is fully competitive
  
  // Current step
  ClanCreationStep _currentStep = ClanCreationStep.basicInfo;
  
  // Getters
  String get name => _name;
  String get code => _code;
  String get description => _description;
  String? get websiteUrl => _websiteUrl;
  String? get region => _region;
  int get maxMembers => _maxMembers;
  bool get isPublic => _isPublic;
  bool get isRecruiting => _isRecruiting;
  
  dynamic get emblem => _emblem;
  bool get hasEmblem => _hasEmblem;
  
  List<String> get activityDays => _activityDays;
  List<PlayTimeType> get activityTimes => _activityTimes;
  
  List<AgeGroup> get ageGroups => _ageGroups;
  GenderPreference get genderPreference => _genderPreference;
  
  ClanFocus get focus => _focus;
  int get focusRating => _focusRating;
  
  ClanCreationStep get currentStep => _currentStep;
  
  // Setters for basic info
  void setName(String value) {
    _name = value;
    notifyListeners();
  }
  
  void setCode(String value) {
    _code = value;
    notifyListeners();
  }
  
  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }
  
  void setWebsiteUrl(String value) {
    _websiteUrl = value;
    notifyListeners();
  }
  
  void setRegion(String value) {
    _region = value;
    notifyListeners();
  }
  
  void setMaxMembers(int value) {
    _maxMembers = value;
    notifyListeners();
  }
  
  void setIsPublic(bool value) {
    _isPublic = value;
    notifyListeners();
  }
  
  void setIsRecruiting(bool value) {
    _isRecruiting = value;
    notifyListeners();
  }
  
  // Emblem setters
  void setEmblem(dynamic value) {
    _emblem = value;
    _hasEmblem = value != null;
    notifyListeners();
  }
  
  // Activity times setters
  void toggleActivityDay(String day) {
    if (_activityDays.contains(day)) {
      _activityDays.remove(day);
    } else {
      _activityDays.add(day);
    }
    notifyListeners();
  }
  
  void toggleActivityTime(PlayTimeType time) {
    if (_activityTimes.contains(time)) {
      _activityTimes.remove(time);
    } else {
      _activityTimes.add(time);
    }
    notifyListeners();
  }
  
  // Member preferences setters
  void toggleAgeGroup(AgeGroup age) {
    if (_ageGroups.contains(age)) {
      _ageGroups.remove(age);
    } else {
      _ageGroups.add(age);
    }
    notifyListeners();
  }
  
  void setGenderPreference(GenderPreference gender) {
    _genderPreference = gender;
    notifyListeners();
  }
  
  // Focus setters
  void setFocus(ClanFocus value) {
    _focus = value;
    notifyListeners();
  }
  
  void setFocusRating(int value) {
    _focusRating = value;
    notifyListeners();
  }
  
  // Navigation
  void nextStep() {
    if (_currentStep.index < ClanCreationStep.values.length - 1) {
      _currentStep = ClanCreationStep.values[_currentStep.index + 1];
      notifyListeners();
    }
  }
  
  void previousStep() {
    if (_currentStep.index > 0) {
      _currentStep = ClanCreationStep.values[_currentStep.index - 1];
      notifyListeners();
    }
  }
  
  void goToStep(ClanCreationStep step) {
    _currentStep = step;
    notifyListeners();
  }
  
  // 엠블럼 이미지를 Firebase Storage에 업로드
  Future<String> _uploadEmblemImage(File imageFile, String clanId) async {
    print('엠블럼 이미지 업로드 시작: ${imageFile.path}');
    final storageRef = FirebaseStorage.instance.ref();
    final uuid = const Uuid().v4();
    final extension = path.extension(imageFile.path);
    final emblemRef = storageRef.child('clans/$clanId/emblem_$uuid$extension');
    
    try {
      print('Storage 레퍼런스 생성: ${emblemRef.fullPath}');
      final uploadTask = emblemRef.putFile(imageFile);
      print('업로드 작업 시작');
      final snapshot = await uploadTask.whenComplete(() => null);
      print('업로드 완료, 다운로드 URL 가져오기');
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('다운로드 URL 획득: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('엠블럼 이미지 업로드 오류: $e');
      rethrow;
    }
  }
  
  // Build a clan model from current state
  Future<ClanModel> buildClanModel(String userId) async {
    print('buildClanModel 호출됨 - 사용자 ID: $userId');
    // 엠블럼 처리
    dynamic processedEmblem;
    
    if (_emblem is File) {
      // 파일은 아직 업로드되지 않았으므로 그대로 저장
      processedEmblem = _emblem;
    } else if (_emblem is Map) {
      // 기본 엠블럼 설정은 그대로 사용
      processedEmblem = _emblem;
    }
    
    return ClanModel(
      id: '', // will be set by Firestore
      name: _name,
      code: _code,
      description: _description,
      ownerId: userId,
      emblem: processedEmblem,
      activityDays: _activityDays,
      activityTimes: _activityTimes,
      ageGroups: _ageGroups,
      genderPreference: _genderPreference,
      focus: _focus,
      focusRating: _focusRating,
      websiteUrl: _websiteUrl,
      createdAt: Timestamp.now(),
      maxMembers: _maxMembers,
      members: [userId],
    );
  }
  
  // Validation functions
  bool isBasicInfoValid() {
    return _name.isNotEmpty && _hasEmblem;
  }
  
  bool isEmblemValid() {
    return _hasEmblem;
  }
  
  bool isActivityTimesValid() {
    return _activityDays.isNotEmpty && _activityTimes.isNotEmpty;
  }
  
  bool isMemberPreferencesValid() {
    return _ageGroups.isNotEmpty;
  }
  
  bool isFocusSelectionValid() {
    return true; // Always valid as there's a default
  }
  
  // 특정 단계에 필요한 데이터가 모두 입력되었는지 확인
  bool isStepDataComplete(ClanCreationStep step) {
    switch (step) {
      case ClanCreationStep.basicInfo:
        return isBasicInfoValid();
      case ClanCreationStep.emblem:
        return isEmblemValid();
      case ClanCreationStep.activityTimes:
        return isActivityTimesValid();
      case ClanCreationStep.memberPreferences:
        return isMemberPreferencesValid();
      case ClanCreationStep.focusSelection:
        return isFocusSelectionValid();
      case ClanCreationStep.confirmation:
        return isFormValid();
      default:
        return false;
    }
  }
} 