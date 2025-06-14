import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/friendship_model.dart';
import 'package:lol_custom_game_manager/models/user_profile_model.dart';
import 'package:lol_custom_game_manager/services/chat_service.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/services/friendship_service.dart';
import 'package:lol_custom_game_manager/services/user_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon.dart';
import 'package:lol_custom_game_manager/constants/lol_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:lol_custom_game_manager/models/user_model.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final ClanService _clanService = ClanService();
  final FriendshipService _friendshipService = FriendshipService();

  late Future<UserProfile> _userProfileFuture;
  bool _isClanOwner = false;
  ClanModel? _currentUserClan;
  
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  String? _friendshipId;
  bool _isLoadingFriendship = true;


  @override
  void initState() {
    super.initState();
    _userProfileFuture = _userService.getUserProfile(widget.userId);
    _checkIfClanOwner();
    _getFriendshipStatus();
  }

  Future<void> _checkIfClanOwner() async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser?.clanId == null) return;

    final clan = await _clanService.getClan(currentUser!.clanId!);
    if (mounted && clan != null && clan.ownerId == currentUser.uid) {
      setState(() {
        _isClanOwner = true;
        _currentUserClan = clan;
      });
    }
  }

  Future<void> _getFriendshipStatus() async {
    setState(() => _isLoadingFriendship = true);
    try {
      final statusData = await _friendshipService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _friendshipStatus = statusData['status'];
          _friendshipId = statusData['friendshipId'];
        });
      }
    } catch (e) {
      // 에러 처리
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriendship = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final isMyProfile = currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<UserProfile>(
        future: _userProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('프로필 정보를 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
          }

          final profile = snapshot.data!;

          return Column(
            children: [
              const Spacer(),
              _buildProfileHeader(context, profile),
              const SizedBox(height: 20),
              _buildInfoSection(context, profile),
              const Divider(height: 40, indent: 20, endIndent: 20),
              if (!isMyProfile) _buildActionButtons(context, profile),
              const Spacer(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfile profile) {
    final user = profile.user;
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: user.profileImageUrl.isNotEmpty
              ? NetworkImage(user.profileImageUrl)
              : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
        ),
        const SizedBox(height: 16),
        Text(
          user.nickname,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        if (profile.clan != null)
          Text(
            '소속 클랜: ${profile.clan!.name}',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
      ],
    );
  }
  
  Widget _buildInfoSection(BuildContext context, UserProfile profile) {
    final user = profile.user;
    final tierName = user.tier.name;
    final tierIconPath = LolTierIcons.getIconPath(tierName);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(tierIconPath, width: 24, height: 24),
            const SizedBox(width: 8),
            Text(
              UserModel.tierToString(user.tier),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('주 포지션: ', style: TextStyle(fontSize: 16)),
            if (user.preferredPositions != null && user.preferredPositions!.isNotEmpty)
              ...user.preferredPositions!
                  .map((position) => Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: LaneIcon(lane: position, size: 24),
                      ))
                  .toList()
            else
              const Text('미설정', style: TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, UserProfile profile) {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionButton(
          context,
          icon: Icons.chat_bubble_outline,
          label: '1:1 채팅',
          onPressed: () async {
            try {
              final chatRoomId = await _chatService.getOrCreateDirectChatRoom(
                currentUser.uid,
                profile.user.uid,
              );
              context.push('/chat/$chatRoomId');
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('채팅방을 여는 중 오류가 발생했습니다: $e')),
              );
            }
          },
        ),
        if (_isClanOwner && profile.clan == null)
          _actionButton(
            context,
            icon: Icons.group_add_outlined,
            label: '클랜 초대',
            onPressed: () async {
              try {
                await _clanService.inviteUserToClan(
                  _currentUserClan!.id,
                  profile.user.uid,
                  currentUser.nickname,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('클랜 초대를 보냈습니다.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('클랜 초대 중 오류가 발생했습니다: $e')),
                );
              }
            },
          ),
        _buildFriendActionButton(),
      ],
    );
  }

  Widget _buildFriendActionButton() {
    if (_isLoadingFriendship) {
      return const CircularProgressIndicator();
    }

    switch (_friendshipStatus) {
      case FriendshipStatus.none:
        return _actionButton(context, icon: Icons.person_add_alt_1_outlined, label: '친구 추가', onPressed: () async {
          await _friendshipService.sendFriendRequest(widget.userId);
          _getFriendshipStatus();
        });
      case FriendshipStatus.pending:
        return _actionButton(context, icon: Icons.cancel_outlined, label: '요청 취소', onPressed: () async {
          if (_friendshipId != null) {
            await _friendshipService.rejectOrRemoveFriend(_friendshipId!);
            _getFriendshipStatus();
          }
        });
      case FriendshipStatus.accepted:
        return _actionButton(context, icon: Icons.person_remove_outlined, label: '친구 끊기', onPressed: () async {
          if (_friendshipId != null) {
            await _friendshipService.rejectOrRemoveFriend(_friendshipId!);
            _getFriendshipStatus();
          }
        });
      case FriendshipStatus.rejected:
        return _actionButton(context, icon: Icons.person_add_alt_1_outlined, label: '친구 추가', onPressed: () async {
           await _friendshipService.sendFriendRequest(widget.userId);
           _getFriendshipStatus();
        });
    }
  }

  Widget _actionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white,
          child: IconButton(
            icon: Icon(icon, size: 28),
            onPressed: onPressed,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}