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
  Future<void> _loadCurrentUser() async {
    if (!_authService.isLoggedIn) return;
    
    _setLoading(true);
    try {
      _currentUser = await _firebaseService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load user profile: $e');
    } finally {
      _setLoading(false);
    }
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
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to sign out: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile({
    String? nickname,
    String? riotId,
    String? tier,
    String? profileImageUrl,
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
    required bool isPaid,
    int? price,
    int? ovrLimit,
    PlayerTier? tierLimit,
    String? description,
    bool? premiumBadge, // Optional: Will be determined by user's premium status
    GeoPoint? locationCoordinates,
    GameFormat? gameFormat,
    String? customRoomName,
    String? customRoomPassword,
  }) async {
    if (_currentUser == null) return null;
    
    _setLoading(true);
    _clearError();
    
    try {
      // 기본 슬롯 맵 생성
      final Map<String, int> slots = {
        'team1': 5,
        'team2': 5,
      };
      
      // 각 역할별 빈 슬롯 맵 생성
      final Map<String, int> filledSlotsByRole = {
        'top': 0,
        'jungle': 0,
        'mid': 0,
        'adc': 0,
        'support': 0,
      };
      
      // 빈 슬롯 맵 생성
      final Map<String, int> filledSlots = {
        'team1': 0,
        'team2': 0,
      };
      
      // 프리미엄 멤버십 확인하여 자동으로 프리미엄 배지 설정
      final bool hasPremiumBadge = premiumBadge ?? _currentUser!.isPremium;
      
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
        isPaid: isPaid,
        price: price,
        status: TournamentStatus.open,
        createdAt: DateTime.now(),
        slots: slots,
        filledSlots: filledSlots,
        slotsByRole: slotsByRole,
        filledSlotsByRole: filledSlotsByRole,
        participants: [],
        ovrLimit: ovrLimit,
        tierLimit: tierLimit,
        premiumBadge: hasPremiumBadge,
        gameFormat: gameFormat ?? GameFormat.single,
        gameServer: GameServer.kr, // 기본값으로 한국 서버 설정
        // Additional fields can be added to extras if needed
        rules: {
          'ovrLimit': ovrLimit,
          'tierLimit': tierLimit?.index,
          'premiumBadge': hasPremiumBadge,
          'locationCoordinates': locationCoordinates != null ? {
            'latitude': locationCoordinates.latitude,
            'longitude': locationCoordinates.longitude,
          } : null,
          'customRoomName': customRoomName,
          'customRoomPassword': customRoomPassword,
        },
      );
      
      String id = await _firebaseService.createTournament(tournament);
      
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
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Apply to tournament
  Future<bool> applyToTournament({
    required String tournamentId,
    required String role,
    String? message,
  }) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      ApplicationModel application = ApplicationModel(
        id: '',  // Will be set by Firestore
        tournamentId: tournamentId,
        userUid: _currentUser!.uid,
        userName: _currentUser!.nickname,
        userProfileImageUrl: _currentUser!.profileImageUrl,
        role: role,
        userOvr: null,  // TODO: Get user OVR for this role if available
        appliedAt: Timestamp.now(),
        message: message,
        status: ApplicationStatus.pending,
      );
      
      await _firebaseService.applyToTournament(application);
      
      // Process application through cloud function (will handle notifications)
      try {
        await _cloudFunctionsService.processTournamentApplication(
          tournamentId: tournamentId,
          userId: _currentUser!.uid,
          role: role,
        );
      } catch (e) {
        // Non-critical error, just log it
        debugPrint('Failed to process application: $e');
      }
      
      return true;
    } catch (e) {
      _setError('Failed to apply to tournament: $e');
      return false;
    } finally {
      _setLoading(false);
    }
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
} 