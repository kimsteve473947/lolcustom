import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';

class AppStateProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirebaseService _firebaseService;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Constructor
  AppStateProvider({
    required AuthService authService,
    required FirebaseService firebaseService,
  }) : 
    _authService = authService,
    _firebaseService = firebaseService {
    _initializeApp();
  }
  
  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _authService.isLoggedIn;
  
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
      _currentUser = await _firebaseService.getCurrentUserModel();
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
      await _authService.signInWithEmailAndPassword(email, password);
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
      await _authService.registerWithEmailAndPassword(email, password);
      await _authService.createUserProfile(nickname);
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
      UserModel updatedUser = _currentUser!.copyWith(
        nickname: nickname,
        riotId: riotId,
        tier: tier,
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
    required String location,
    required DateTime startsAt,
    required Map<String, int> slotsByRole,
    required bool isPaid,
    int? price,
    int? ovrLimit,
    String? description,
    bool premiumBadge = false,
    GeoPoint? locationCoordinates,
  }) async {
    if (_currentUser == null) return null;
    
    _setLoading(true);
    _clearError();
    
    try {
      TournamentModel tournament = TournamentModel(
        id: '',  // Will be set by Firestore
        hostUid: _currentUser!.uid,
        hostNickname: _currentUser!.nickname,
        hostProfileImageUrl: _currentUser!.profileImageUrl,
        startsAt: Timestamp.fromDate(startsAt),
        location: location,
        locationCoordinates: locationCoordinates,
        isPaid: isPaid,
        price: price,
        ovrLimit: ovrLimit,
        premiumBadge: premiumBadge,
        slotsByRole: slotsByRole,
        filledSlotsByRole: {
          'top': 0,
          'jungle': 0,
          'mid': 0,
          'adc': 0,
          'support': 0,
        },
        status: TournamentStatus.open,
        createdAt: Timestamp.now(),
        description: description,
      );
      
      String id = await _firebaseService.createTournament(tournament);
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
      );
      
      await _firebaseService.applyToTournament(application);
      return true;
    } catch (e) {
      _setError('Failed to apply to tournament: $e');
      return false;
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
      MercenaryModel mercenary = MercenaryModel(
        id: '',  // Will be set by Firestore
        userUid: _currentUser!.uid,
        nickname: _currentUser!.nickname,
        profileImageUrl: _currentUser!.profileImageUrl,
        tier: _currentUser!.tier,
        roleStats: roleStats,
        skillStats: skillStats,
        isAvailable: true,
        preferredPositions: preferredPositions,
        description: description,
        createdAt: Timestamp.now(),
        lastActiveAt: Timestamp.now(),
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
  
  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 