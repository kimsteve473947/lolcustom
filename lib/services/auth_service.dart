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
      if (user == null) {
        debugPrint('AuthService.getCurrentUserModel() - 로그인된 사용자 없음');
        return null;
      }
      
      // 현재 Firebase Auth 사용자 정보 새로고침
      await user.reload();
      final refreshedUser = _auth.currentUser; // 새로고침 후 다시 가져오기
      
      if (refreshedUser == null) {
        debugPrint('AuthService.getCurrentUserModel() - 새로고침 후 사용자 없음 (세션 만료)');
        return null;
      }
      
      debugPrint('AuthService.getCurrentUserModel() - Firestore에서 사용자 문서 조회 시작: ${refreshedUser.uid}');
      
      // Firestore에서 사용자 문서 가져오기
      final doc = await _firestore.collection('users').doc(refreshedUser.uid).get();
      
      if (doc.exists) {
        final userModel = UserModel.fromFirestore(doc);
        debugPrint('AuthService.getCurrentUserModel() - 사용자 문서 조회 성공: ${userModel.nickname} (${userModel.uid})');
        return userModel;
      } else {
        debugPrint('AuthService.getCurrentUserModel() - 사용자 문서 없음. 새 문서 생성: ${refreshedUser.uid}');
        // 사용자 문서가 없는 경우 기본 문서 생성
        final newUser = UserModel(
          uid: refreshedUser.uid,
          email: refreshedUser.email ?? '',
          nickname: refreshedUser.displayName ?? 'User${refreshedUser.uid.substring(0, 4)}',
          joinedAt: Timestamp.now(),
        );
        
        await _firestore.collection('users').doc(refreshedUser.uid).set(newUser.toMap());
        return newUser;
      }
    } catch (e) {
      debugPrint('AuthService.getCurrentUserModel() - 오류 발생: $e');
      return null;
    }
  }
  
  // Firebase 인증 사용자 정보 새로고침
  Future<void> reloadCurrentUser() async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.reload();
        debugPrint('Reloaded Firebase Auth user: ${currentUser?.email} (${currentUser?.uid})');
      }
    } catch (e) {
      debugPrint('Error reloading current user: $e');
    }
  }
  
  // 사용자 데이터 초기화 (문제 해결용)
  Future<void> resetUserData() async {
    try {
      final user = currentUser;
      if (user == null) {
        debugPrint('resetUserData: No current user logged in');
        return;
      }
      
      // 현재 사용자 정보 새로고침
      await user.reload();
      
      // 현재 사용자 문서 가져오기
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      // 이메일 주소 가져오기
      final email = user.email ?? '';
      
      // 디스플레이 이름 가져오기
      final displayName = user.displayName ?? 'User${user.uid.substring(0, 4)}';
      
      debugPrint('resetUserData: Resetting user data for ${user.uid} ($email, $displayName)');
      
      // 사용자 문서 업데이트 또는 생성
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'nickname': displayName,
        'joinedAt': doc.exists ? (doc.data() as Map<String, dynamic>)['joinedAt'] ?? Timestamp.now() : Timestamp.now(),
        'lastActiveAt': Timestamp.now(),
        'credits': doc.exists ? (doc.data() as Map<String, dynamic>)['credits'] ?? 0 : 0,
        'isPremium': doc.exists ? (doc.data() as Map<String, dynamic>)['isPremium'] ?? false : false,
        'isVerified': user.emailVerified,
        'signInProviders': ['password'],
      }, SetOptions(merge: true));
      
      debugPrint('resetUserData: User data has been reset successfully');
    } catch (e) {
      debugPrint('Error resetting user data: $e');
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
      
      // 디버깅 정보 로깅
      debugPrint('회원가입 - nickname: $nickname, displayName: ${credential.user?.displayName}');
      
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
      
      // 유저 존재 여부 확인
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(credential.user!.uid).get();
      
      // 유저 문서가 없는 경우 생성
      if (!userDoc.exists) {
        // 기본 닉네임 생성
        String nickname = credential.user?.displayName ?? 'User${credential.user!.uid.substring(0, 4)}';
        
        // Firestore에 사용자 정보 저장
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'nickname': nickname,
          'joinedAt': Timestamp.now(),
          'lastActiveAt': Timestamp.now(),
          'credits': 0,
          'isPremium': false,
          'isVerified': credential.user?.emailVerified ?? false,
          'signInProviders': ['password'],
        });
      } else {
        // 마지막 로그인 시간 업데이트
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'lastActiveAt': Timestamp.now(),
        });
      }
      
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
      // 로그아웃 전 현재 사용자 ID 저장 (디버깅용)
      final currentUid = _auth.currentUser?.uid;
      final currentEmail = _auth.currentUser?.email;
      debugPrint('로그아웃 시도: $currentEmail ($currentUid)');
      
      // Firebase 인증에서 로그아웃
      await _auth.signOut();
      
      // 로그아웃 확인
      debugPrint('Firebase 로그아웃 완료. 현재 사용자: ${_auth.currentUser?.email ?? "없음"}');
      
      // Firebase 인증 상태 명시적으로 확인 (디버깅용)
      if (_auth.currentUser == null) {
        debugPrint('로그아웃 성공: 사용자 세션이 정상적으로 종료됨');
      } else {
        debugPrint('로그아웃 불완전: 여전히 인증된 사용자가 있음 - ${_auth.currentUser?.email}');
        // 강제로 다시 시도
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('로그아웃 중 오류 발생: $e');
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

  // Discord OAuth2 로그인 (Firebase Auth 내장 기능 사용)
  Future<UserCredential> signInWithDiscord() async {
    try {
      debugPrint('Discord OAuth2 로그인 시작');
      
      // Firebase Auth가 초기화되었는지 확인
      await _checkFirebaseAuth();
      
      // Discord OAuth Provider 생성
      final discordProvider = OAuthProvider('discord.com');
      discordProvider.addScope('identify');
      discordProvider.addScope('email');
      
      // Discord OAuth2 인증
      final credential = await _auth.signInWithProvider(discordProvider);
      
      debugPrint('Discord OAuth2 인증 성공: ${credential.user?.email}');
      
      // Discord 사용자 정보 추출
      final user = credential.user;
      if (user == null) {
        throw Exception('Discord 인증에 성공했지만 사용자 정보를 가져올 수 없습니다.');
      }
      
      // OAuth 추가 정보에서 Discord 특정 정보 추출
      String? discordId;
      String? discordUsername;
      String? discordAvatar;
      
      // additionalUserInfo에서 Discord 정보 추출
      final additionalInfo = credential.additionalUserInfo?.profile;
      if (additionalInfo != null) {
        discordId = additionalInfo['id']?.toString();
        discordUsername = additionalInfo['username']?.toString();
        discordAvatar = additionalInfo['avatar']?.toString();
        
        // Discord CDN을 통한 프로필 이미지 URL 생성
        if (discordAvatar != null && discordId != null) {
          discordAvatar = 'https://cdn.discordapp.com/avatars/$discordId/$discordAvatar.png';
        }
        
        debugPrint('Discord 사용자 정보 - ID: $discordId, Username: $discordUsername');
      }
      
      // Firestore에서 기존 사용자 문서 확인
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      final now = Timestamp.now();
      
      if (!userDoc.exists) {
        // 새 사용자 생성
        debugPrint('새 Discord 사용자 생성: ${user.email}');
        
        final nickname = discordUsername ?? user.displayName ?? 'User${user.uid.substring(0, 4)}';
        
        // Discord 정보를 additionalInfo에 저장
        final discordInfo = <String, dynamic>{
          if (discordId != null) 'discordId': discordId,
          if (discordUsername != null) 'discordUsername': discordUsername,
          if (discordAvatar != null) 'discordAvatar': discordAvatar,
          'discordConnectedAt': now.millisecondsSinceEpoch,
        };

        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          nickname: nickname,
          profileImageUrl: discordAvatar ?? user.photoURL ?? '',
          joinedAt: now,
          role: UserRole.user,
          credits: 0,
          isPremium: false,
          additionalInfo: discordInfo,
        );
        
        await _firestore.collection('users').doc(user.uid).set(newUser.toFirestore());
        debugPrint('새 Discord 사용자 문서 생성 완료');
        
      } else {
        // 기존 사용자 업데이트 (Discord 정보 추가/업데이트)
        debugPrint('기존 사용자에 Discord 정보 업데이트: ${user.email}');
        
        final userData = userDoc.data() as Map<String, dynamic>;
        final currentAdditionalInfo = userData['additionalInfo'] as Map<String, dynamic>? ?? {};
        
        // Discord 정보를 additionalInfo에 병합
        final discordInfo = <String, dynamic>{
          if (discordId != null) 'discordId': discordId,
          if (discordUsername != null) 'discordUsername': discordUsername,
          if (discordAvatar != null) 'discordAvatar': discordAvatar,
          'discordConnectedAt': now.millisecondsSinceEpoch,
        };
        
        // 기존 additionalInfo와 병합
        final mergedAdditionalInfo = {...currentAdditionalInfo, ...discordInfo};
        
        final updates = <String, dynamic>{
          'lastActiveAt': now,
          'additionalInfo': mergedAdditionalInfo,
        };
        
        // 프로필 이미지가 없는 경우 Discord 아바타를 기본 프로필 이미지로 설정
        if (discordAvatar != null) {
          final currentProfileImage = userData['profileImageUrl'] as String?;
          if (currentProfileImage == null || currentProfileImage.isEmpty) {
            updates['profileImageUrl'] = discordAvatar;
          }
        }
        
        await _firestore.collection('users').doc(user.uid).update(updates);
        debugPrint('Discord 정보 업데이트 완료');
      }
      
      return credential;
      
    } on FirebaseAuthException catch (e) {
      debugPrint('Discord OAuth2 Firebase Auth Exception: ${e.code} - ${e.message}');
      
      // Discord OAuth2 관련 오류 처리
      if (e.code == 'user-cancelled') {
        throw FirebaseAuthException(
          code: 'user-cancelled',
          message: 'Discord 로그인이 취소되었습니다.',
        );
      } else if (e.code == 'network-request-failed') {
        throw FirebaseAuthException(
          code: 'network-request-failed',
          message: '네트워크 연결에 문제가 있습니다. 인터넷 연결을 확인해주세요.',
        );
      }
      
      throw getKoreanErrorMessage(e);
    } catch (e) {
      debugPrint('Discord OAuth2 로그인 중 오류: $e');
      rethrow;
    }
  }
  
  // Discord 연결 해제
  Future<void> disconnectDiscord() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('사용자가 로그인되어 있지 않습니다.');
      
      debugPrint('Discord 연결 해제 시작: ${user.uid}');
      
      // 현재 사용자 정보 가져오기
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return;
      
      final userData = doc.data() as Map<String, dynamic>;
      final currentAdditionalInfo = userData['additionalInfo'] as Map<String, dynamic>? ?? {};
      
      // Discord 관련 정보 제거
      final updatedAdditionalInfo = Map<String, dynamic>.from(currentAdditionalInfo);
      updatedAdditionalInfo.removeWhere((key, value) => 
        key.startsWith('discord') || key == 'discordConnectedAt');
      
      // Firestore에서 Discord 정보 제거
      await _firestore.collection('users').doc(user.uid).update({
        'additionalInfo': updatedAdditionalInfo,
      });
      
      debugPrint('Discord 연결 해제 완료');
    } catch (e) {
      debugPrint('Discord 연결 해제 중 오류: $e');
      rethrow;
    }
  }
  
  // 사용자의 Discord 연결 상태 확인
  Future<bool> isDiscordConnected() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      
      final userData = doc.data() as Map<String, dynamic>;
      final additionalInfo = userData['additionalInfo'] as Map<String, dynamic>?;
      
      if (additionalInfo == null) return false;
      
      final discordId = additionalInfo['discordId'] as String?;
      return discordId != null && discordId.isNotEmpty;
    } catch (e) {
      debugPrint('Discord 연결 상태 확인 중 오류: $e');
      return false;
    }
  }
} 