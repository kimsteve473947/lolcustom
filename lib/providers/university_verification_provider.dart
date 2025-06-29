import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/university_verification_model.dart';
import 'package:lol_custom_game_manager/services/university_verification_service.dart';

class UniversityVerificationProvider extends ChangeNotifier {
  final UniversityVerificationService _service = UniversityVerificationService();

  UniversityVerificationModel? _userVerification;
  bool _isLoading = false;
  String? _error;

  // Getters
  UniversityVerificationModel? get userVerification => _userVerification;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get isVerified => 
      _userVerification?.status == VerificationStatus.approved;
  
  bool get isPending => 
      _userVerification?.status == VerificationStatus.pending;
  
  bool get isRejected => 
      _userVerification?.status == VerificationStatus.rejected;

  String? get userUniversity => 
      isVerified ? _userVerification?.universityName : null;

  // 사용자 인증 상태 로드
  Future<void> loadUserVerification(String userId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    _setError(null);

    try {
      _userVerification = await _service.getUserVerification(userId);
      debugPrint('사용자 인증 상태 로드: ${_userVerification?.statusText}');
    } catch (e) {
      _setError('인증 상태를 불러오는데 실패했습니다: $e');
      debugPrint('사용자 인증 상태 로드 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 대학 인증 신청
  Future<bool> submitVerification({
    required String userId,
    required String userName,
    required String universityName,
    required String studentId,
    required String major,
    required DocumentType documentType,
    required File imageFile,
  }) async {
    if (_isLoading) return false;

    _setLoading(true);
    _setError(null);

    try {
      final verificationId = await _service.submitVerification(
        userId: userId,
        userName: userName,
        universityName: universityName,
        studentId: studentId,
        major: major,
        documentType: documentType,
        imageFile: imageFile,
      );

      // 신청 후 상태 다시 로드
      await loadUserVerification(userId);
      
      debugPrint('대학 인증 신청 완료: $verificationId');
      return true;
    } catch (e) {
      _setError('인증 신청에 실패했습니다: $e');
      debugPrint('대학 인증 신청 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 인증 상태 스트림 구독
  Stream<UniversityVerificationModel?> getUserVerificationStream(String userId) {
    return _service.getUserVerificationStream(userId);
  }

  // 실시간 인증 상태 업데이트
  void updateUserVerification(UniversityVerificationModel? verification) {
    _userVerification = verification;
    notifyListeners();
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }

  // 상태 초기화
  void reset() {
    _userVerification = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
} 