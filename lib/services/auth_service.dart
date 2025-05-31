import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
          joinedAt: DateTime.now(),
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
      // Firebase Auth에 사용자 등록
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 사용자 프로필 업데이트
      await credential.user?.updateDisplayName(nickname);
      
      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'nickname': nickname,
        'joinedAt': Timestamp.now(),
        'credits': 0,
        'isPremium': false,
        'isVerified': false,
      });
      
      return credential;
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
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 마지막 로그인 시간 업데이트
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastActiveAt': Timestamp.now(),
      });
      
      return credential;
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
  
  // 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
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
  
  // Firebase Auth 오류 메시지를 한글로 변환
  String getKoreanErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '해당 이메일로 등록된 사용자가 없습니다.';
      case 'wrong-password':
        return '비밀번호가 일치하지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 더 강력한 비밀번호를 사용해주세요.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'user-disabled':
        return '해당 계정은 비활성화되었습니다.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      case 'operation-not-allowed':
        return '이 작업은 허용되지 않습니다.';
      case 'network-request-failed':
        return '네트워크 연결에 문제가 있습니다.';
      default:
        return '오류가 발생했습니다: ${e.code}';
    }
  }
} 