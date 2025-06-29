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
        debugPrint('getCurrentUser: No current user found in Firebase Auth');
        return null;
      }
      
      // Reload the user to ensure we have the latest data
      await user.reload();
      user = _auth.currentUser; // Get the refreshed user
      
      if (user == null) {
        debugPrint('getCurrentUser: User is null after reload');
        return null;
      }
      
      debugPrint('getCurrentUser: Getting user document for uid: ${user.uid}, email: ${user.email}, displayName: ${user.displayName}');
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        debugPrint('getCurrentUser: User document does not exist for uid: ${user.uid}');
        
        // Get display name from Firebase Auth if available
        String nickname = user.displayName ?? '';
        
        // If display name is empty, use email as a fallback
        if (nickname.isEmpty) {
          if (user.email != null && user.email!.isNotEmpty) {
            // Extract name from email (before @)
            nickname = user.email!.split('@')[0];
            // Capitalize first letter
            if (nickname.isNotEmpty) {
              nickname = nickname[0].toUpperCase() + nickname.substring(1);
            }
          } else {
            // Last resort - use a generic name with partial UID
            nickname = '사용자${user.uid.substring(0, 4)}';
          }
        }
        
        debugPrint('getCurrentUser: Creating new user document with nickname: $nickname');
        
        // Create a new user document with the determined nickname
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          nickname: nickname,
          joinedAt: Timestamp.now(),
        );
        
        await _firestore.collection('users').doc(user.uid).set(newUser.toFirestore());
        return newUser;
      }
      
      // Create UserModel from the Firestore document
      UserModel userModel = UserModel.fromFirestore(doc);
      
      // If the nickname is empty or looks like a system-generated ID, try to update it
      if (userModel.nickname.isEmpty || 
          userModel.nickname.startsWith('User') || 
          userModel.nickname.startsWith('n') && userModel.nickname.length > 20) {
        
        // Get better nickname from Firebase Auth if available
        String updatedNickname = user.displayName ?? '';
        
        if (updatedNickname.isNotEmpty) {
          // Update the user model with the better nickname
          userModel = userModel.copyWith(nickname: updatedNickname);
          await _firestore.collection('users').doc(user.uid).update({'nickname': updatedNickname});
          debugPrint('getCurrentUser: Updated nickname from Firebase Auth: $updatedNickname');
        }
      }
      
      debugPrint('getCurrentUser: Retrieved user: ${userModel.nickname} with ID: ${userModel.uid}');
      return userModel;
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
  
  // 용병 관련 메서드들을 제거했습니다 (듀오 찾기 기능만 유지)
  
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