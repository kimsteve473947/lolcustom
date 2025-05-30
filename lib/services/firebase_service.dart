import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/models.dart';

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
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toFirestore());
    } catch (e) {
      print('Error creating user profile: $e');
      throw e;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toFirestore());
    } catch (e) {
      print('Error updating user profile: $e');
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
      Query query = _firestore.collection('tournaments')
          .orderBy('startsAt', descending: false)
          .where('status', isEqualTo: TournamentStatus.open.index);

      if (startDate != null) {
        query = query.where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('startsAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
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
      return snapshot.docs.map((doc) => TournamentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting tournaments: $e');
      return [];
    }
  }

  Future<TournamentModel?> getTournament(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('tournaments').doc(id).get();
      if (doc.exists) {
        return TournamentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting tournament: $e');
      return null;
    }
  }

  Future<String> createTournament(TournamentModel tournament) async {
    try {
      DocumentReference ref = await _firestore.collection('tournaments').add(tournament.toFirestore());
      return ref.id;
    } catch (e) {
      print('Error creating tournament: $e');
      throw e;
    }
  }

  Future<void> updateTournament(TournamentModel tournament) async {
    try {
      await _firestore.collection('tournaments').doc(tournament.id).update(tournament.toFirestore());
    } catch (e) {
      print('Error updating tournament: $e');
      throw e;
    }
  }

  // Application methods
  Future<String> applyToTournament(ApplicationModel application) async {
    try {
      DocumentReference ref = await _firestore.collection('applications').add(application.toFirestore());
      return ref.id;
    } catch (e) {
      print('Error applying to tournament: $e');
      throw e;
    }
  }

  Future<List<ApplicationModel>> getTournamentApplications(String tournamentId) async {
    try {
      final snapshot = await _firestore.collection('applications')
          .where('tournamentId', isEqualTo: tournamentId)
          .get();
      return snapshot.docs.map((doc) => ApplicationModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting tournament applications: $e');
      return [];
    }
  }

  Future<void> updateApplicationStatus(String id, ApplicationStatus status) async {
    try {
      await _firestore.collection('applications').doc(id).update({'status': status.index});
    } catch (e) {
      print('Error updating application status: $e');
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
      Query query = _firestore.collection('mercenaries')
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
      List<MercenaryModel> mercenaries = snapshot.docs.map((doc) => MercenaryModel.fromFirestore(doc)).toList();
      
      // Filter by minOvr if provided (this can't be done in the query)
      if (minOvr != null) {
        mercenaries = mercenaries.where((m) => m.averageRoleStat >= minOvr).toList();
      }
      
      return mercenaries;
    } catch (e) {
      print('Error getting mercenaries: $e');
      return [];
    }
  }

  Future<String> createMercenaryProfile(MercenaryModel mercenary) async {
    try {
      DocumentReference ref = await _firestore.collection('mercenaries').add(mercenary.toFirestore());
      return ref.id;
    } catch (e) {
      print('Error creating mercenary profile: $e');
      throw e;
    }
  }

  Future<void> updateMercenaryProfile(MercenaryModel mercenary) async {
    try {
      await _firestore.collection('mercenaries').doc(mercenary.id).update(mercenary.toFirestore());
    } catch (e) {
      print('Error updating mercenary profile: $e');
      throw e;
    }
  }

  Future<MercenaryModel?> getMercenary(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('mercenaries').doc(id).get();
      if (doc.exists) {
        return MercenaryModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting mercenary: $e');
      return null;
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Rating methods
  Future<String> rateUser(RatingModel rating) async {
    try {
      DocumentReference ref = await _firestore.collection('ratings').add(rating.toFirestore());
      return ref.id;
    } catch (e) {
      print('Error rating user: $e');
      throw e;
    }
  }

  Future<List<RatingModel>> getUserRatings(String userId) async {
    try {
      final snapshot = await _firestore.collection('ratings')
          .where('targetUid', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting user ratings: $e');
      return [];
    }
  }

  // Chat methods
  Future<String> createChatRoom(ChatRoomModel chatRoom) async {
    try {
      DocumentReference ref = await _firestore.collection('chatRooms').add(chatRoom.toFirestore());
      return ref.id;
    } catch (e) {
      print('Error creating chat room: $e');
      throw e;
    }
  }

  Future<List<ChatRoomModel>> getUserChatRooms(String userId) async {
    try {
      final snapshot = await _firestore.collection('chatRooms')
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();
      return snapshot.docs.map((doc) => ChatRoomModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting user chat rooms: $e');
      return [];
    }
  }

  Future<String> sendMessage(MessageModel message) async {
    try {
      // Add the message
      DocumentReference ref = await _firestore.collection('messages').add(message.toFirestore());
      
      // Update the chat room with last message
      await _firestore.collection('chatRooms').doc(message.chatRoomId).update({
        'lastMessageText': message.text,
        'lastMessageTime': message.timestamp,
      });
      
      return ref.id;
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  Stream<List<MessageModel>> getChatMessages(String chatRoomId) {
    return _firestore.collection('messages')
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
      print('Error uploading image: $e');
      throw e;
    }
  }
} 