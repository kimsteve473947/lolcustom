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
    debugPrint('AuthProvider._init() 시작');
    _fetchCurrentUser();
    
    // 사용자 상태 변경 감지
    authService.authStateChanges().listen((User? user) {
      debugPrint('AuthProvider - Auth 상태 변경 감지: ${user?.email} (${user?.uid})');
      if (user != null) {
        // 사용자가 로그인하면 정보 새로고침
        _fetchCurrentUser(forceRefresh: true);
      } else {
        // 사용자가 로그아웃하면 null로 설정
        debugPrint('AuthProvider - 사용자 로그아웃 감지: 데이터 초기화');
        _user = null;
        notifyListeners();
      }
    });
  }
  
  // 현재 로그인된 사용자 정보 가져오기
  Future<void> _fetchCurrentUser({bool forceRefresh = false}) async {
    if (!authService.isLoggedIn) {
      debugPrint('AuthProvider._fetchCurrentUser() - 로그인되어 있지 않음');
      _user = null;
      notifyListeners();
      return;
    }
    
    _setLoading(true);
    try {
      // 강제로 Firebase Auth 사용자 정보 새로고침
      if (forceRefresh) {
        await authService.reloadCurrentUser();
        debugPrint('AuthProvider - 사용자 정보 강제 새로고침 완료: ${authService.currentUser?.email}');
      }
      
      // Firestore에서 최신 사용자 정보 가져오기
      _user = await authService.getCurrentUserModel();
      debugPrint('AuthProvider - 사용자 정보 로드 완료: ${_user?.nickname} (${_user?.uid})');
      _clearError();
    } catch (e) {
      debugPrint('AuthProvider - 사용자 정보 로드 오류: $e');
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
    } on FirebaseAuthException catch (e) {
      // Firebase Auth 오류 처리
      if (e.code == 'billing-not-enabled') {
        _setError('Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.');
      } else {
        _setError(authService.getKoreanErrorMessage(e));
      }
      rethrow;
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
      
      // 회원가입 성공 후 이메일 인증 안내 메시지 설정
      _setMessage('회원가입이 완료되었습니다. 이메일 인증 메일을 확인해주세요.');
    } on FirebaseAuthException catch (e) {
      // Firebase Auth 오류 처리
      if (e.code == 'billing-not-enabled') {
        _setError('Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.');
      } else {
        _setError(authService.getKoreanErrorMessage(e));
      }
      rethrow;
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
      // 로그아웃 시도 로깅
      debugPrint('로그아웃 시작: ${authService.currentUser?.email}');
      
      // Firebase 인증에서 로그아웃
      await authService.signOut();
      
      // 사용자 데이터 명시적으로 초기화
      _user = null;
      
      // 메모리 캐시 클리어
      _clearError();
      
      // 데이터 갱신 알림
      notifyListeners();
      
      debugPrint('로그아웃 완료. 현재 사용자 데이터: $_user');
    } catch (e) {
      _setError('로그아웃 중 오류 발생: $e');
      debugPrint('로그아웃 오류: $e');
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
      _setMessage('비밀번호 재설정 이메일이 전송되었습니다. 이메일을 확인해주세요.');
    } on FirebaseAuthException catch (e) {
      _setError(authService.getKoreanErrorMessage(e));
      rethrow;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // 비밀번호 재설정 코드 확인
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    _setLoading(true);
    try {
      await authService.confirmPasswordReset(code, newPassword);
      _clearError();
      _setMessage('비밀번호가 성공적으로 변경되었습니다.');
    } on FirebaseAuthException catch (e) {
      _setError(authService.getKoreanErrorMessage(e));
      rethrow;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // 이메일 인증 메일 재전송
  Future<void> resendEmailVerification() async {
    _setLoading(true);
    try {
      await authService.resendEmailVerification();
      _clearError();
      _setMessage('이메일 인증 메일이 재전송되었습니다. 이메일을 확인해주세요.');
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // 이메일 인증 상태 확인
  Future<bool> checkEmailVerified() async {
    _setLoading(true);
    try {
      final isVerified = await authService.checkEmailVerified();
      _clearError();
      return isVerified;
    } catch (e) {
      _setError(e.toString());
      return false;
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
    _message = null;
    notifyListeners();
  }
  
  // 메시지 설정
  String? _message;
  String? get message => _message;
  
  void _setMessage(String message) {
    _message = message;
    _error = null;
    notifyListeners();
  }
  
  // 에러 및 메시지 초기화
  void _clearError() {
    _error = null;
    _message = null;
    notifyListeners();
  }
} 