import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  
  // 생성자에서 Firebase 인스턴스를 초기화하고 오류 처리
  AuthService() : 
    _auth = FirebaseAuth.instance,
    _firestore = FirebaseFirestore.instance {
    _checkFirebaseAuth();
  }

  // Firebase Auth 초기화 확인
  Future<void> _checkFirebaseAuth() async {
    try {
      // 단순히 authStateChanges를 한 번 호출하여 Firebase Auth가 초기화되었는지 확인
      await _auth.authStateChanges().first;
      debugPrint('Firebase Auth initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Firebase Auth: $e');
      // 여기서 필요한 경우 사용자에게 알림을 표시하거나 다른 조치를 취할 수 있습니다.
    }
  }
  
  // 인증 상태 변경 스트림
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  
  // 현재 사용자 getter
  User? get currentUser => _auth.currentUser;
  
  // 현재 사용자가 로그인했는지 확인
  bool get isLoggedIn => currentUser != null;
  
  // 현재 로그인된 사용자의 UserModel 가져오기
  Future<UserModel?> getCurrentUserModel() async {
    try {
      final user = currentUser;
      if (user == null) return null;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      } else {
        // 사용자 문서가 없는 경우 기본 문서 생성
        final newUser = UserModel(
          uid: user.uid,
          nickname: user.displayName ?? 'User${user.uid.substring(0, 4)}',
          joinedAt: Timestamp.now(),
        );
        
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        return newUser;
      }
    } catch (e) {
      debugPrint('Error getting user model: $e');
      return null;
    }
  }
  
  // 이메일과 비밀번호로 회원가입
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      // Firebase Auth가 초기화되었는지 확인
      await _checkFirebaseAuth();
      
      // 이메일 인증 여부 확인
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: '이미 사용 중인 이메일입니다.'
        );
      }
      
      // Firebase Auth에 사용자 등록
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 사용자 프로필 업데이트
      await credential.user?.updateDisplayName(nickname);
      
      // 사용자에게 이메일 인증 메일 보내기
      await credential.user?.sendEmailVerification();
      
      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'nickname': nickname,
        'joinedAt': Timestamp.now(),
        'credits': 0,
        'isPremium': false,
        'isVerified': false,
        'signInProviders': ['password'],
      });
      
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception during signup: ${e.code} - ${e.message}');
      
      // BILLING_NOT_ENABLED 오류 확인 및 처리
      if (e.code == 'internal-error' && e.message?.contains('BILLING_NOT_ENABLED') == true) {
        debugPrint('Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.');
        throw FirebaseAuthException(
          code: 'billing-not-enabled',
          message: 'Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.'
        );
      }
      
      throw getKoreanErrorMessage(e);
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }
  
  // 이메일과 비밀번호로 로그인
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Firebase Auth가 초기화되었는지 확인
      await _checkFirebaseAuth();
      
      // Firebase Auth에 로그인 시도
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 마지막 로그인 시간 업데이트
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastActiveAt': Timestamp.now(),
      });
      
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception during signin: ${e.code} - ${e.message}');
      
      // BILLING_NOT_ENABLED 오류 확인 및 처리
      if (e.code == 'internal-error' && e.message?.contains('BILLING_NOT_ENABLED') == true) {
        debugPrint('Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.');
        throw FirebaseAuthException(
          code: 'billing-not-enabled',
          message: 'Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.'
        );
      }
      
      throw getKoreanErrorMessage(e);
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
  
  // 이메일 인증 메일 재전송
  Future<void> resendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('사용자가 로그인되어 있지 않습니다.');
      
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('Error sending email verification: $e');
      rethrow;
    }
  }
  
  // 이메일 인증 상태 확인
  Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // 사용자 정보 새로고침
      await user.reload();
      
      // 이메일 인증 상태 확인
      bool isVerified = user.emailVerified;
      
      // Firestore 사용자 정보 업데이트
      if (isVerified) {
        await _firestore.collection('users').doc(user.uid).update({
          'isVerified': true,
        });
      }
      
      return isVerified;
    } catch (e) {
      debugPrint('Error checking email verification status: $e');
      return false;
    }
  }
  
  // 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // 이메일이 실제로 등록되어 있는지 확인
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: '해당 이메일로 등록된 사용자가 없습니다.'
        );
      }
      
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      debugPrint('Error sending password reset email: ${e.code} - ${e.message}');
      throw getKoreanErrorMessage(e);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }
  
  // 비밀번호 재설정 코드 확인
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      await _auth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Error confirming password reset: ${e.code} - ${e.message}');
      throw getKoreanErrorMessage(e);
    } catch (e) {
      debugPrint('Error confirming password reset: $e');
      rethrow;
    }
  }
  
  // 사용자 정보 업데이트
  Future<void> updateUserProfile({
    String? nickname,
    String? profileImageUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('사용자가 로그인되어 있지 않습니다.');
      
      final updates = <String, dynamic>{};
      
      if (nickname != null) {
        await user.updateDisplayName(nickname);
        updates['nickname'] = nickname;
      }
      
      if (profileImageUrl != null) {
        await user.updatePhotoURL(profileImageUrl);
        updates['profileImageUrl'] = profileImageUrl;
      }
      
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // 계정 삭제
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('사용자가 로그인되어 있지 않습니다.');
      
      // Firestore에서 사용자 데이터 삭제
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Firebase Auth에서 사용자 삭제
      await user.delete();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }
  
  // Firebase Auth 에러 메시지를 한국어로 변환
  String getKoreanErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'user-disabled':
        return '이 계정은 비활성화되었습니다.';
      case 'user-not-found':
        return '해당 이메일로 등록된 계정이 없습니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'operation-not-allowed':
        return '이 작업은 현재 허용되지 않습니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 6자 이상의 강력한 비밀번호를 사용해주세요.';
      case 'network-request-failed':
        return '네트워크 연결에 문제가 있습니다. 인터넷 연결을 확인해주세요.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      case 'invalid-credential':
        return '제공된 인증 정보가 잘못되었습니다.';
      case 'account-exists-with-different-credential':
        return '동일한 이메일을 사용하는 계정이 이미 다른 방식으로 등록되어 있습니다.';
      case 'requires-recent-login':
        return '이 작업을 수행하려면 최근에 로그인해야 합니다. 다시 로그인 후 시도해주세요.';
      case 'provider-already-linked':
        return '이 인증 방식은 이미 계정에 연결되어 있습니다.';
      case 'credential-already-in-use':
        return '이 인증 정보는 이미 다른 계정에서 사용 중입니다.';
      case 'invalid-verification-code':
        return '인증 코드가 잘못되었습니다.';
      case 'invalid-verification-id':
        return '인증 ID가 잘못되었습니다.';
      case 'captcha-check-failed':
        return 'reCAPTCHA 확인에 실패했습니다.';
      case 'app-not-authorized':
        return '앱이 Firebase Authentication을 사용할 권한이 없습니다.';
      case 'expired-action-code':
        return '인증 코드가 만료되었습니다.';
      case 'invalid-action-code':
        return '인증 코드가 잘못되었습니다.';
      case 'missing-action-code':
        return '인증 코드가 제공되지 않았습니다.';
      case 'quota-exceeded':
        return '할당량이 초과되었습니다.';
      case 'unauthorized-domain':
        return '허가되지 않은 도메인입니다.';
      case 'invalid-continue-uri':
        return 'Continue URL이 잘못되었습니다.';
      case 'missing-continue-uri':
        return 'Continue URL이 제공되지 않았습니다.';
      case 'missing-email':
        return '이메일이 제공되지 않았습니다.';
      case 'missing-phone-number':
        return '전화번호가 제공되지 않았습니다.';
      case 'invalid-phone-number':
        return '잘못된 전화번호 형식입니다.';
      case 'missing-verification-code':
        return '인증 코드가 제공되지 않았습니다.';
      case 'invalid-recipient-email':
        return '수신자 이메일이 잘못되었습니다.';
      case 'invalid-sender':
        return '발신자 이메일이 잘못되었습니다.';
      case 'missing-verification-id':
        return '인증 ID가 제공되지 않았습니다.';
      case 'rejected-credential':
        return '인증 정보가 거부되었습니다.';
      case 'invalid-message-payload':
        return '메시지 페이로드가 잘못되었습니다.';
      case 'invalid-recipient':
        return '수신자가 잘못되었습니다.';
      case 'missing-android-pkg-name':
        return 'Android 패키지 이름이 제공되지 않았습니다.';
      case 'missing-ios-bundle-id':
        return 'iOS 번들 ID가 제공되지 않았습니다.';
      case 'invalid-argument':
        return '잘못된 인자가 제공되었습니다.';
      case 'invalid-password':
        return '비밀번호가 유효하지 않습니다.';
      case 'billing-not-enabled':
        return 'Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.';
      case 'internal-error':
        if (e.message?.contains('BILLING_NOT_ENABLED') == true) {
          return 'Firebase 결제 계정이 필요합니다. Firebase Console에서 Blaze 플랜으로 업그레이드하세요.';
        }
        return '내부 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      default:
        return e.message ?? '알 수 없는 오류가 발생했습니다.';
    }
  }
} 