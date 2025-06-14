import 'package:flutter/material.dart';
import 'package:lol_custom_game_manager/models/clan_application_model.dart';
import 'package:lol_custom_game_manager/services/clan_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:lol_custom_game_manager/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class ClanMemberTab extends StatefulWidget {
  final String clanId;
  final bool isOwner;

  const ClanMemberTab({
    Key? key,
    required this.clanId,
    required this.isOwner,
  }) : super(key: key);

  @override
  State<ClanMemberTab> createState() => _ClanMemberTabState();
}

class _ClanMemberTabState extends State<ClanMemberTab> {
  final ClanService _clanService = ClanService();
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Stream<List<ClanApplicationModel>> _applicationsStream;

  @override
  void initState() {
    super.initState();
    _membersFuture = _clanService.getClanMembers(widget.clanId);
    if (widget.isOwner) {
      _applicationsStream = _clanService.getClanApplications(widget.clanId);
    }
  }

  void _processApplication(String applicationId, ClanApplicationStatus status) async {
    try {
      await _clanService.processClanApplication(
        applicationId: applicationId,
        newStatus: status,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청이 ${status == ClanApplicationStatus.accepted ? '수락' : '거절'}되었습니다.')),
      );
      // Refresh member list after processing
      setState(() {
        _membersFuture = _clanService.getClanMembers(widget.clanId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('클랜원 목록'),
          _buildMembersList(),
          if (widget.isOwner) ...[
            const Divider(height: 48),
            _buildSectionTitle('가입 신청 현황'),
            _buildApplicationsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildMembersList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('멤버 목록을 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('클랜원이 없습니다.'));
        }

        final members = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isOwner = member['isOwner'] as bool;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: member['photoURL'] != null
                    ? NetworkImage(member['photoURL'])
                    : null,
                child: member['photoURL'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(member['displayName'] ?? member['nickname'] ?? '이름 없음'),
              trailing: isOwner ? const Chip(label: Text('클랜장')) : null,
              onTap: () {
                context.push('/profile/${member['uid']}');
              },
            );
          },
        );
      },
    );
  }

  Widget _buildApplicationsList() {
    return StreamBuilder<List<ClanApplicationModel>>(
      stream: _applicationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('가입 신청 목록을 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('새로운 가입 신청이 없습니다.'),
          ));
        }

        final applications = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application = applications[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: application.userProfileImageUrl != null
                            ? NetworkImage(application.userProfileImageUrl!)
                            : null,
                        child: application.userProfileImageUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(application.userName),
                      subtitle: Text(application.message ?? '가입 메시지가 없습니다.'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _processApplication(application.id, ClanApplicationStatus.rejected),
                          child: const Text('거절', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _processApplication(application.id, ClanApplicationStatus.accepted),
                          child: const Text('수락'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}