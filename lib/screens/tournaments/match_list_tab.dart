import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/tournament_provider.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';
import 'package:lol_custom_game_manager/widgets/error_view.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:lol_custom_game_manager/widgets/lane_icon_widget.dart';
import 'package:provider/provider.dart';

class MatchListTab extends StatefulWidget {
  final TournamentType tournamentType;

  const MatchListTab({
    Key? key,
    required this.tournamentType,
  }) : super(key: key);

  @override
  MatchListTabState createState() => MatchListTabState();
}

class MatchListTabState extends State<MatchListTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !provider.isLoading(widget.tournamentType) &&
        provider.hasMore(widget.tournamentType)) {
      provider.fetchMoreTournaments(widget.tournamentType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TournamentProvider>(
      builder: (context, provider, child) {
        final tournaments = provider.tournaments(widget.tournamentType);
        final isLoading = provider.isLoading(widget.tournamentType);
        final hasMore = provider.hasMore(widget.tournamentType);
        final errorMessage = provider.errorMessage;

        if (errorMessage != null) {
          return ErrorView(
            errorMessage: errorMessage,
            onRetry: () => provider.fetchInitialTournaments(widget.tournamentType),
          );
        }

        // 초기 로딩 중이면서 데이터가 없을 때만 전체 로딩 인디케이터 표시
        if (isLoading && tournaments.isEmpty) {
          return const LoadingIndicator();
        }

        if (tournaments.isEmpty) {
          return _buildEmptyState(context, provider.selectedDate);
        }

        return RefreshIndicator(
          onRefresh: () => provider.fetchInitialTournaments(widget.tournamentType),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: tournaments.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == tournaments.length) {
                // 로딩 중 & 더 많은 데이터가 있을 때만 하단 로딩 인디케이터 표시
                return isLoading ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: LoadingIndicator(),
                ) : const SizedBox.shrink();
              }
              final tournament = tournaments[index];
              return _buildTournamentCard(context, tournament);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, DateTime selectedDate) {
    String message = '${DateFormat('M월 d일', 'ko_KR').format(selectedDate)}에 예정된 내전이 없습니다';

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_busy_rounded,
                    size: 72,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/tournaments/create');
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    '내전 만들기',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTournamentCard(BuildContext context, TournamentModel tournament) {
    final orderedRoles = ['top', 'jungle', 'mid', 'adc', 'support'];
    final totalParticipants = tournament.participants.length;
    final totalSlots = tournament.slotsByRole.values.fold(0, (sum, count) => sum + count);

    Map<String, String> tierInfo = {};
    void checkAndAddTier(String tierName, String iconPath) {
      if (tournament.title.toLowerCase().contains(tierName)) {
        tierInfo[tierName] = iconPath;
      }
    }

    checkAndAddTier('아이언', 'assets/images/tiers/아이언로고.png');
    checkAndAddTier('브론즈', 'assets/images/tiers/브론즈로고.png');
    checkAndAddTier('실버', 'assets/images/tiers/실버로고.png');
    checkAndAddTier('골드', 'assets/images/tiers/골드로고.png');
    checkAndAddTier('플레티넘', 'assets/images/tiers/플레티넘로고.png');
    checkAndAddTier('플래티넘', 'assets/images/tiers/플레티넘로고.png');
    checkAndAddTier('에메랄드', 'assets/images/tiers/에메랄드로고.png');
    checkAndAddTier('다이아', 'assets/images/tiers/다이아로고.png');
    checkAndAddTier('마스터', 'assets/images/tiers/마스터로고.png');

    List<String> tierIconPaths = [];
    if (tierInfo.containsKey('아이언')) tierIconPaths.add('assets/images/tiers/아이언로고.png');
    if (tierInfo.containsKey('브론즈')) tierIconPaths.add('assets/images/tiers/브론즈로고.png');
    if (tierInfo.containsKey('실버')) tierIconPaths.add('assets/images/tiers/실버로고.png');
    if (tierInfo.containsKey('골드')) tierIconPaths.add('assets/images/tiers/골드로고.png');
    if (tierInfo.containsKey('플레티넘') || tierInfo.containsKey('플래티넘')) tierIconPaths.add('assets/images/tiers/플레티넘로고.png');
    if (tierInfo.containsKey('에메랄드')) tierIconPaths.add('assets/images/tiers/에메랄드로고.png');
    if (tierInfo.containsKey('다이아')) tierIconPaths.add('assets/images/tiers/다이아로고.png');
    if (tierInfo.containsKey('마스터')) tierIconPaths.add('assets/images/tiers/마스터로고.png');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          context.push('/tournaments/${tournament.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('HH:mm', 'ko_KR').format(tournament.startsAt.toDate()),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(tournament.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(tournament.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(tournament.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tournament.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (tierIconPaths.isNotEmpty)
                    SizedBox(
                      height: 24,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        children: tierIconPaths.map((path) => 
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Image.asset(
                              path,
                              width: 24,
                              height: 24,
                            ),
                          )
                        ).toList(),
                      ),
                    )
                  else if (tournament.title.toLowerCase().contains('랜덤'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '랜덤',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '참가 현황',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$totalParticipants/$totalSlots',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getParticipantCountColor(totalParticipants, totalSlots),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: orderedRoles.map((role) {
                      final totalForRole = tournament.slotsByRole[role] ?? 2;
                      final filledForRole = tournament.filledSlotsByRole[role] ?? 0;
                      
                      return Column(
                        children: [
                          LaneIconWidget(
                            lane: role,
                            size: 36,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$filledForRole/$totalForRole',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _getParticipantCountColor(filledForRole, totalForRole),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalSlots > 0 ? totalParticipants / totalSlots : 0,
                      backgroundColor: Colors.grey.shade200,
                      color: _getProgressBarColor(totalParticipants, totalSlots),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getParticipantCountColor(int filled, int total) {
    if (filled == 0) return Colors.black;
    if (filled < total) return Colors.amber.shade700;
    return Colors.red;
  }

  Color _getProgressBarColor(int filled, int total) {
    if (filled == 0) return Colors.grey.shade700;
    if (filled < total) return Colors.amber.shade700;
    return Colors.red;
  }

  String _getStatusText(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return '초안';
      case TournamentStatus.open:
        return '모집 중';
      case TournamentStatus.full:
        return '모집 완료';
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return '진행 중';
      case TournamentStatus.completed:
        return '완료됨';
      case TournamentStatus.cancelled:
        return '취소됨';
    }
  }

  Color _getStatusColor(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.draft:
        return Colors.grey;
      case TournamentStatus.open:
        return AppColors.success;
      case TournamentStatus.full:
        return AppColors.primary;
      case TournamentStatus.inProgress:
      case TournamentStatus.ongoing:
        return AppColors.warning;
      case TournamentStatus.completed:
        return AppColors.textSecondary;
      case TournamentStatus.cancelled:
        return AppColors.error;
    }
  }
}