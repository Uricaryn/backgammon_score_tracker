import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/services/tournament_service.dart';

class TournamentDetailController extends ChangeNotifier {
  TournamentDetailController({
    required this.tournamentId,
    required this.initialParticipants,
    TournamentService? tournamentService,
    FirebaseFirestore? firestore,
  })  : _tournamentService = tournamentService ?? TournamentService(),
        _firestore = firestore ?? FirebaseFirestore.instance {
    _attachListeners();
  }

  final String tournamentId;
  final List<String> initialParticipants;
  final TournamentService _tournamentService;
  final FirebaseFirestore _firestore;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _tournamentSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _matchesSubscription;

  Map<String, dynamic>? tournamentData;
  List<Map<String, dynamic>> matches = const [];
  Object? tournamentError;
  Object? matchesError;
  bool tournamentLoading = true;
  bool matchesLoading = true;

  List<String> get participants =>
      List<String>.from(tournamentData?['participants'] ?? initialParticipants);

  List<Map<String, dynamic>> get completedMatches =>
      matches.where((m) => m['status'] == 'completed').toList();

  void _attachListeners() {
    _tournamentSubscription = _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .snapshots()
        .listen(
      (snapshot) {
        tournamentLoading = false;
        if (!snapshot.exists) {
          tournamentData = null;
          tournamentError = 'Turnuva bulunamadı';
        } else {
          tournamentData = snapshot.data();
          tournamentError = null;
        }
        notifyListeners();
      },
      onError: (error) {
        tournamentLoading = false;
        tournamentError = error;
        notifyListeners();
      },
    );

    _matchesSubscription =
        _tournamentService.getTournamentMatches(tournamentId).listen(
      (value) {
        matchesLoading = false;
        matches = value;
        matchesError = null;
        notifyListeners();
      },
      onError: (error) {
        matchesLoading = false;
        matchesError = error;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _tournamentSubscription?.cancel();
    _matchesSubscription?.cancel();
    super.dispose();
  }
}
