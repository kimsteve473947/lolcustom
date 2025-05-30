import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lol_custom_game_manager/models/models.dart';

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
      print('Error getting current user: $e');
      return null;
    }
  }

  // Storage methods
  Future<String> uploadImage(String path, Uint8List bytes) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }
} 