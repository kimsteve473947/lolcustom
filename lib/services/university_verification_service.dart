import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/university_verification_model.dart';

class UniversityVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 대학 인증 신청
  Future<String> submitVerification({
    required String userId,
    required String userName,
    required String universityName,
    required String studentId,
    required String major,
    required DocumentType documentType,
    required File imageFile,
  }) async {
    try {
      // 1. 이미지 Firebase Storage에 업로드
      final imageUrl = await _uploadVerificationImage(userId, imageFile);
      
      // 2. Firestore에 인증 신청 정보 저장
      final verification = UniversityVerificationModel(
        id: '',
        userId: userId,
        userName: userName,
        universityName: universityName,
        studentId: studentId,
        major: major,
        documentType: documentType,
        imageUrl: imageUrl,
        createdAt: Timestamp.now(),
      );

      final docRef = await _firestore
          .collection('universityVerifications')
          .add(verification.toFirestore());

      debugPrint('대학 인증 신청 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('대학 인증 신청 중 오류: $e');
      throw Exception('인증 신청 중 오류가 발생했습니다: $e');
    }
  }

  // 이미지 업로드
  Future<String> _uploadVerificationImage(String userId, File imageFile) async {
    try {
      final fileName = 'verification_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('university_verifications').child(fileName);
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('인증 이미지 업로드 완료: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('이미지 업로드 실패: $e');
      throw Exception('이미지 업로드에 실패했습니다: $e');
    }
  }

  // 사용자 인증 상태 조회
  Future<UniversityVerificationModel?> getUserVerification(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('universityVerifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UniversityVerificationModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('사용자 인증 상태 조회 실패: $e');
      return null;
    }
  }

  // 인증 상태 스트림
  Stream<UniversityVerificationModel?> getUserVerificationStream(String userId) {
    return _firestore
        .collection('universityVerifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return UniversityVerificationModel.fromFirestore(snapshot.docs.first);
          }
          return null;
        });
  }

  // 모든 인증 신청 조회 (관리자용)
  Future<List<UniversityVerificationModel>> getAllVerifications({
    VerificationStatus? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('universityVerifications')
          .orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.index);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => UniversityVerificationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('인증 신청 목록 조회 실패: $e');
      return [];
    }
  }

  // 인증 승인 (관리자용)
  Future<void> approveVerification(String verificationId, String adminId) async {
    try {
      await _firestore
          .collection('universityVerifications')
          .doc(verificationId)
          .update({
        'status': VerificationStatus.approved.index,
        'verifiedBy': adminId,
        'verifiedAt': Timestamp.now(),
      });

      debugPrint('인증 승인 완료: $verificationId');
    } catch (e) {
      debugPrint('인증 승인 실패: $e');
      throw Exception('인증 승인에 실패했습니다: $e');
    }
  }

  // 인증 거부 (관리자용)
  Future<void> rejectVerification(
    String verificationId,
    String adminId,
    String reason,
  ) async {
    try {
      await _firestore
          .collection('universityVerifications')
          .doc(verificationId)
          .update({
        'status': VerificationStatus.rejected.index,
        'verifiedBy': adminId,
        'verifiedAt': Timestamp.now(),
        'rejectionReason': reason,
      });

      debugPrint('인증 거부 완료: $verificationId');
    } catch (e) {
      debugPrint('인증 거부 실패: $e');
      throw Exception('인증 거부에 실패했습니다: $e');
    }
  }

  // 사용자의 대학 정보 조회 (인증된 경우)
  Future<String?> getUserUniversity(String userId) async {
    try {
      final verification = await getUserVerification(userId);
      if (verification != null && verification.status == VerificationStatus.approved) {
        return verification.universityName;
      }
      return null;
    } catch (e) {
      debugPrint('사용자 대학 정보 조회 실패: $e');
      return null;
    }
  }

  // 사용자 인증 여부 확인
  Future<bool> isUserVerified(String userId) async {
    try {
      final verification = await getUserVerification(userId);
      return verification != null && verification.status == VerificationStatus.approved;
    } catch (e) {
      debugPrint('사용자 인증 여부 확인 실패: $e');
      return false;
    }
  }
} 