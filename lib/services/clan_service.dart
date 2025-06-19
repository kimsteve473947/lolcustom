import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/clan_recruitment_post_model.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lol_custom_game_manager/models/clan_application_model.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

class ClanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection reference
  CollectionReference get _clansCollection => _firestore.collection('clans');
  CollectionReference get _recruitmentPostsCollection => _firestore.collection('clan_recruitment_posts');
  
  // --- Clan Recruitment ---

  Stream<List<ClanRecruitmentPostModel>> getRecruitmentPostsStream({String? filter}) {
    Query query = _recruitmentPostsCollection
        .where('isRecruiting', isEqualTo: true);
    
    // 필터가 있으면 해당 팀 특징을 가진 포스트만 조회
    if (filter != null && filter.isNotEmpty) {
      query = query.where('teamFeatures', arrayContains: filter);
    }
    
    // 임시로 orderBy 제거 (인덱스 문제 우회)
    return query
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) => ClanRecruitmentPostModel.fromFirestore(doc)).toList();
      // 메모리에서 정렬
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Stream<List<ClanRecruitmentPostModel>> getRecruitmentPostsByClansStream(String clanId) {
    return _recruitmentPostsCollection
        .where('clanId', isEqualTo: clanId)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) => ClanRecruitmentPostModel.fromFirestore(doc)).toList();
      // 메모리에서 정렬
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Future<void> publishRecruitmentPost(ClanRecruitmentPostModel post) async {
    try {
      await _recruitmentPostsCollection.add(post.toFirestore());
    } catch (e) {
      debugPrint('Error publishing recruitment post: $e');
      rethrow;
    }
  }

  Future<ClanRecruitmentPostModel?> getExistingRecruitmentPost(String clanId) async {
    try {
      final snapshot = await _recruitmentPostsCollection
          .where('clanId', isEqualTo: clanId)
          .where('isRecruiting', isEqualTo: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return ClanRecruitmentPostModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting existing recruitment post: $e');
      return null;
    }
  }

  Future<void> updateRecruitmentPost(String postId, Map<String, dynamic> updates) async {
    try {
      await _recruitmentPostsCollection.doc(postId).update(updates);
    } catch (e) {
      debugPrint('Error updating recruitment post: $e');
      rethrow;
    }
  }

  // --- Clan Management ---
  
  // Create a new clan
  Future<String> createClan(
    String name,
    String userId,
    String ownerName, {
    String? description,
    dynamic emblem,
    List<String>? activityDays,
    List<PlayTimeType>? activityTimes,
    List<AgeGroup>? ageGroups,
    GenderPreference? genderPreference,
    ClanFocus? focus,
    int? focusRating,
    String? discordUrl,
    bool? areMembersPublic,
    bool? isRecruiting,
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
      ownerName: ownerName,
      emblem: processedEmblem,
      activityDays: activityDays ?? [],
      activityTimes: activityTimes ?? [],
      ageGroups: ageGroups ?? [],
      genderPreference: genderPreference ?? GenderPreference.any,
      focus: focus ?? ClanFocus.balanced,
      focusRating: focusRating ?? 5,
      discordUrl: discordUrl,
      createdAt: Timestamp.now(),
      // maxMembers는 ClanModel의 기본값을 따르도록 제거
      members: [userId],
      areMembersPublic: areMembersPublic ?? true,
      isRecruiting: isRecruiting ?? true,
      level: 1,
      xp: 0,
      xpToNextLevel: 100,
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
      
      return ClanModel.fromFirestore(doc);
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
        .map((doc) => ClanModel.fromFirestore(doc))
        .toList();
  }
  
  // Get clans that are recruiting new members
  Future<List<ClanModel>> getRecruitingClans({int limit = 10}) async {
    final querySnapshot = await _clansCollection
        .where('isRecruiting', isEqualTo: true)
        .where('areMembersPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    
    return querySnapshot.docs.map((doc) => ClanModel.fromFirestore(doc)).toList();
  }
  
  // Apply to join a clan
  Future<void> applyToClan(String clanId, String userId) async {
    try {
      debugPrint('레거시 applyToClan 호출, 새 메서드로 전환: $clanId, $userId');
      await applyClanWithDetails(
        clanId: clanId,
        message: '가입 신청합니다.',
      );
    } catch (e) {
      debugPrint('레거시 applyToClan 오류: $e');
      rethrow;
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
      
      final clanModel = ClanModel.fromFirestore(clanDoc);
      final List<String> pendingMembers = clanModel.pendingMembers;
      final int maxMembers = clanModel.maxMembers;
      
      // 대기 중인 멤버 리스트에 해당 사용자가 있는지 확인
      if (!pendingMembers.contains(userId)) {
        throw Exception('가입 신청 내역이 없습니다');
      }
      
      // 멤버 수 제한 확인
      if (clanModel.memberCount >= maxMembers) {
        throw Exception('클랜이 가득 찼습니다');
      }
      
      // 클랜 정보 업데이트
      transaction.update(clanDocRef, {
        'members': FieldValue.arrayUnion([userId]),
        'pendingMembers': FieldValue.arrayRemove([userId]),
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
          'clanName': clanModel.name,
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
        'clanName': (clanDoc.data() as Map<String, dynamic>)['name'],
      },
      'read': false,
      'createdAt': Timestamp.now(),
    });
  }
  
  // Remove a member from clan
  Future<void> removeMember(String clanId, String userId) async {
    await _clansCollection.doc(clanId).update({
      'members': FieldValue.arrayRemove([userId]),
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
    
    return querySnapshot.docs.map((doc) => ClanModel.fromFirestore(doc)).toList();
  }
  
  // 특정 나이대의 클랜 검색
  Future<List<ClanModel>> searchClansByAgeGroup(List<AgeGroup> ageGroups, {int limit = 10}) async {
    // 각 나이대 그룹의 인덱스 얻기
    final List<int> ageGroupIndices = ageGroups.map((ag) => ag.index).toList();
    
    final querySnapshot = await _clansCollection
        .where('ageGroups', arrayContainsAny: ageGroupIndices)
        .limit(limit)
        .get();
    
    return querySnapshot.docs.map((doc) => ClanModel.fromFirestore(doc)).toList();
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
    
    return querySnapshot.docs.map((doc) => ClanModel.fromFirestore(doc)).toList();
  }

  // 모든 클랜 가져오기
  Stream<List<ClanModel>> getClans({bool onlyRecruiting = false}) {
    Query query = _firestore.collection('clans');
    
    if (onlyRecruiting) {
      query = query.where('isRecruiting', isEqualTo: true);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ClanModel.fromFirestore(doc)).toList();
    });
  }

  // 특정 클랜 가져오기
  Future<ClanModel?> getClan(String clanId) async {
    try {
      final doc = await _firestore.collection('clans').doc(clanId).get();
      if (doc.exists) {
        return ClanModel.fromFirestore(doc);
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
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      debugPrint('클랜 가입 신청 시작: $clanId, 유저: ${user.uid}');

      // 클랜이 존재하는지 확인
      final clanDoc = await _firestore.collection('clans').doc(clanId).get();
      if (!clanDoc.exists) {
        debugPrint('클랜이 존재하지 않음: $clanId');
        throw Exception('존재하지 않는 클랜입니다.');
      }

      // 이미 클랜에 속해있는지 확인
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['clanId'] != null) {
          debugPrint('이미 클랜에 소속됨: ${userData['clanId']}');
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
        debugPrint('이미 신청함: ${existingApplications.docs.first.id}');
        throw Exception('이미 해당 클랜에 가입 신청을 하셨습니다.');
      }

      debugPrint('신청서 생성 중...');
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
      final docRef = await _firestore.collection('clan_applications').add(application.toFirestore());
      debugPrint('신청서 저장 완료: ${docRef.id}');

      // 클랜의 pendingMembers 배열에 사용자 ID 추가
      await _firestore.collection('clans').doc(clanId).update({
        'pendingMembers': FieldValue.arrayUnion([user.uid]),
      });
      debugPrint('pendingMembers 업데이트 완료');

      // 알림 생성 - 클랜 소유자에게 알림
      final clan = ClanModel.fromFirestore(clanDoc);
      await _firestore.collection('notifications').add({
        'userId': clan.ownerId,
        'type': 'clan_application',
        'title': '새로운 클랜 가입 신청',
        'message': '${user.displayName ?? "사용자"}님이 클랜 가입을 신청했습니다.',
        'data': {
          'clanId': clanId,
          'clanName': clan.name,
          'applicationId': docRef.id,
          'applicantId': user.uid,
          'applicantName': user.displayName,
        },
        'read': false,
        'createdAt': Timestamp.now(),
      });
      debugPrint('알림 생성 완료');

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
      
      final clan = ClanModel.fromFirestore(clanDoc);
      
      // 멤버 정보 가져오기
      final members = <Map<String, dynamic>>[];
      
      for (final memberId in clan.members) {
        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        if (memberDoc.exists) {
          final data = memberDoc.data();
          if (data != null) {
            members.add({
              'uid': memberId,
              'displayName': memberId == clan.ownerId ? clan.ownerName : (data['nickname'] ?? '이름 없음'),
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

  // 모든 유저의 클랜 정보 초기화 (일회성 사용)
  Future<void> removeAllClanDataFromUsers() async {
    final usersSnapshot = await _firestore.collection('users').get();
    
    final WriteBatch batch = _firestore.batch();
    
    for (final doc in usersSnapshot.docs) {
      batch.update(doc.reference, {
        'clanId': FieldValue.delete(),
        'isOwnerOfClan': FieldValue.delete(),
      });
    }
    
    await batch.commit();
    debugPrint('모든 유저의 클랜 정보가 초기화되었습니다.');
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

  // 클랜 가입 신청 취소
  Future<void> cancelClanApplication(String applicationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final applicationRef = _firestore.collection('clan_applications').doc(applicationId);

    return _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);
      if (!applicationDoc.exists) {
        throw Exception('존재하지 않는 신청서입니다.');
      }

      final applicationData = applicationDoc.data() as Map<String, dynamic>;
      if (applicationData['userUid'] != user.uid) {
        throw Exception('신청을 취소할 권한이 없습니다.');
      }

      // 신청서 삭제
      transaction.delete(applicationRef);

      // 클랜의 pendingMembers에서 사용자 제거
      final clanId = applicationData['clanId'];
      if (clanId != null) {
        final clanRef = _firestore.collection('clans').doc(clanId);
        transaction.update(clanRef, {
          'pendingMembers': FieldValue.arrayRemove([user.uid])
        });
      }
    });
  }

  // 클랜 평균 티어 계산
  Future<String> getAverageTier(String clanId) async {
    try {
      final clanDoc = await _clansCollection.doc(clanId).get();
      if (!clanDoc.exists) return '정보 없음';

      final clan = ClanModel.fromFirestore(clanDoc);
      if (clan.members.isEmpty) return 'Unranked';

      double totalScore = 0;
      int memberWithTierCount = 0;

      for (final memberId in clan.members) {
        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        if (memberDoc.exists && memberDoc.data()!.containsKey('tier')) {
          final tierString = memberDoc.data()!['tier'] as String;
          final parts = tierString.split(' ');
          if (parts.length == 2) {
            final tierName = parts[0];
            final tierRank = int.tryParse(parts[1]);
            if (LolTiers.scores.containsKey(tierName) && tierRank != null) {
              totalScore += (LolTiers.scores[tierName]! + (4 - tierRank));
              memberWithTierCount++;
            }
          }
        }
      }

      if (memberWithTierCount == 0) return 'Unranked';

      final averageScore = totalScore / memberWithTierCount;
      final averageTierName = LolTiers.getTierFromScore(averageScore);
      
      return LolTiers.kr[averageTierName] ?? averageTierName;

    } catch (e) {
      debugPrint('Error getting average tier: $e');
      return '정보 없음';
    }
  }

  // 사용자를 클랜에 초대
  Future<void> inviteUserToClan(String clanId, String userIdToInvite, String inviterName) async {
    final clanDoc = await _clansCollection.doc(clanId).get();
    if (!clanDoc.exists) {
      throw Exception('존재하지 않는 클랜입니다.');
    }

    final userDoc = await _firestore.collection('users').doc(userIdToInvite).get();
    if (!userDoc.exists) {
      throw Exception('존재하지 않는 사용자입니다.');
    }
    final userToInvite = UserModel.fromFirestore(userDoc);

    if (userToInvite.clanId != null && userToInvite.clanId!.isNotEmpty) {
      throw Exception('이미 다른 클랜에 소속된 사용자입니다.');
    }

    // 초대 알림 생성
    await _firestore.collection('notifications').add({
      'userId': userIdToInvite,
      'type': 'clan_invitation',
      'title': '클랜 초대',
      'message': '$inviterName 님이 당신을 ${(clanDoc.data() as Map<String, dynamic>)['name']} 클랜에 초대했습니다.',
      'data': {
        'clanId': clanId,
        'clanName': (clanDoc.data() as Map<String, dynamic>)['name'],
        'inviterName': inviterName,
      },
      'read': false,
      'createdAt': Timestamp.now(),
    });
  }
}