import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/models/rating_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Auth
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // User methods
  Future<UserModel?> getCurrentUser() async {
    if (currentUser == null) return null;
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toFirestore());
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      throw e;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toFirestore());
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw e;
    }
  }

  // Tournament methods
  Future<List<TournamentModel>> getTournaments({
    int? limit,
    DocumentSnapshot? startAfter,
    DateTime? startDate,
    DateTime? endDate,
    TournamentType? tournamentType,
    int? ovrLimit,
  }) async {
    try {
      Query query = _firestore
          .collection('tournaments')
          .orderBy('startsAt', descending: false)
          .where('status', isEqualTo: TournamentStatus.open.index);

      if (startDate != null) {
        query = query.where(
          'startsAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'startsAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      if (tournamentType != null) {
        query = query.where('tournamentType', isEqualTo: tournamentType.index);
      }

      if (ovrLimit != null) {
        query = query.where('ovrLimit', isLessThanOrEqualTo: ovrLimit);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => TournamentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting tournaments: $e');
      return [];
    }
  }

  Future<TournamentModel?> getTournament(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('tournaments').doc(id).get();
      if (doc.exists) {
        return TournamentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tournament: $e');
      return null;
    }
  }

  Future<String> createTournament(TournamentModel tournament) async {
    try {
      DocumentReference ref =
          await _firestore.collection('tournaments').add(tournament.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('Error creating tournament: $e');
      throw e;
    }
  }

  Future<void> updateTournament(TournamentModel tournament) async {
    try {
      await _firestore
          .collection('tournaments')
          .doc(tournament.id)
          .update(tournament.toFirestore());
    } catch (e) {
      debugPrint('Error updating tournament: $e');
      throw e;
    }
  }

  // Application methods
  Future<String> applyToTournament(ApplicationModel application) async {
    try {
      DocumentReference ref =
          await _firestore.collection('applications').add(application.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('Error applying to tournament: $e');
      throw e;
    }
  }

  Future<List<ApplicationModel>> getTournamentApplications(String tournamentId) async {
    try {
      final snapshot = await _firestore
          .collection('applications')
          .where('tournamentId', isEqualTo: tournamentId)
          .get();
      return snapshot.docs
          .map((doc) => ApplicationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting tournament applications: $e');
      return [];
    }
  }

  Future<void> updateApplicationStatus(String id, ApplicationStatus status) async {
    try {
      await _firestore
          .collection('applications')
          .doc(id)
          .update({'status': status.index});
    } catch (e) {
      debugPrint('Error updating application status: $e');
      throw e;
    }
  }

  // Mercenary methods
  Future<List<MercenaryModel>> getAvailableMercenaries({
    int? limit,
    DocumentSnapshot? startAfter,
    List<String>? positions,
    int? minOvr,
  }) async {
    try {
      Query query = _firestore
          .collection('mercenaries')
          .where('isAvailable', isEqualTo: true)
          .orderBy('lastActiveAt', descending: true);

      if (positions != null && positions.isNotEmpty) {
        query = query.where('preferredPositions', arrayContainsAny: positions);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      List<MercenaryModel> mercenaries = snapshot.docs
          .map((doc) => MercenaryModel.fromFirestore(doc))
          .toList();

      // Filter by minOvr if provided (this can't be done in the query)
      if (minOvr != null) {
        mercenaries =
            mercenaries.where((m) => m.averageRoleStat >= minOvr).toList();
      }

      return mercenaries;
    } catch (e) {
      debugPrint('Error getting mercenaries: $e');
      return [];
    }
  }

  Future<String> createMercenaryProfile(MercenaryModel mercenary) async {
    try {
      DocumentReference ref =
          await _firestore.collection('mercenaries').add(mercenary.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('Error creating mercenary profile: $e');
      throw e;
    }
  }

  Future<void> updateMercenaryProfile(MercenaryModel mercenary) async {
    try {
      await _firestore
          .collection('mercenaries')
          .doc(mercenary.id)
          .update(mercenary.toFirestore());
    } catch (e) {
      debugPrint('Error updating mercenary profile: $e');
      throw e;
    }
  }

  Future<MercenaryModel?> getMercenary(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('mercenaries').doc(id).get();
      if (doc.exists) {
        return MercenaryModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting mercenary: $e');
      return null;
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  // Rating methods
  Future<String> rateUser(RatingModel rating) async {
    try {
      DocumentReference ref =
          await _firestore.collection('ratings').add(rating.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('Error rating user: $e');
      throw e;
    }
  }

  Future<List<RatingModel>> getUserRatings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('targetId', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return RatingModel.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting user ratings: $e');
      return [];
    }
  }

  // Chat methods
  Future<String> createChatRoom(ChatRoomModel chatRoom) async {
    try {
      debugPrint('=== 채팅방 생성 메서드 호출 ===');
      debugPrint('채팅방 제목: ${chatRoom.title}');
      debugPrint('참가자 목록: ${chatRoom.participantIds.join(', ')}');
      debugPrint('채팅방 타입: ${chatRoom.type}');
      debugPrint('연결된 토너먼트 ID: ${chatRoom.tournamentId}');
      
      // Firestore에 채팅방 문서 생성
      debugPrint('Firestore에 채팅방 문서 생성 시작...');
      final docRef = await _firestore.collection('chatRooms').add(chatRoom.toFirestore());
      debugPrint('채팅방 문서 생성 완료, ID: ${docRef.id}');
      
      // 생성된 ID로 채팅방 모델 업데이트
      final updatedChatRoom = chatRoom.copyWith(id: docRef.id);
      
      // ID가 포함된 데이터로 문서 업데이트
      debugPrint('채팅방 ID 업데이트 시작...');
      await docRef.update(updatedChatRoom.toFirestore());
      debugPrint('채팅방 ID 업데이트 완료');
      
      debugPrint('=== 채팅방 생성 완료: ${docRef.id} ===');
      return docRef.id;
    } catch (e) {
      debugPrint('!!! 채팅방 생성 실패: $e !!!');
      throw Exception('채팅방 생성 실패: $e');
    }
  }

  Future<List<ChatRoomModel>> getUserChatRooms(String userId) async {
    try {
      debugPrint('Fetching chat rooms for user: $userId');
      
      final snapshot = await _firestore
          .collection('chatRooms')
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();
      
      debugPrint('Found ${snapshot.docs.length} chat rooms for user $userId');
      
      // 결과 검증 및 변환
      List<ChatRoomModel> chatRooms = [];
      for (var doc in snapshot.docs) {
        try {
          final room = ChatRoomModel.fromFirestore(doc);
          
          // ChatRoomType 검증
          if (room.type == ChatRoomType.tournamentRecruitment) {
            debugPrint('Found tournament chat room: ${doc.id}, title: ${room.title}');
          }
          
          chatRooms.add(room);
        } catch (e) {
          debugPrint('Error converting chat room doc: $e');
        }
      }
      
      return chatRooms;
    } catch (e) {
      debugPrint('Error getting user chat rooms: $e');
      return [];
    }
  }

  Future<String> sendMessage(MessageModel message) async {
    try {
      // Firestore에 메시지 저장
      final docRef = await _firestore.collection('messages').add(message.toFirestore());
      
      // 채팅방 마지막 메시지 정보 업데이트
      await _firestore.collection('chatRooms').doc(message.chatRoomId).update({
        'lastMessageText': message.text,
        'lastMessageTime': message.timestamp,
      });
      
      // 채팅방 참가자들의 읽지 않은 메시지 수 업데이트
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(message.chatRoomId).get();
      if (chatRoomDoc.exists) {
        final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
        
        // 읽지 않은 메시지 카운트 업데이트
        Map<String, int> updatedUnreadCount = Map<String, int>.from(chatRoom.unreadCount);
        for (String participantId in chatRoom.participantIds) {
          // 메시지 발신자는 읽음 처리
          if (participantId != message.senderId) {
            updatedUnreadCount[participantId] = (updatedUnreadCount[participantId] ?? 0) + 1;
          }
        }
        
        // 채팅방 읽지 않은 메시지 수 업데이트
        await _firestore.collection('chatRooms').doc(message.chatRoomId).update({
          'unreadCount': updatedUnreadCount
        });
      }
      
      debugPrint('Message sent successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception('메시지 전송 실패: $e');
    }
  }

  Stream<List<MessageModel>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  // Storage methods
  Future<String> uploadImage(String path, Uint8List bytes) async {
    try {
      // Handle web vs mobile differently if needed
      final ref = _storage.ref().child(path);

      if (kIsWeb) {
        // Web specific upload
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
        );
        await ref.putData(bytes, metadata);
      } else {
        // Mobile upload
        await ref.putData(bytes);
      }

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw e;
    }
  }

  // Generic methods to fetch document by ID with proper typing
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocumentById(
      String collection, String id) async {
    return await _firestore.collection(collection).doc(id).get();
  }

  // Renamed method for raw Firestore data
  Future<List<Map<String, dynamic>>> fetchRawTournamentDocs() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('tournaments').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Example method for fetching a user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;

    final data = doc.data();
    return data;
  }

  // Example method to calculate average rating
  Future<double> calculateAverageRating(String userId) async {
    final ratings = await getUserRatings(userId);
    if (ratings.isEmpty) return 0.0;

    final totalStars = ratings.fold<int>(0, (sum, rating) => sum + rating.stars);
    return totalStars / ratings.length;
  }

  // Example of a storage upload method
  Future<String> uploadFile(String path, Uint8List bytes) async {
    final ref = _storage.ref().child(path);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  // Example of working with timestamps
  DateTime? convertTimestampToDateTime(Timestamp? timestamp) {
    return timestamp?.toDate();
  }

  String formatLastMessageTime(DateTime dateTime) {
    // Implementation of formatting logic
    return dateTime.toString();
  }

  // Fetch top users for rankings
  Future<List<UserModel>> fetchTopUsers({int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('averageRating', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top users: $e');
      return [];
    }
  }
  
  // Tournament participation methods - delegating to transaction-safe operations
  Future<void> joinTournamentByRole(String tournamentId, String role) async {
    try {
      // Method to join a tournament with a specific role (top, jungle, mid, etc.)
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('로그인이 필요합니다.');
      
      await _firestore.runTransaction((transaction) async {
        // Get the tournament document
        final docRef = _firestore.collection('tournaments').doc(tournamentId);
        final docSnapshot = await transaction.get(docRef);
        
        if (!docSnapshot.exists) {
          throw Exception('토너먼트를 찾을 수 없습니다.');
        }
        
        // Convert to tournament model
        final tournament = TournamentModel.fromFirestore(docSnapshot);
        
        // Check if already a participant
        if (tournament.participants.contains(userId)) {
          throw Exception('이미 참가 중인 토너먼트입니다.');
        }
        
        // Check if can join the role
        if (!tournament.canJoinRole(role)) {
          throw Exception('해당 포지션은 이미 가득 찼거나 참가할 수 없습니다.');
        }
        
        // Get user information
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          throw Exception('사용자 정보를 찾을 수 없습니다.');
        }
        
        // Check credits for competitive tournaments
        if (tournament.tournamentType == TournamentType.competitive) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userCredits = userData['credits'] as int? ?? 0;
          const requiredCredits = 20; // 항상 고정 20 크레딧
          
          if (userCredits < requiredCredits) {
            throw Exception('크레딧이 부족합니다. 필요 크레딧: $requiredCredits, 보유 크레딧: $userCredits');
          }
          
          // Deduct credits
          transaction.update(_firestore.collection('users').doc(userId), {
            'credits': userCredits - requiredCredits
          });
        }
        
        // Update participants list
        final updatedParticipants = List<String>.from(tournament.participants)..add(userId);
        
        // Update participants by role
        final updatedParticipantsByRole = Map<String, List<String>>.from(tournament.participantsByRole);
        if (updatedParticipantsByRole[role] == null) {
          updatedParticipantsByRole[role] = [];
        }
        updatedParticipantsByRole[role]!.add(userId);
        
        // Update filled slots by role
        final updatedFilledSlotsByRole = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] = (updatedFilledSlotsByRole[role] ?? 0) + 1;
        
        // Update overall filled slots
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        if (role == 'top' || role == 'jungle' || role == 'mid') {
          updatedFilledSlots['team1'] = (updatedFilledSlots['team1'] ?? 0) + 1;
        } else {
          updatedFilledSlots['team2'] = (updatedFilledSlots['team2'] ?? 0) + 1;
        }
        
        // Check if tournament will be full after joining
        TournamentStatus updatedStatus = tournament.status;
        var willBeFull = true;
        for (final entry in tournament.slotsByRole.entries) {
          final roleKey = entry.key;
          final totalSlots = entry.value;
          final filledSlots = (updatedFilledSlotsByRole[roleKey] ?? 0);
          if (filledSlots < totalSlots) {
            willBeFull = false;
            break;
          }
        }
        
        if (willBeFull) {
          updatedStatus = TournamentStatus.full;
        }
        
        // Update tournament document with a simple map to avoid any potential issues
        transaction.update(docRef, {
          'participants': updatedParticipants,
          'participantsByRole': updatedParticipantsByRole,
          'filledSlotsByRole': updatedFilledSlotsByRole,
          'filledSlots': updatedFilledSlots,
          'status': updatedStatus.index,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      debugPrint('Error joining tournament: $e');
      rethrow;
    }
  }
  
  Future<void> leaveTournamentByRole(String tournamentId, String role) async {
    try {
      // Method to leave a tournament with a specific role
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('로그인이 필요합니다.');
      
      await _firestore.runTransaction((transaction) async {
        // Get the tournament document
        final docRef = _firestore.collection('tournaments').doc(tournamentId);
        final docSnapshot = await transaction.get(docRef);
        
        if (!docSnapshot.exists) {
          throw Exception('토너먼트를 찾을 수 없습니다.');
        }
        
        // Convert to tournament model
        final tournament = TournamentModel.fromFirestore(docSnapshot);
        
        // Check if user is a participant
        if (!tournament.participants.contains(userId)) {
          throw Exception('참가하지 않은 토너먼트입니다.');
        }
        
        // Check if user is in the specified role
        final roleParticipants = tournament.participantsByRole[role] ?? [];
        if (!roleParticipants.contains(userId)) {
          throw Exception('해당 역할로 참가하지 않았습니다.');
        }
        
        // Update filled slots by role
        final updatedFilledSlotsByRole = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] = (updatedFilledSlotsByRole[role] ?? 1) - 1;
        if (updatedFilledSlotsByRole[role]! < 0) updatedFilledSlotsByRole[role] = 0;
        
        // Update overall filled slots (team1, team2) based on role
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        if (role == 'top' || role == 'jungle' || role == 'mid') {
          updatedFilledSlots['team1'] = (updatedFilledSlots['team1'] ?? 1) - 1;
          if (updatedFilledSlots['team1']! < 0) updatedFilledSlots['team1'] = 0;
        } else {
          updatedFilledSlots['team2'] = (updatedFilledSlots['team2'] ?? 1) - 1;
          if (updatedFilledSlots['team2']! < 0) updatedFilledSlots['team2'] = 0;
        }
        
        final updatedParticipants = List<String>.from(tournament.participants)..remove(userId);
        
        // Update participants by role
        final updatedParticipantsByRole = Map<String, List<String>>.from(tournament.participantsByRole);
        updatedParticipantsByRole[role] = roleParticipants.where((id) => id != userId).toList();
        
        // Update status if needed
        TournamentStatus updatedStatus = tournament.status;
        if (tournament.status == TournamentStatus.full) {
          updatedStatus = TournamentStatus.open;
        }
        
        // Update tournament document
        transaction.update(docRef, {
          'filledSlots': updatedFilledSlots,
          'filledSlotsByRole': updatedFilledSlotsByRole,
          'participants': updatedParticipants,
          'participantsByRole': updatedParticipantsByRole,
          'status': updatedStatus.index,
          'updatedAt': Timestamp.now(),
        });
        
        // Find and update application status to cancelled
        final applicationQuery = await _firestore.collection('applications')
            .where('tournamentId', isEqualTo: tournamentId)
            .where('userUid', isEqualTo: userId)
            .where('role', isEqualTo: role)
            .limit(1)
            .get();
            
        if (applicationQuery.docs.isNotEmpty) {
          final applicationDoc = applicationQuery.docs.first;
          transaction.update(
            _firestore.collection('applications').doc(applicationDoc.id), 
            {'status': ApplicationStatus.cancelled.index}
          );
        }
        
        // Refund credits for competitive tournaments
        if (tournament.tournamentType == TournamentType.competitive) {
          // Get user information to check current credits
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final currentCredits = userData['credits'] as int? ?? 0;
            const refundCredits = 20; // Same as required credits
            
            // Add refund to user's credits
            transaction.update(_firestore.collection('users').doc(userId), {
              'credits': currentCredits + refundCredits
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error leaving tournament: $e');
      rethrow;
    }
  }
  
  // Credit management methods
  Future<void> addCredits(String userId, int amount) async {
    try {
      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final currentCredits = userData['credits'] as int? ?? 0;
      
      // Add credits
      await _firestore.collection('users').doc(userId).update({
        'credits': currentCredits + amount
      });
    } catch (e) {
      debugPrint('Error adding credits: $e');
      rethrow;
    }
  }
  
  Future<int> getUserCredits() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('로그인이 필요합니다.');
      }
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['credits'] as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting user credits: $e');
      rethrow;
    }
  }

  // 내전 ID로 채팅방 찾기
  Future<String?> findChatRoomByTournamentId(String tournamentId) async {
    try {
      debugPrint('=== 토너먼트 ID로 채팅방 찾기: $tournamentId ===');
      
      debugPrint('Firestore 쿼리 실행 중...');
      final querySnapshot = await _firestore
          .collection('chatRooms')
          .where('tournamentId', isEqualTo: tournamentId)
          .limit(1)
          .get();
      
      debugPrint('쿼리 결과: ${querySnapshot.docs.length}개의 문서 찾음');
      
      if (querySnapshot.docs.isNotEmpty) {
        final chatRoomId = querySnapshot.docs.first.id;
        debugPrint('채팅방 찾음: $chatRoomId');
        return chatRoomId;
      }
      
      debugPrint('해당 토너먼트의 채팅방을 찾을 수 없음');
      return null;
    } catch (e) {
      debugPrint('!!! 토너먼트 ID로 채팅방 찾기 오류: $e !!!');
      return null;
    }
  }
  
  // 채팅방에 참가자 추가
  Future<void> addParticipantToChatRoom(
      String chatRoomId,
      String userId,
      String userName,
      String? userProfileImageUrl) async {
    try {
      // 채팅방 정보 가져오기
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        debugPrint('Chat room $chatRoomId does not exist');
        return;
      }
      
      // 채팅방 모델로 변환
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      
      // 이미 참가자인지 확인
      if (chatRoom.participantIds.contains(userId)) {
        debugPrint('User $userId is already a participant in chat room $chatRoomId');
        return;
      }
      
      // 참가자 목록, 이름, 프로필 이미지, 읽지 않은 메시지 수 업데이트
      final updatedParticipantIds = List<String>.from(chatRoom.participantIds)..add(userId);
      final updatedParticipantNames = Map<String, String>.from(chatRoom.participantNames)..addAll({userId: userName});
      final updatedParticipantProfileImages = Map<String, String?>.from(chatRoom.participantProfileImages)..addAll({userId: userProfileImageUrl});
      final updatedUnreadCount = Map<String, int>.from(chatRoom.unreadCount)..addAll({userId: 0});
      
      // 채팅방 업데이트
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'participantIds': updatedParticipantIds,
        'participantNames': updatedParticipantNames,
        'participantProfileImages': updatedParticipantProfileImages,
        'unreadCount': updatedUnreadCount,
      });
      
      debugPrint('Added user $userId to chat room $chatRoomId');
    } catch (e) {
      debugPrint('Error adding participant to chat room: $e');
      throw e;
    }
  }
  
  // 채팅방과 내전 연결
  Future<void> linkChatRoomToTournament(String chatRoomId, String tournamentId) async {
    try {
      debugPrint('Linking chat room $chatRoomId to tournament $tournamentId');
      
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
            'tournamentId': tournamentId,
            'type': ChatRoomType.tournamentRecruitment.index,
          });
      
      // 업데이트 후 검증
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (chatRoomDoc.exists) {
        final data = chatRoomDoc.data() as Map<String, dynamic>;
        debugPrint('Chat room after linking - tournamentId: ${data['tournamentId']}, type: ${data['type']}');
      }
    } catch (e) {
      debugPrint('Error linking chat room to tournament: $e');
      throw Exception('채팅방과 내전을 연결하는 중 오류가 발생했습니다: $e');
    }
  }

  // 단일 토너먼트 삭제
  Future<void> deleteTournament(String tournamentId) async {
    try {
      // 권한 문제 해결을 위해 트랜잭션 대신 일반 삭제 방식 사용
      // 토너먼트 문서 삭제
      await _firestore.collection('tournaments').doc(tournamentId).delete();
      
      // 관련 신청서 조회
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('tournamentId', isEqualTo: tournamentId)
          .get();
          
      // 관련 신청서 삭제
      for (final doc in applicationsSnapshot.docs) {
        await _firestore.collection('applications').doc(doc.id).delete();
      }
      
      debugPrint('Tournament $tournamentId successfully deleted');
    } catch (e) {
      debugPrint('Error deleting tournament: $e');
      rethrow;
    }
  }

  // 토너먼트 일괄 삭제 기능
  Future<int> deleteAllTournaments() async {
    try {
      // 먼저 삭제할 토너먼트 목록 조회
      final QuerySnapshot snapshot = await _firestore.collection('tournaments').get();
      
      int count = 0;
      
      // 각 토너먼트 문서 삭제
      for (final doc in snapshot.docs) {
        await _firestore.collection('tournaments').doc(doc.id).delete();
        count++;
      }
      
      debugPrint('Deleted $count tournaments');
      return count;
    } catch (e) {
      debugPrint('Error deleting all tournaments: $e');
      rethrow;
    }
  }
}
