import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum VerificationStatus {
  pending,    // 검토 중
  approved,   // 승인됨
  rejected,   // 거부됨
}

enum DocumentType {
  studentId,     // 학생증
  libraryCard,   // 도서관카드
  enrollmentCert, // 재학증명서
}

class UniversityVerificationModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String universityName;
  final String studentId;  // 학번
  final String major;      // 전공
  final DocumentType documentType;
  final String imageUrl;   // 업로드된 증명서 이미지 URL
  final VerificationStatus status;
  final String? rejectionReason;  // 거부 시 이유
  final String? verifiedBy;       // 승인한 관리자 ID
  final Timestamp createdAt;
  final Timestamp? verifiedAt;    // 승인/거부 일시

  const UniversityVerificationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.universityName,
    required this.studentId,
    required this.major,
    required this.documentType,
    required this.imageUrl,
    this.status = VerificationStatus.pending,
    this.rejectionReason,
    this.verifiedBy,
    required this.createdAt,
    this.verifiedAt,
  });

  UniversityVerificationModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? universityName,
    String? studentId,
    String? major,
    DocumentType? documentType,
    String? imageUrl,
    VerificationStatus? status,
    String? rejectionReason,
    String? verifiedBy,
    Timestamp? createdAt,
    Timestamp? verifiedAt,
  }) {
    return UniversityVerificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      universityName: universityName ?? this.universityName,
      studentId: studentId ?? this.studentId,
      major: major ?? this.major,
      documentType: documentType ?? this.documentType,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      createdAt: createdAt ?? this.createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'universityName': universityName,
      'studentId': studentId,
      'major': major,
      'documentType': documentType.index,
      'imageUrl': imageUrl,
      'status': status.index,
      'rejectionReason': rejectionReason,
      'verifiedBy': verifiedBy,
      'createdAt': createdAt,
      'verifiedAt': verifiedAt,
    };
  }

  factory UniversityVerificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UniversityVerificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      universityName: data['universityName'] ?? '',
      studentId: data['studentId'] ?? '',
      major: data['major'] ?? '',
      documentType: DocumentType.values[data['documentType'] ?? 0],
      imageUrl: data['imageUrl'] ?? '',
      status: VerificationStatus.values[data['status'] ?? 0],
      rejectionReason: data['rejectionReason'],
      verifiedBy: data['verifiedBy'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      verifiedAt: data['verifiedAt'],
    );
  }

  String get statusText {
    switch (status) {
      case VerificationStatus.pending:
        return '검토 중';
      case VerificationStatus.approved:
        return '인증 완료';
      case VerificationStatus.rejected:
        return '인증 거부';
    }
  }

  String get documentTypeText {
    switch (documentType) {
      case DocumentType.studentId:
        return '학생증';
      case DocumentType.libraryCard:
        return '도서관카드';
      case DocumentType.enrollmentCert:
        return '재학증명서';
    }
  }

  @override
  List<Object?> get props => [
    id, userId, userName, universityName, studentId, major,
    documentType, imageUrl, status, rejectionReason, verifiedBy,
    createdAt, verifiedAt,
  ];
} 