import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  
  AuthProvider({required this.authService}) {
    // 초기화 시 현재 사용자 로드
    _loadCurrentUser();
    
    // 인증 상태 변경 감지
    authService.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadCurrentUser();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }
  
  // Getters
  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // 현재 사용자 정보 로드
  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _user = await authService.getCurrentUserModel();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading current user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 회원가입
  Future<bool> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        nickname: nickname,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = authService.getKoreanErrorMessage(e);
      return false;
    } catch (e) {
      _errorMessage = '회원가입 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 로그인
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = authService.getKoreanErrorMessage(e);
      return false;
    } catch (e) {
      _errorMessage = '로그인 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await authService.signOut();
      _user = null;
    } catch (e) {
      _errorMessage = '로그아웃 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 비밀번호 재설정 이메일 전송
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await authService.sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = authService.getKoreanErrorMessage(e);
      return false;
    } catch (e) {
      _errorMessage = '비밀번호 재설정 이메일 전송 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 사용자 프로필 업데이트
  Future<bool> updateProfile({
    String? nickname,
    String? profileImageUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await authService.updateUserProfile(
        nickname: nickname,
        profileImageUrl: profileImageUrl,
      );
      await _loadCurrentUser();
      return true;
    } catch (e) {
      _errorMessage = '프로필 업데이트 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 