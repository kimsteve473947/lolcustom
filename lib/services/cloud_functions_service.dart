import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:lol_custom_game_manager/models/models.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions;
  
  // Initialize with region for web compatibility
  CloudFunctionsService() : _functions = FirebaseFunctions.instance;
  
  // Call a cloud function to send a notification to all tournament participants
  Future<void> notifyTournamentParticipants({
    required String tournamentId,
    required String message,
  }) async {
    try {
      final callable = _functions.httpsCallable('notifyTournamentParticipants');
      await callable.call({
        'tournamentId': tournamentId,
        'message': message,
      });
    } catch (e) {
      print('Error notifying tournament participants: $e');
      throw e;
    }
  }
  
  // Call a cloud function to update user rating statistics
  Future<void> updateUserRatings(String userId) async {
    try {
      final callable = _functions.httpsCallable('updateUserRatings');
      await callable.call({
        'userId': userId,
      });
    } catch (e) {
      print('Error updating user ratings: $e');
      throw e;
    }
  }
  
  // Call a cloud function to process a tournament application
  Future<Map<String, dynamic>> processTournamentApplication({
    required String tournamentId,
    required String userId,
    required String role,
  }) async {
    try {
      final callable = _functions.httpsCallable('processTournamentApplication');
      final result = await callable.call({
        'tournamentId': tournamentId,
        'userId': userId,
        'role': role,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error processing tournament application: $e');
      throw e;
    }
  }
  
  // Call a cloud function to clean up expired tournaments
  Future<void> cleanupExpiredTournaments() async {
    try {
      final callable = _functions.httpsCallable('cleanupExpiredTournaments');
      await callable.call();
    } catch (e) {
      print('Error cleaning up expired tournaments: $e');
      throw e;
    }
  }
  
  // Call a cloud function to create a chat room and notify participants
  Future<String> createChatRoomWithNotification({
    required List<String> participantIds,
    required String title,
    required ChatRoomType type,
    String? initialMessage,
  }) async {
    try {
      final callable = _functions.httpsCallable('createChatRoomWithNotification');
      final result = await callable.call({
        'participantIds': participantIds,
        'title': title,
        'type': type.index,
        'initialMessage': initialMessage,
      });
      return result.data['chatRoomId'] as String;
    } catch (e) {
      print('Error creating chat room with notification: $e');
      throw e;
    }
  }

  // Example of calling a cloud function that handles data correctly for web
  Future<Map<String, dynamic>> callFunction(
    String functionName, 
    Map<String, dynamic> parameters
  ) async {
    try {
      final result = await _functions.httpsCallable(functionName).call(parameters);
      
      // The data object is already properly converted to Dart objects by the SDK
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error calling cloud function $functionName: $e');
      rethrow;
    }
  }
  
  // Example for tournament creation
  Future<String> createTournament(Map<String, dynamic> tournamentData) async {
    try {
      final result = await _functions.httpsCallable('createTournament').call(tournamentData);
      return result.data['tournamentId'] as String;
    } catch (e) {
      debugPrint('Error creating tournament: $e');
      rethrow;
    }
  }
  
  // Example for user registration in a tournament
  Future<void> registerForTournament(String tournamentId, String userId, String role) async {
    try {
      await _functions.httpsCallable('registerForTournament').call({
        'tournamentId': tournamentId,
        'userId': userId,
        'role': role,
      });
    } catch (e) {
      debugPrint('Error registering for tournament: $e');
      rethrow;
    }
  }
} 