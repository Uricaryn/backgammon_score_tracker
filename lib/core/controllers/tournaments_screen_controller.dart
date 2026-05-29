import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/services/tournament_service.dart';

class TournamentsScreenController extends ChangeNotifier {
  TournamentsScreenController({TournamentService? tournamentService})
      : _tournamentService = tournamentService ?? TournamentService() {
    _personalSub = _tournamentService
        .getTournaments(category: TournamentService.tournamentCategoryPersonal)
        .listen(
      (value) {
        personalTournaments = value;
        personalError = null;
        personalLoading = false;
        notifyListeners();
      },
      onError: (error) {
        personalError = error;
        personalLoading = false;
        notifyListeners();
      },
    );
    _socialSub = _tournamentService
        .getTournaments(category: TournamentService.tournamentCategorySocial)
        .listen(
      (value) {
        socialTournaments = value;
        socialError = null;
        socialLoading = false;
        notifyListeners();
      },
      onError: (error) {
        socialError = error;
        socialLoading = false;
        notifyListeners();
      },
    );
    _invitationsSub = _tournamentService.getTournamentInvitations().listen(
      (value) {
        invitations = value;
        invitationsError = null;
        invitationsLoading = false;
        notifyListeners();
      },
      onError: (error) {
        invitationsError = error;
        invitationsLoading = false;
        notifyListeners();
      },
    );
  }

  final TournamentService _tournamentService;
  StreamSubscription<List<Map<String, dynamic>>>? _personalSub;
  StreamSubscription<List<Map<String, dynamic>>>? _socialSub;
  StreamSubscription<List<Map<String, dynamic>>>? _invitationsSub;

  List<Map<String, dynamic>> personalTournaments = const [];
  List<Map<String, dynamic>> socialTournaments = const [];
  List<Map<String, dynamic>> invitations = const [];
  Object? personalError;
  Object? socialError;
  Object? invitationsError;
  bool personalLoading = true;
  bool socialLoading = true;
  bool invitationsLoading = true;

  @override
  void dispose() {
    _personalSub?.cancel();
    _socialSub?.cancel();
    _invitationsSub?.cancel();
    super.dispose();
  }
}
