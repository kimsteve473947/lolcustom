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
    bool? isPaid,
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

      if (isPaid != null) {
        query = query.where('isPaid', isEqualTo: isPaid);
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
      DocumentReference ref =
          await _firestore.collection('chatRooms').add(chatRoom.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('Error creating chat room: $e');
      throw e;
    }
  }

  Future<List<ChatRoomModel>> getUserChatRooms(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chatRooms')
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ChatRoomModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user chat rooms: $e');
      return [];
    }
  }

  Future<String> sendMessage(MessageModel message) async {
    try {
      // Add the message
      DocumentReference ref =
          await _firestore.collection('messages').add(message.toFirestore());

      // Update the chat room with last message
      await _firestore.collection('chatRooms').doc(message.chatRoomId).update({
        'lastMessageText': message.text,
        'lastMessageTime': message.timestamp,
      });

      return ref.id;
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw e;
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
        
        // Update fields
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 0) + 1;
        
        final updatedFilledSlotsByRole = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] = (updatedFilledSlotsByRole[role] ?? 0) + 1;
        
        final updatedParticipants = List<String>.from(tournament.participants)..add(userId);
        
        // Update participants by role
        final updatedParticipantsByRole = Map<String, List<String>>.from(tournament.participantsByRole);
        if (updatedParticipantsByRole[role] == null) {
          updatedParticipantsByRole[role] = [];
        }
        updatedParticipantsByRole[role]!.add(userId);
        
        // Check if tournament will be full after joining
        TournamentStatus updatedStatus = tournament.status;
        final willBeFull = updatedFilledSlotsByRole.entries.every((entry) {
          final totalSlots = tournament.slotsByRole[entry.key] ?? 0;
          return entry.value >= totalSlots;
        });
        
        if (willBeFull) {
          updatedStatus = TournamentStatus.full;
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
        
        // Update fields
        final updatedFilledSlots = Map<String, int>.from(tournament.filledSlots);
        updatedFilledSlots[role] = (updatedFilledSlots[role] ?? 1) - 1;
        if (updatedFilledSlots[role]! < 0) updatedFilledSlots[role] = 0;
        
        final updatedFilledSlotsByRole = Map<String, int>.from(tournament.filledSlotsByRole);
        updatedFilledSlotsByRole[role] = (updatedFilledSlotsByRole[role] ?? 1) - 1;
        if (updatedFilledSlotsByRole[role]! < 0) updatedFilledSlotsByRole[role] = 0;
        
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
}
