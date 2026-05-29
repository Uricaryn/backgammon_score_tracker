import 'package:backgammon_score_tracker/core/models/game_state.dart';

/// Lightweight row for the online tavla lobby (unfinished live games).
class ActiveLiveGameSummary {
  const ActiveLiveGameSummary({
    required this.roomId,
    required this.opponentName,
    required this.status,
    required this.updatedAt,
    required this.isOpponentAway,
  });

  final String roomId;
  final String opponentName;
  final GameStatus status;
  final DateTime updatedAt;
  final bool isOpponentAway;

  bool get isFinished => status == GameStatus.finished;

  String get statusLabel {
    switch (status) {
      case GameStatus.waiting:
        return 'Bekleniyor';
      case GameStatus.openingRoll:
        return 'Acilis zari';
      case GameStatus.active:
        return 'Devam ediyor';
      case GameStatus.finished:
        return 'Bitti';
    }
  }
}
