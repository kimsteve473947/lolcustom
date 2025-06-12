import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lol_custom_game_manager/models/clan_application_model.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class ClanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection reference
  CollectionReference get _clansCollection => _firestore.collection('clans');
  
  // Create a new clan
  Future<String> createClan(
    String name,
    String userId, {
    String? description,
    dynamic emblem,
    List<String>? activityDays,
    List<PlayTimeType>? activityTimes,
    List<AgeGroup>? ageGroups,
    GenderPreference? genderPreference,
    ClanFocus? focus,
    int? focusRating,
    String? websiteUrl,
    bool? isPublic,
    bool? isRecruiting,
    int? memberCount,
  }) async {
    // Generate a unique clan ID
    final String clanId = _uuid.v4();
    
    // Handle emblem upload if it's a file
    dynamic processedEmblem = emblem;
    
    if (processedEmblem is File) {
      final File imageFile = processedEmblem;
      final String extension = path.extension(imageFile.path);
      final String imagePath = 'clans/$clanId/emblem_${_uuid.v4()}$extension';
      
      // Upload emblem to Firebase Storage
      final uploadTask = _storage.ref().child(imagePath).putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update emblem to download URL
      processedEmblem = downloadUrl;
    }
    
    // Create ClanModel
    final clan = ClanModel(
      id: clanId,
      name: name,
      description: description,
      ownerId: userId,
      emblem: processedEmblem,
      activityDays: activityDays ?? [],
      activityTimes: activityTimes ?? [],
      ageGroups: ageGroups ?? [],
      genderPreference: genderPreference ?? GenderPreference.any,
      focus: focus ?? ClanFocus.balanced,
      focusRating: focusRating ?? 5,
      websiteUrl: websiteUrl,
      createdAt: Timestamp.now(),
      memberCount: memberCount ?? 1,
      maxMembers: 30,
      members: [userId],
      isPublic: isPublic ?? true,
      isRecruiting: isRecruiting ?? true,
    );
    
    // Save clan to Firestore
    await _clansCollection.doc(clanId).set(clan.toMap());
    
    // Update user's clan association
    await _firestore.collection('users').doc(userId).update({
      'clanId': clanId,
      'isOwnerOfClan': true,
    });
    
    return clanId;
  }
  
  // Get clan by ID
  Future<ClanModel?> getClanById(String clanId) async {
    debugPrint('getClanById 호출: $clanId');
    try {
      final doc = await _clansCollection.doc(clanId).get();
      debugPrint('getClanById 결과: ${doc.exists ? '문서 존재' : '문서 없음'}');
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      debugPrint('클랜 데이터: ${data.toString().substring(0, min(100, data.toString().length))}...');
      
      return ClanModel.fromMap(data);
    } catch (e) {
      debugPrint('getClanById 오류: $e');
      return null;
    }
  }
  
  // Get clans where user is a member
  Future<List<ClanModel>> getUserClans(String userId) async {
    final querySnapshot = await _clansCollection
        .where('members', arrayContains: userId)
        .get();
    
    return querySnapshot.docs
        .map((doc) => ClanModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
  
  // Get clans that are recruiting new members
  Future<List<ClanModel>> getRecruitingClans({int limit = 10}) async {
    final querySnapshot = await _clansCollection
        .where('isRecruiting', isEqualTo: true)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    
    return querySnapshot.docs
        .map((doc) => ClanModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
  
  // Apply to join a clan
  Future<void> applyToClan(String clanId, String userId) async {
    // Check if the user is already a member or has a pending application
    final clanDoc = await _clansCollection.doc(clanId).get();
    if (!clanDoc.exists) {
      throw Exception('클랜이 존재하지 않습니다');
    }
    
    final clanData = clanDoc.data() as Map<String, dynamic>;
    final List<String> members = List<String>.from(clanData['members'] ?? []);
    final List<String> pendingMembers = List<String>.from(clanData['pendingMembers'] ?? []);
    
    if (members.contains(userId)) {
      throw Exception('이미 클랜의 멤버입니다');
    }
    
    if (pendingMembers.contains(userId)) {
      throw Exception('이미 가입 신청을 했습니다');
    }
    
    // Check if the clan is recruiting
    if (clanData['isRecruiting'] != true) {
      throw Exception('현재 이 클랜은 멤버를 모집하지 않습니다');
    }
    
    // Check if the clan is full
    final int memberCount = clanData['memberCount'] ?? members.length;
    final int maxMembers = clanData['maxMembers'] ?? 30;
    
    if (memberCount >= maxMembers) {
      throw Exception('클랜이 가득 찼습니다');
    }
    
    // Add user to pending members
    await _clansCollection.doc(clanId).update({
      'pendingMembers': FieldValue.arrayUnion([userId]),
    });
    
    // Create application notification for clan owner
    final ownerId = clanData['ownerId'];
    if (ownerId != null) {
      // 알림 생성 로직
      await _firestore.collection('notifications').add({
        'userId': ownerId,
        'type': 'clan_application',
        'message': '새로운 클랜 가입 신청이 있습니다',
        'data': {
          'clanId': clanId,
          'applicantId': userId,
        },
        'read': false,
        'createdAt': Timestamp.now(),
      });
    }
  }
  
  // Accept a pending member
  Future<void> acceptMember(String clanId, String userId) async {
    // 트랜잭션으로 안전하게 처리
    return _firestore.runTransaction((transaction) async {
      // 클랜 문서 가져오기
      final clanDocRef = _clansCollection.doc(clanId);
      final clanDoc = await transaction.get(clanDocRef);
      
      if (!clanDoc.exists) {
        throw Exception('클랜이 존재하지 않습니다');
      }
      
      final clanData = clanDoc.data() as Map<String, dynamic>;
      final List<String> pendingMembers = List<String>.from(clanData['pendingMembers'] ?? []);
      final int memberCount = clanData['memberCount'] ?? 0;
      final int maxMembers = clanData['maxMembers'] ?? 30;
      
      // 대기 중인 멤버 리스트에 해당 사용자가 있는지 확인
      if (!pendingMembers.contains(userId)) {
        throw Exception('가입 신청 내역이 없습니다');
      }
      
      // 멤버 수 제한 확인
      if (memberCount >= maxMembers) {
        throw Exception('클랜이 가득 찼습니다');
      }
      
      // 클랜 정보 업데이트
      transaction.update(clanDocRef, {
        'members': FieldValue.arrayUnion([userId]),
        'pendingMembers': FieldValue.arrayRemove([userId]),
        'memberCount': FieldValue.increment(1),
      });
      
      // 사용자 정보 업데이트
      final userDocRef = _firestore.collection('users').doc(userId);
      transaction.update(userDocRef, {
        'clanId': clanId,
        'isOwnerOfClan': false,
      });
      
      // 알림 생성
      final notificationRef = _firestore.collection('notifications').doc();
      transaction.set(notificationRef, {
        'userId': userId,
        'type': 'clan_application_accepted',
        'message': '클랜 가입 신청이 수락되었습니다',
        'data': {
          'clanId': clanId,
          'clanName': clanData['name'],
        },
        'read': false,
        'createdAt': Timestamp.now(),
      });
    });
  }
  
  // Reject a pending member
  Future<void> rejectMember(String clanId, String userId) async {
    // 클랜 문서 가져오기
    final clanDoc = await _clansCollection.doc(clanId).get();
    
    if (!clanDoc.exists) {
      throw Exception('클랜이 존재하지 않습니다');
    }
    
    final clanData = clanDoc.data() as Map<String, dynamic>;
    final List<String> pendingMembers = List<String>.from(clanData['pendingMembers'] ?? []);
    
    // 대기 중인 멤버 리스트에 해당 사용자가 있는지 확인
    if (!pendingMembers.contains(userId)) {
      throw Exception('가입 신청 내역이 없습니다');
    }
    
    // 클랜 정보 업데이트
    await _clansCollection.doc(clanId).update({
      'pendingMembers': FieldValue.arrayRemove([userId]),
    });
    
    // 알림 생성
    await _firestore.collection('notifications').add({
      'userId': userId,
      'type': 'clan_application_rejected',
      'message': '클랜 가입 신청이 거절되었습니다',
      'data': {
        'clanId': clanId,
        'clanName': clanData['name'],
      },
      'read': false,
      'createdAt': Timestamp.now(),
    });
  }
  
  // Remove a member from clan
  Future<void> removeMember(String clanId, String userId) async {
    await _clansCollection.doc(clanId).update({
      'members': FieldValue.arrayRemove([userId]),
      'memberCount': FieldValue.increment(-1),
    });
    
    // Update user's clan association
    await _firestore.collection('users').doc(userId).update({
      'clanId': null,
      'isOwnerOfClan': false,
    });
  }
  
  // Update clan information
  Future<void> updateClan(String clanId, Map<String, dynamic> updates) async {
    await _clansCollection.doc(clanId).update(updates);
  }
  
  // Delete a clan
  Future<void> deleteClan(String clanId) async {
    // First, get clan data to access member IDs
    final clanDoc = await _clansCollection.doc(clanId).get();
    if (!clanDoc.exists) return;
    
    final clanData = clanDoc.data() as Map<String, dynamic>;
    final List<String> memberIds = List<String>.from(clanData['members'] ?? []);
    
    // Update all members' clan associations
    for (final memberId in memberIds) {
      await _firestore.collection('users').doc(memberId).update({
        'clanId': null,
        'isOwnerOfClan': false,
      });
    }
    
    // Delete clan emblem from storage if exists
    final emblem = clanData['emblem'];
    if (emblem != null && emblem is Map && emblem['type'] == 'image' && emblem['url'] != null) {
      try {
        await _storage.refFromURL(emblem['url']).delete();
      } catch (e) {
        // Handle error or continue if the file doesn't exist
      }
    } else if (emblem != null && emblem is String && emblem.startsWith('http')) {
      try {
        await _storage.refFromURL(emblem).delete();
      } catch (e) {
        // Handle error or continue if the file doesn't exist
      }
    }
    
    // Delete clan document
    await _clansCollection.doc(clanId).delete();
  }
  
  // Search clans
  Future<List<ClanModel>> searchClans(String query, {int limit = 10}) async {
    // This is a simple implementation. For better search, consider using
    // a more advanced solution like Algolia or ElasticSearch
    final querySnapshot = await _clansCollection
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(limit)
        .get();
    
    return querySnapshot.docs
        .map((doc) => ClanModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
  
  // 특정 나이대의 클랜 검색
  Future<List<ClanModel>> searchClansByAgeGroup(List<AgeGroup> ageGroups, {int limit = 10}) async {
    // 각 나이대 그룹의 인덱스 얻기
    final List<int> ageGroupIndices = ageGroups.map((ag) => ag.index).toList();
    
    final querySnapshot = await _clansCollection
        .where('ageGroups', arrayContainsAny: ageGroupIndices)
        .limit(limit)
        .get();
    
    return querySnapshot.docs
        .map((doc) => ClanModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
  
  // 특정 성향(focus)의 클랜 검색
  Future<List<ClanModel>> searchClansByFocus(ClanFocus focus, {int minRating = 1, int maxRating = 10, int limit = 10}) async {
    final focusIndex = focus.index;
    
    final querySnapshot = await _clansCollection
        .where('focus', isEqualTo: focusIndex)
        .where('focusRating', isGreaterThanOrEqualTo: minRating)
        .where('focusRating', isLessThanOrEqualTo: maxRating)
        .limit(limit)
        .get();
    
    return querySnapshot.docs
        .map((doc) => ClanModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // 모든 클랜 가져오기
  Stream<List<ClanModel>> getClans({bool onlyRecruiting = false}) {
    Query query = _firestore.collection('clans');
    
    if (onlyRecruiting) {
      query = query.where('isRecruiting', isEqualTo: true);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClanModel.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // 특정 클랜 가져오기
  Future<ClanModel?> getClan(String clanId) async {
    try {
      final doc = await _firestore.collection('clans').doc(clanId).get();
      if (doc.exists) {
        return ClanModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting clan: $e');
      return null;
    }
  }

  // 현재 사용자의 클랜 가져오기
  Future<ClanModel?> getCurrentUserClan() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // 사용자 문서에서 clanId 필드 가져오기
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data();
      if (data == null || !data.containsKey('clanId') || data['clanId'] == null) {
        return null;
      }

      final clanId = data['clanId'] as String;
      return await getClan(clanId);
    } catch (e) {
      debugPrint('Error getting current user clan: $e');
      return null;
    }
  }

  // 사용자가 클랜장인지 확인
  Future<bool> isUserClanOwner(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
      return data != null && data['isOwnerOfClan'] == true;
    } catch (e) {
      debugPrint('Error checking if user is clan owner: $e');
      return false;
    }
  }

  // 클랜 가입 신청하기
  Future<bool> applyClanWithDetails({
    required String clanId,
    String? message,
    String? position,
    String? experience,
    String? contactInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 이미 클랜에 속해있는지 확인
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['clanId'] != null) {
          throw Exception('이미 클랜에 소속되어 있습니다.');
        }
      }

      // 이미 신청한 적이 있는지 확인
      final existingApplications = await _firestore
          .collection('clan_applications')
          .where('userUid', isEqualTo: user.uid)
          .where('clanId', isEqualTo: clanId)
          .where('status', isEqualTo: ClanApplicationStatus.pending.index)
          .get();

      if (existingApplications.docs.isNotEmpty) {
        throw Exception('이미 해당 클랜에 가입 신청을 하셨습니다.');
      }

      // 신청서 생성
      final application = ClanApplicationModel(
        id: '', // Firestore에서 자동 생성
        clanId: clanId,
        userUid: user.uid,
        userName: user.displayName ?? '이름 없음',
        userProfileImageUrl: user.photoURL,
        status: ClanApplicationStatus.pending,
        appliedAt: Timestamp.now(),
        message: message,
        position: position,
        experience: experience,
        contactInfo: contactInfo,
      );

      // Firestore에 저장
      await _firestore.collection('clan_applications').add(application.toFirestore());

      // 클랜의 pendingMembers 배열에 사용자 ID 추가
      await _firestore.collection('clans').doc(clanId).update({
        'pendingMembers': FieldValue.arrayUnion([user.uid]),
      });

      return true;
    } catch (e) {
      debugPrint('Error applying to clan: $e');
      rethrow;
    }
  }

  // 클랜 가입 신청 승인/거절하기
  Future<bool> processClanApplication({
    required String applicationId,
    required ClanApplicationStatus newStatus,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 신청서 가져오기
      final applicationDoc = await _firestore.collection('clan_applications').doc(applicationId).get();
      if (!applicationDoc.exists) {
        throw Exception('존재하지 않는 신청서입니다.');
      }

      final application = ClanApplicationModel.fromFirestore(applicationDoc);
      
      // 현재 사용자가 클랜장인지 확인
      final clan = await getClan(application.clanId);
      if (clan == null || clan.ownerId != user.uid) {
        throw Exception('클랜 신청서를 처리할 권한이 없습니다.');
      }

      // 상태 업데이트
      await _firestore.collection('clan_applications').doc(applicationId).update({
        'status': newStatus.index,
      });

      // 승인인 경우 클랜에 사용자 추가
      if (newStatus == ClanApplicationStatus.accepted) {
        // 클랜의 members 배열에 사용자 ID 추가
        await _firestore.collection('clans').doc(application.clanId).update({
          'members': FieldValue.arrayUnion([application.userUid]),
          'pendingMembers': FieldValue.arrayRemove([application.userUid]),
          'memberCount': FieldValue.increment(1),
        });

        // 사용자의 clanId 필드 업데이트
        await _firestore.collection('users').doc(application.userUid).update({
          'clanId': application.clanId,
        });
      } else if (newStatus == ClanApplicationStatus.rejected) {
        // 거절인 경우 pendingMembers에서 제거
        await _firestore.collection('clans').doc(application.clanId).update({
          'pendingMembers': FieldValue.arrayRemove([application.userUid]),
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error processing clan application: $e');
      rethrow;
    }
  }

  // 클랜의 가입 신청 목록 가져오기
  Stream<List<ClanApplicationModel>> getClanApplications(String clanId) {
    return _firestore
        .collection('clan_applications')
        .where('clanId', isEqualTo: clanId)
        .where('status', isEqualTo: ClanApplicationStatus.pending.index)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClanApplicationModel.fromFirestore(doc);
      }).toList();
    });
  }

  // 클랜의 멤버 목록 가져오기
  Future<List<Map<String, dynamic>>> getClanMembers(String clanId) async {
    try {
      final clanDoc = await _firestore.collection('clans').doc(clanId).get();
      if (!clanDoc.exists) {
        throw Exception('존재하지 않는 클랜입니다.');
      }

      final clan = ClanModel.fromMap(clanDoc.data() as Map<String, dynamic>);
      
      // 멤버 정보 가져오기
      final members = <Map<String, dynamic>>[];
      
      for (final memberId in clan.members) {
        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        if (memberDoc.exists) {
          final data = memberDoc.data();
          if (data != null) {
            members.add({
              'uid': memberId,
              'displayName': data['displayName'] ?? '이름 없음',
              'photoURL': data['photoURL'],
              'isOwner': memberId == clan.ownerId,
            });
          }
        }
      }

      return members;
    } catch (e) {
      debugPrint('Error getting clan members: $e');
      return [];
    }
  }

  // 사용자의 가입 신청 내역 가져오기
  Stream<List<ClanApplicationModel>> getUserApplications() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('clan_applications')
        .where('userUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClanApplicationModel.fromFirestore(doc);
      }).toList();
    });
  }
} 