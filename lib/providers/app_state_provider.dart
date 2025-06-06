import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/services/cloud_functions_service.dart';

class AppStateProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirebaseService _firebaseService;
  final CloudFunctionsService _cloudFunctionsService;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  
  // 캐시 및 상태 관리를 위한 필드 정의
  final List<TournamentModel> _tournaments = [];
  final Map<String, List<TournamentModel>> _tournamentsByCategory = {};
  final List<ClanModel> _clans = [];
  final List<ChatRoomModel> _chatRooms = [];
  final List<NotificationModel> _notifications = [];
  final List<UserModel> _mercenaries = [];
  final Map<String, UserModel> _mercenaryById = {};
  
  // Constructor
  AppStateProvider({
    AuthService? authService,
    FirebaseService? firebaseService,
    CloudFunctionsService? cloudFunctionsService,
  }) : 
    _authService = authService ?? AuthService(),
    _firebaseService = firebaseService ?? FirebaseService(),
    _cloudFunctionsService = cloudFunctionsService ?? CloudFunctionsService() {
    _initializeApp();
  }
  
  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _authService.isLoggedIn;

  // Expose services for direct access when needed
  CloudFunctionsService get cloudFunctionsService => _cloudFunctionsService;
  FirebaseService get firebaseService => _firebaseService;
  
  // Initialize app state
  Future<void> _initializeApp() async {
    _setLoading(true);
    
    try {
      if (_authService.isLoggedIn) {
        await _loadCurrentUser();
      }
    } catch (e) {
      _setError('Failed to initialize app: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Load current user
  Future<void> _loadCurrentUser({bool forceRefresh = false}) async {
    if (!_authService.isLoggedIn) {
      debugPrint('AppStateProvider - 로그인되어 있지 않음, 사용자 로드 스킵');
      _currentUser = null;
      notifyListeners();
      return;
    }
    
    _setLoading(true);
    try {
      // 먼저 Firebase 인증 사용자 새로고침
      await _authService.reloadCurrentUser();
      debugPrint('AppStateProvider - Firebase Auth 사용자 새로고침 완료');
      
      // 사용자 정보 가져오기
      final prevUser = _currentUser;
      _currentUser = await _firebaseService.getCurrentUser();
      
      if (_currentUser != null) {
        debugPrint('AppStateProvider - 사용자 정보 로드 완료: ${_currentUser!.nickname} (${_currentUser!.uid})');
        
        // 이전 사용자와 다른 사용자인 경우 모든 캐시 클리어
        if (prevUser != null && prevUser.uid != _currentUser!.uid) {
          debugPrint('AppStateProvider - 사용자 변경 감지: ${prevUser.uid} → ${_currentUser!.uid}');
          _clearAllCaches();
        }
      } else {
        debugPrint('AppStateProvider - 사용자 정보 로드 실패: 데이터가 없음');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('AppStateProvider - 사용자 정보 로드 오류: $e');
      _setError('Failed to load user profile: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 모든 캐시 클리어
  void _clearAllCaches() {
    debugPrint('AppStateProvider - 모든 캐시 초기화');
    _tournaments.clear();
    _tournamentsByCategory.clear();
    _clans.clear();
    _chatRooms.clear();
    _notifications.clear();
    _mercenaries.clear();
    _mercenaryById.clear();
  }
  
  // Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _loadCurrentUser();
      return true;
    } catch (e) {
      _setError('Failed to sign in: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Register with email and password
  Future<bool> register(String email, String password, String nickname) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        nickname: nickname,
      );
      await _loadCurrentUser();
      return true;
    } catch (e) {
      _setError('Failed to register: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    
    try {
      debugPrint('AppStateProvider: 로그아웃 시작');
      
      // 기존 사용자 정보 캡처 (디버깅용)
      final prevUserEmail = _currentUser?.email;
      final prevUserUid = _currentUser?.uid;
      
      // Firebase 인증에서 로그아웃
      await _authService.signOut();
      
      // 사용자 데이터 명시적으로 초기화
      _currentUser = null;
      
      // 앱 상태 리셋
      _tournaments.clear();
      _clans.clear();
      _chatRooms.clear();
      _notifications.clear();
      
      // 캐시 및 로컬 데이터 초기화
      _clearTournamentCache();
      _clearUserCache();
      
      debugPrint('AppStateProvider: 로그아웃 완료. 이전 사용자: $prevUserEmail ($prevUserUid)');
      
      // 데이터 갱신 알림
      notifyListeners();
    } catch (e) {
      _setError('로그아웃 중 오류 발생: $e');
      debugPrint('AppStateProvider: 로그아웃 오류: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 토너먼트 캐시 초기화
  void _clearTournamentCache() {
    _tournaments.clear();
    _tournamentsByCategory.clear();
    notifyListeners();
  }
  
  // 사용자 관련 캐시 초기화
  void _clearUserCache() {
    _mercenaries.clear();
    _mercenaryById.clear();
    notifyListeners();
  }
  
  // Update user profile
  Future<bool> updateUserProfile({
    String? nickname,
    String? riotId,
    String? tier,
    String? profileImageUrl,
    List<String>? preferredPositions,
  }) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      // tier 문자열에서 PlayerTier 열거형으로 변환
      PlayerTier? playerTier;
      if (tier != null) {
        playerTier = UserModel.tierFromString(tier);
      }
      
      UserModel updatedUser = _currentUser!.copyWith(
        nickname: nickname,
        riotId: riotId,
        tier: playerTier,
        profileImageUrl: profileImageUrl,
        preferredPositions: preferredPositions,
      );
      
      await _firebaseService.updateUserProfile(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Create tournament
  Future<String?> createTournament({
    required String title,
    required String location,
    required DateTime startsAt,
    required Map<String, int> slotsByRole,
    required TournamentType tournamentType,
    int? ovrLimit,
    PlayerTier? tierLimit,
    String? description,
    bool? premiumBadge, // Optional: Will be determined by user's premium status
    GeoPoint? locationCoordinates,
    GameFormat? gameFormat,
    String? customRoomName,
    String? customRoomPassword,
    String? hostPosition, // 주최자 포지션 추가
  }) async {
    if (_currentUser == null) {
      _setError('사용자 로그인이 필요합니다');
      return null;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      // 기본 슬롯 맵 생성
      final Map<String, int> slots = {
        'team1': 5,
        'team2': 5,
      };
      
      // 각 역할별 빈 슬롯 맵 생성 - 모든 역할이 존재하는지 확인
      final Map<String, int> filledSlotsByRole = {
        'top': 0,
        'jungle': 0,
        'mid': 0,
        'adc': 0,
        'support': 0,
      };
      
      // 역할별 참가자 목록 초기화 - 모든 역할이 존재하는지 확인
      final Map<String, List<String>> participantsByRole = {
        'top': [],
        'jungle': [],
        'mid': [],
        'adc': [],
        'support': [],
      };
      
      // 입력된 slotsByRole에 모든 필수 역할이 포함되어 있는지 확인하고 누락된 역할은 기본값 설정
      final Map<String, int> validatedSlotsByRole = {
        'top': slotsByRole['top'] ?? 2,
        'jungle': slotsByRole['jungle'] ?? 2,
        'mid': slotsByRole['mid'] ?? 2,
        'adc': slotsByRole['adc'] ?? 2,
        'support': slotsByRole['support'] ?? 2,
      };
      
      // 빈 슬롯 맵 생성
      final Map<String, int> filledSlots = {
        'team1': 0,
        'team2': 0,
      };
      
      // 프리미엄 멤버십 확인하여 자동으로 프리미엄 배지 설정
      final bool hasPremiumBadge = premiumBadge ?? _currentUser!.isPremium;
      
      // 경쟁전용 심판 목록 (초기에는 비어있음)
      final List<String> referees = [];
      
      // 티어 참가 범위 제한 (티어 + 한 단계 위 티어)
      Map<String, dynamic> tierRules = {};
      if (tierLimit != null && tierLimit != PlayerTier.unranked) {
        // 선택한 티어와 한 단계 위 티어 인덱스 구하기
        final int selectedTierIndex = tierLimit.index;
        final int nextTierIndex = selectedTierIndex < PlayerTier.values.length - 1
            ? selectedTierIndex + 1  // 한 단계 위 티어
            : selectedTierIndex;     // 챌린저일 경우 자기 자신
            
        tierRules = {
          'minTier': selectedTierIndex,  // 최소 티어 (선택한 티어)
          'maxTier': nextTierIndex,      // 최대 티어 (한 단계 위 티어)
        };
      }
      
      // 주최자 참가 정보 설정 (선택한 포지션이 있을 경우)
      List<String> participants = [];
      if (hostPosition != null && hostPosition.isNotEmpty) {
        participants.add(_currentUser!.uid);
        if (participantsByRole.containsKey(hostPosition)) {
          participantsByRole[hostPosition]!.add(_currentUser!.uid);
          filledSlotsByRole[hostPosition] = (filledSlotsByRole[hostPosition] ?? 0) + 1;
          
          // team1, team2 중 어디에 속하는지 결정
          if (hostPosition == 'top' || hostPosition == 'jungle' || hostPosition == 'mid') {
            filledSlots['team1'] = (filledSlots['team1'] ?? 0) + 1;
          } else if (hostPosition == 'adc' || hostPosition == 'support') {
            filledSlots['team2'] = (filledSlots['team2'] ?? 0) + 1;
          }
        }
      }
      
      TournamentModel tournament = TournamentModel(
        id: '',  // Will be set by Firestore
        title: title.isNotEmpty ? title : '${_currentUser!.nickname}의 내전',
        description: description ?? '리그 오브 레전드 내전입니다',
        hostId: _currentUser!.uid,
        hostName: _currentUser!.nickname,
        hostNickname: _currentUser!.nickname,
        hostProfileImageUrl: _currentUser!.profileImageUrl,
        startsAt: Timestamp.fromDate(startsAt),
        location: location,
        tournamentType: tournamentType,
        creditCost: tournamentType == TournamentType.competitive ? 20 : null, // 항상 20 크레딧으로 고정
        status: TournamentStatus.open,
        createdAt: DateTime.now(),
        slots: slots,
        filledSlots: filledSlots,
        slotsByRole: validatedSlotsByRole, // 검증된 슬롯 맵 사용
        filledSlotsByRole: filledSlotsByRole,
        participants: participants,
        participantsByRole: participantsByRole,
        ovrLimit: ovrLimit,
        tierLimit: tierLimit,
        premiumBadge: hasPremiumBadge,
        gameFormat: gameFormat ?? GameFormat.single,
        gameServer: GameServer.kr, // 기본값으로 한국 서버 설정
        // Additional fields can be added to extras if needed
        rules: {
          'ovrLimit': ovrLimit,
          'tierLimit': tierLimit?.index,
          'tierRules': tierRules,  // 티어 참가 범위 규칙 추가
          'premiumBadge': hasPremiumBadge,
          'locationCoordinates': locationCoordinates != null ? {
            'latitude': locationCoordinates.latitude,
            'longitude': locationCoordinates.longitude,
          } : null,
          'customRoomName': customRoomName,
          'customRoomPassword': customRoomPassword,
          'referees': referees, // 심판 목록 추가
          'isRefereed': tournamentType == TournamentType.competitive, // 경쟁전인 경우 심판 필요
          'hostPosition': hostPosition, // 주최자 포지션 저장
        },
      );
      
      // Firestore에 저장
      String id = await _firebaseService.createTournament(tournament);
      
      // 주최자가 이미 포지션을 선택했다면, 자동으로 application 생성
      if (hostPosition != null && hostPosition.isNotEmpty) {
        try {
          ApplicationModel application = ApplicationModel(
            id: '',  // Will be set by Firestore
            tournamentId: id,
            userUid: _currentUser!.uid,
            userName: _currentUser!.nickname,
            userProfileImageUrl: _currentUser!.profileImageUrl,
            role: hostPosition,
            userOvr: null,
            appliedAt: Timestamp.now(),
            message: '주최자',
            status: ApplicationStatus.accepted, // 자동 승인
          );
          
          await _firebaseService.applyToTournament(application);
        } catch (e) {
          // 신청 저장 실패해도 토너먼트 생성은 성공으로 처리
          debugPrint('Failed to save host application: $e');
        }
      }
      
      // Notify potential participants about new tournament (if we're premium)
      if (hasPremiumBadge) {
        try {
          await _cloudFunctionsService.notifyTournamentParticipants(
            tournamentId: id,
            message: '새로운 내전이 생성되었습니다: ${title.isNotEmpty ? title : _currentUser!.nickname}님의 내전',
          );
        } catch (e) {
          // Non-critical error, just log it
          debugPrint('Failed to send notifications: $e');
        }
      }
      
      return id;
    } catch (e) {
      _setError('Failed to create tournament: $e');
      debugPrint('Tournament creation error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // 토너먼트 특정 라인 참가
  Future<bool> joinTournamentByRole({
    required String tournamentId,
    required String role,
    String? message,
  }) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      // 토너먼트 정보 조회
      final tournament = await _firebaseService.getTournament(tournamentId);
      if (tournament == null) {
        _setError('토너먼트를 찾을 수 없습니다');
        return false;
      }
      
      // 라인 참가 가능 여부 확인
      if (!tournament.canJoinRole(role)) {
        _setError('해당 라인은 이미 가득 찼거나 참가할 수 없습니다');
        return false;
      }
      
      // 티어 제한 확인
      if (!tournament.isUserTierEligible(_currentUser!.tier)) {
        // 선택한 티어에 따라 메시지 생성
        String errorMessage;
        if (tournament.tierLimit == PlayerTier.unranked) {
          errorMessage = '랜덤 멸망전은 모든 티어가 참가 가능합니다';
        } else {
          final tierValues = PlayerTier.values;
          final minTierIndex = tournament.tierLimit!.index;
          final maxTierIndex = minTierIndex < tierValues.length - 1 ? minTierIndex + 1 : minTierIndex;
          
          final minTierName = UserModel.tierFromString(tierValues[minTierIndex].toString().split('.').last).toString().split('.').last;
          final maxTierName = UserModel.tierFromString(tierValues[maxTierIndex].toString().split('.').last).toString().split('.').last;
          
          errorMessage = '이 내전은 $minTierName ~ $maxTierName 티어만 참가 가능합니다';
        }
        
        _setError(errorMessage);
        return false;
      }
      
      // 경쟁전인 경우 크레딧 확인
      if (tournament.tournamentType == TournamentType.competitive) {
        final requiredCredits = tournament.creditCost ?? 20;
        if (!_currentUser!.hasEnoughCredits(requiredCredits)) {
          _setError('크레딧이 부족합니다. 필요 크레딧: $requiredCredits, 보유 크레딧: ${_currentUser!.credits}');
          return false;
        }
      }
      
      // 토너먼트 참가 처리
      await _firebaseService.joinTournamentByRole(tournamentId, role);
      
      // 신청 정보 생성
      ApplicationModel application = ApplicationModel(
        id: '',  // Will be set by Firestore
        tournamentId: tournamentId,
        userUid: _currentUser!.uid,
        userName: _currentUser!.nickname,
        userProfileImageUrl: _currentUser!.profileImageUrl,
        role: role,
        userOvr: null,  // TODO: Get user OVR for this role if available
        appliedAt: Timestamp.now(),
        message: message, // This is now fully optional and can be null
        status: ApplicationStatus.accepted, // 자동 승인으로 변경
      );
      
      await _firebaseService.applyToTournament(application);
      
      // 크레딧 차감 알림 (이미 서비스에서 처리했으므로 여기서는 UI 업데이트만)
      if (tournament.tournamentType == TournamentType.competitive) {
        final requiredCredits = tournament.creditCost ?? 20;
        _currentUser = _currentUser!.withUpdatedCredits(_currentUser!.credits - requiredCredits);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('토너먼트 참가 중 오류가 발생했습니다: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 토너먼트 참가 취소
  Future<bool> leaveTournamentByRole({
    required String tournamentId,
    required String role,
  }) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      // 토너먼트 정보 조회
      final tournament = await _firebaseService.getTournament(tournamentId);
      if (tournament == null) {
        _setError('토너먼트를 찾을 수 없습니다');
        return false;
      }
      
      // 참가 취소 처리
      await _firebaseService.leaveTournamentByRole(tournamentId, role);
      
      // 경쟁전인 경우 크레딧 환불 알림 (UI 업데이트)
      if (tournament.tournamentType == TournamentType.competitive) {
        const refundCredits = 20; // 항상 고정 20 크레딧
        _currentUser = _currentUser!.withUpdatedCredits(_currentUser!.credits + refundCredits);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('토너먼트 참가 취소 중 오류가 발생했습니다: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 크레딧 충전
  Future<bool> addCredits(int amount) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      await _firebaseService.addCredits(_currentUser!.uid, amount);
      
      // 로컬 상태 업데이트
      _currentUser = _currentUser!.withUpdatedCredits(_currentUser!.credits + amount);
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('크레딧 충전 중 오류가 발생했습니다: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 크레딧 조회
  Future<int> getUserCredits() async {
    if (_currentUser == null) return 0;
    
    try {
      final credits = await _firebaseService.getUserCredits();
      
      // 로컬 상태 업데이트
      if (_currentUser!.credits != credits) {
        _currentUser = _currentUser!.withUpdatedCredits(credits);
        notifyListeners();
      }
      
      return credits;
    } catch (e) {
      _setError('크레딧 조회 중 오류가 발생했습니다: $e');
      return _currentUser!.credits;
    }
  }
  
  // Apply to tournament (이전 호환성 유지)
  Future<bool> applyToTournament({
    required String tournamentId,
    required String role,
    String? message,
  }) async {
    return joinTournamentByRole(
      tournamentId: tournamentId,
      role: role,
      message: message,
    );
  }
  
  // Create chat room with notifications
  Future<String?> createChatRoom({
    required String targetUserId,
    required String title,
    required ChatRoomType type,
    String? initialMessage,
  }) async {
    if (_currentUser == null) return null;
    
    _setLoading(true);
    _clearError();
    
    try {
      // Create chat room and send notification using cloud function
      final chatRoomId = await _cloudFunctionsService.createChatRoomWithNotification(
        participantIds: [_currentUser!.uid, targetUserId],
        title: title,
        type: type,
        initialMessage: initialMessage,
      );
      
      return chatRoomId;
    } catch (e) {
      _setError('Failed to create chat room: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Create mercenary profile
  Future<bool> createMercenaryProfile({
    required Map<String, int> roleStats,
    required Map<String, int> skillStats,
    required List<String> preferredPositions,
    String? description,
  }) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      // Calculate average role stat
      double averageRoleStat = 0;
      if (roleStats.isNotEmpty) {
        final sum = roleStats.values.fold(0, (sum, stat) => sum + stat);
        averageRoleStat = sum / roleStats.length;
      }
      
      MercenaryModel mercenary = MercenaryModel(
        id: '',  // Will be set by Firestore
        userUid: _currentUser!.uid,
        nickname: _currentUser!.nickname,
        profileImageUrl: _currentUser!.profileImageUrl,
        tier: _currentUser!.tier,
        createdAt: Timestamp.now(),
        lastActiveAt: Timestamp.now(),
        roleStats: roleStats,
        skillStats: skillStats,
        preferredPositions: preferredPositions,
        description: description,
        averageRoleStat: averageRoleStat,
        averageRating: _currentUser!.averageRating ?? 0.0,
      );
      
      await _firebaseService.createMercenaryProfile(mercenary);
      return true;
    } catch (e) {
      _setError('Failed to create mercenary profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 토너먼트 일괄 삭제
  Future<int> deleteAllTournaments() async {
    _setLoading(true);
    _clearError();
    
    try {
      final count = await _firebaseService.deleteAllTournaments();
      return count;
    } catch (e) {
      _setError('Failed to delete tournaments: $e');
      return 0;
    } finally {
      _setLoading(false);
    }
  }
  
  // 토너먼트 삭제 (주최자만 가능)
  Future<bool> deleteTournament(String tournamentId) async {
    _setLoading(true);
    _clearError();
    
    try {
      // 토너먼트 정보 조회
      final tournament = await _firebaseService.getTournament(tournamentId);
      if (tournament == null) {
        _setError('토너먼트를 찾을 수 없습니다');
        return false;
      }
      
      // 주최자 확인
      if (_currentUser == null || tournament.hostId != _currentUser!.uid) {
        _setError('토너먼트 삭제 권한이 없습니다');
        return false;
      }
      
      // 토너먼트 삭제
      await _firebaseService.deleteTournament(tournamentId);
      
      // 삭제 성공
      return true;
    } catch (e) {
      _setError('토너먼트 삭제 중 오류가 발생했습니다: $e');
      debugPrint('Tournament deletion error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 사용자 데이터 초기화 (문제 해결용)
  Future<bool> resetUserData() async {
    if (!_authService.isLoggedIn) {
      _setError('사용자 로그인이 필요합니다');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      // 사용자 데이터 초기화
      await _authService.resetUserData();
      
      // 초기화된 사용자 정보 로드
      await _loadCurrentUser();
      
      return true;
    } catch (e) {
      _setError('사용자 데이터 초기화 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // 앱 전체에서 사용자 데이터 동기화
  Future<void> syncCurrentUser() async {
    try {
      if (!_authService.isLoggedIn) {
        debugPrint('AppStateProvider.syncCurrentUser() - 로그인되어 있지 않음, currentUser 초기화');
        _currentUser = null;
        notifyListeners();
        return;
      }
      
      // FirebaseAuth에서 사용자 정보 새로고침
      await _authService.reloadCurrentUser();
      
      // 새로운 사용자 데이터 가져오기
      final newUserData = await _firebaseService.getCurrentUser();
      
      // 변경 사항이 있는지 확인 (사용자 전환 또는 데이터 업데이트)
      final bool userChanged = _currentUser?.uid != newUserData?.uid;
      final bool dataChanged = _currentUser?.nickname != newUserData?.nickname;
      
      if (userChanged) {
        debugPrint('AppStateProvider.syncCurrentUser() - 사용자 변경됨: ${_currentUser?.uid} → ${newUserData?.uid}');
        
        // 다른 사용자로 변경되었으면 캐시 초기화
        _clearAllCaches();
      } else if (dataChanged) {
        debugPrint('AppStateProvider.syncCurrentUser() - 사용자 데이터 변경됨: ${_currentUser?.nickname} → ${newUserData?.nickname}');
      }
      
      // 사용자 데이터 업데이트
      _currentUser = newUserData;
      notifyListeners();
    } catch (e) {
      debugPrint('AppStateProvider.syncCurrentUser() - 오류 발생: $e');
    }
  }
} 