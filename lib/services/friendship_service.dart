import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lol_custom_game_manager/models/friendship_model.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _friendshipsCollection => _firestore.collection('friendships');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // 친구 요청 보내기
  Future<void> sendFriendRequest(String receiverId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }
    final requesterId = currentUser.uid;

    if (requesterId == receiverId) {
      throw Exception('자기 자신에게 친구 요청을 보낼 수 없습니다.');
    }

    // 이미 보낸 요청이나 친구 관계가 있는지 확인
    final existingRequest = await _friendshipsCollection
        .where('requesterId', whereIn: [requesterId, receiverId])
        .where('receiverId', whereIn: [requesterId, receiverId])
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('이미 친구 요청을 보냈거나 친구 관계입니다.');
    }

    final newRequest = Friendship(
      id: '', // Firestore에서 자동 생성
      requesterId: requesterId,
      receiverId: receiverId,
      status: FriendshipStatus.pending,
      createdAt: Timestamp.now(),
    );

    await _friendshipsCollection.add(newRequest.toFirestore());
    
    // TODO: Add notification for the receiver
  }

  // 친구 요청 수락
  Future<void> acceptFriendRequest(String friendshipId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    final friendshipDoc = await _friendshipsCollection.doc(friendshipId).get();
    if (!friendshipDoc.exists) throw Exception('존재하지 않는 친구 요청입니다.');

    final friendship = Friendship.fromFirestore(friendshipDoc);
    if (friendship.receiverId != currentUser.uid) {
      throw Exception('요청을 수락할 권한이 없습니다.');
    }

    final requesterId = friendship.requesterId;
    final receiverId = friendship.receiverId;

    // 트랜잭션을 사용하여 원자적으로 업데이트
    await _firestore.runTransaction((transaction) async {
      // 1. friendship 상태 변경
      transaction.update(friendshipDoc.reference, {'status': FriendshipStatus.accepted.index});

      // 2. 양쪽 사용자의 friends 리스트에 서로 추가
      transaction.update(_usersCollection.doc(requesterId), {
        'friends': FieldValue.arrayUnion([receiverId])
      });
      transaction.update(_usersCollection.doc(receiverId), {
        'friends': FieldValue.arrayUnion([requesterId])
      });
    });
  }

  // 친구 요청 거절 또는 친구 삭제
  Future<void> rejectOrRemoveFriend(String friendshipId) async {
     final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    final friendshipDoc = await _friendshipsCollection.doc(friendshipId).get();
    if (!friendshipDoc.exists) throw Exception('존재하지 않는 관계입니다.');
    
    final friendship = Friendship.fromFirestore(friendshipDoc);

    // 친구 관계인 경우, 양쪽의 friends 리스트에서 서로 삭제
    if (friendship.status == FriendshipStatus.accepted) {
       await _firestore.runTransaction((transaction) async {
        transaction.update(_usersCollection.doc(friendship.requesterId), {
          'friends': FieldValue.arrayRemove([friendship.receiverId])
        });
        transaction.update(_usersCollection.doc(friendship.receiverId), {
          'friends': FieldValue.arrayRemove([friendship.requesterId])
        });
      });
    }

    // friendship 문서 삭제
    await friendshipDoc.reference.delete();
  }

  // 두 사용자 간의 친구 관계 상태 확인
  Future<Map<String, dynamic>> getFriendshipStatus(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return {'status': FriendshipStatus.none, 'friendshipId': null};
    
    final requesterId = currentUser.uid;

    final querySnapshot = await _friendshipsCollection
        .where('requesterId', whereIn: [requesterId, otherUserId])
        .where('receiverId', whereIn: [requesterId, otherUserId])
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return {'status': FriendshipStatus.none, 'friendshipId': null};
    }

    final friendshipDoc = querySnapshot.docs.first;
    final friendship = Friendship.fromFirestore(friendshipDoc);

    return {'status': friendship.status, 'friendshipId': friendship.id};
  }

  // 받은 친구 요청 목록 가져오기
  Stream<List<Friendship>> getReceivedFriendRequests(String userId) {
    return _friendshipsCollection
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: FriendshipStatus.pending.index)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Friendship.fromFirestore(doc)).toList());
  }

  // 친구 목록 가져오기
  Stream<List<UserModel>> getFriends(String userId) {
    return _usersCollection.doc(userId).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists) return [];
      final user = UserModel.fromFirestore(userDoc);
      final friendIds = user.friends; // UserModel에 friends 필드가 있다고 가정

      if (friendIds == null || friendIds.isEmpty) return [];

      final friendDocs = await _usersCollection.where(FieldPath.documentId, whereIn: friendIds).get();
      return friendDocs.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }
}