import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User methods
  Future<UserModel?> getCurrentUser() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        return null;
      }
      
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        return null;
      }
      
      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toFirestore());
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw e;
    }
  }

  // Storage methods
  Future<String> uploadImage(String path, Uint8List bytes) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw e;
    }
  }
  
  // Tournament methods
  Future<String> createTournament(TournamentModel tournament) async {
    try {
      DocumentReference docRef = await _firestore.collection('tournaments').add(tournament.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating tournament: $e');
      throw e;
    }
  }
  
  Future<void> updateTournament(TournamentModel tournament) async {
    try {
      await _firestore.collection('tournaments').doc(tournament.id).update(tournament.toFirestore());
    } catch (e) {
      debugPrint('Error updating tournament: $e');
      throw e;
    }
  }
  
  Future<void> deleteTournament(String tournamentId) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).delete();
    } catch (e) {
      debugPrint('Error deleting tournament: $e');
      throw e;
    }
  }
  
  // Get tournament by ID
  Future<TournamentModel?> getTournament(String tournamentId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('tournaments').doc(tournamentId).get();
      if (!doc.exists) {
        return null;
      }
      return TournamentModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting tournament: $e');
      throw e;
    }
  }
  
  // Mercenary methods
  Future<String> createMercenary(MercenaryModel mercenary) async {
    try {
      DocumentReference docRef = await _firestore.collection('mercenaries').add(mercenary.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating mercenary: $e');
      throw e;
    }
  }
  
  Future<void> updateMercenary(MercenaryModel mercenary) async {
    try {
      await _firestore.collection('mercenaries').doc(mercenary.id).update(mercenary.toFirestore());
    } catch (e) {
      debugPrint('Error updating mercenary: $e');
      throw e;
    }
  }
  
  // Rating methods
  Future<void> addRating(RatingModel rating) async {
    try {
      await _firestore.collection('ratings').add(rating.toFirestore());
    } catch (e) {
      debugPrint('Error adding rating: $e');
      throw e;
    }
  }
  
  // Get ratings for a specific user
  Future<List<RatingModel>> getUserRatings(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('ratings')
          .where('ratedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
          
      return snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting user ratings: $e');
      throw e;
    }
  }
  
  // Calculate average rating for a user
  Future<double> calculateAverageRating(String userId) async {
    try {
      List<RatingModel> ratings = await getUserRatings(userId);
      if (ratings.isEmpty) return 0.0;
      
      double total = ratings.fold(0.0, (sum, rating) => sum + rating.score);
      return total / ratings.length;
    } catch (e) {
      debugPrint('Error calculating average rating: $e');
      throw e;
    }
  }
} 