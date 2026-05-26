import 'package:backgammon_score_tracker/core/models/game_session.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';

class MatchSummaryAdapter {
  const MatchSummaryAdapter();

  Map<String, dynamic> toLegacyScoreMap(GameSession session) {
    final state = session.state;
    final whiteOff = state.borneOff[PlayerColor.white] ?? 0;
    final blackOff = state.borneOff[PlayerColor.black] ?? 0;
    final whiteScore = state.winner == PlayerColor.white ? 1 : 0;
    final blackScore = state.winner == PlayerColor.black ? 1 : 0;
    return {
      'player1': session.playerWhiteName,
      'player2': session.playerBlackName,
      'player1Score': whiteScore,
      'player2Score': blackScore,
      'whiteOff': whiteOff,
      'blackOff': blackOff,
      'winner': state.winner?.name,
      'finishedAt': DateTime.now().toIso8601String(),
    };
  }
}
