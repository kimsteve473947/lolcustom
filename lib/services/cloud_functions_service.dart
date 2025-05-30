import 'package:cloud_functions/cloud_functions.dart';
import 'package:lol_custom_game_manager/models/models.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
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
}

// This enum should match the one in models.dart
enum ChatRoomType {
  tournamentRecruitment,
  mercenaryOffer,
} 