import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  
  AuthProvider({required this.authService}) {
    _init();
  }
  
  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => authService.isLoggedIn;
  
  // 초기화
  void _init() {
    // 현재 로그인된 사용자 정보 가져오기
    _fetchCurrentUser();
    
    // 사용자 상태 변경 감지
    authService.authStateChanges().listen((User? user) {
      if (user != null) {
        _fetchCurrentUser();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }
  
  // 현재 로그인된 사용자 정보 가져오기
  Future<void> _fetchCurrentUser() async {
    if (!authService.isLoggedIn) return;
    
    _setLoading(true);
    try {
      _user = await authService.getCurrentUserModel();
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // 로그인
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _clearError();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // 회원가입
  Future<void> signUp(String email, String password, String nickname) async {
    _setLoading(true);
    try {
      await authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        nickname: nickname,
      );
      _clearError();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await authService.signOut();
      _user = null;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // 비밀번호 재설정 메일 전송
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    try {
      await authService.sendPasswordResetEmail(email);
      _clearError();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // 프로필 업데이트
  Future<void> updateProfile({String? nickname, String? profileImageUrl}) async {
    _setLoading(true);
    try {
      await authService.updateUserProfile(
        nickname: nickname,
        profileImageUrl: profileImageUrl,
      );
      await _fetchCurrentUser(); // 업데이트 후 사용자 정보 다시 가져오기
      _clearError();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // 로딩 상태 설정
  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }
  
  // 에러 설정
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  // 에러 초기화
  void _clearError() {
    _error = null;
    notifyListeners();
  }
} 