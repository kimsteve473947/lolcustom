import 'package:lol_custom_game_manager/models/user_model.dart';
import 'package:lol_custom_game_manager/models/clan_model.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';

class UserProfile {
  final UserModel user;
  final ClanModel? clan;
  final List<TournamentModel> recentTournaments;
  // TODO: Add recent mercenary posts, ratings, etc.

  UserProfile({
    required this.user,
    this.clan,
    this.recentTournaments = const [],
  });
}