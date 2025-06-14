import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/models/user_profile_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UserProfile> getUserProfile(String userId) async {
    // 1. Get user data
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }
    final user = UserModel.fromFirestore(userDoc);

    // 2. Get clan data
    ClanModel? clan;
    if (user.clanId != null && user.clanId!.isNotEmpty) {
      final clanDoc = await _firestore.collection('clans').doc(user.clanId).get();
      if (clanDoc.exists) {
        clan = ClanModel.fromFirestore(clanDoc);
      }
    }

    // 3. Get recent tournaments
    final tournamentsSnapshot = await _firestore
        .collection('tournaments')
        .where('participants', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .get();
    
    final recentTournaments = tournamentsSnapshot.docs
        .map((doc) => TournamentModel.fromFirestore(doc))
        .toList();

    // 4. Construct and return profile
    return UserProfile(
      user: user,
      clan: clan,
      recentTournaments: recentTournaments,
    );
  }

  Future<UserModel?> getUser(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return null;
    }
    return UserModel.fromFirestore(userDoc);
  }

  Future<void> updateUserProfile({
    required String uid,
    required String nickname,
    String? statusMessage,
    String? profileImageUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'nickname': nickname,
        'statusMessage': statusMessage ?? '',
      };

      if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }

      await _firestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      // debugPrint('Error updating user profile: $e');
      throw Exception('프로필 업데이트 중 오류가 발생했습니다.');
    }
  }

  Future<String> uploadProfileImage({
    required String uid,
    required File imageFile,
  }) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      // debugPrint('Error uploading profile image: $e');
      throw Exception('프로필 이미지 업로드 중 오류가 발생했습니다.');
    }
  }
}