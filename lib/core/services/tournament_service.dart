import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/services/friendship_service.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logService = LogService();
  final FriendshipService _friendshipService = FriendshipService();
  final PremiumService _premiumService = PremiumService();

  // Tournament durumları
  static const String tournamentPending = 'pending';
  static const String tournamentActive = 'active';
  static const String tournamentCompleted = 'completed';
  static const String tournamentCancelled = 'cancelled';

  // Tournament tipleri
  static const String tournamentTypeElimination = 'elimination';
  static const String tournamentTypeRoundRobin = 'round_robin';

  // Tournament kategorileri
  static const String tournamentCategorySocial = 'social';
  static const String tournamentCategoryPersonal = 'personal';

  // Participant durumları
  static const String participantPending = 'pending';
  static const String participantAccepted = 'accepted';
  static const String participantDeclined = 'declined';

  /// Yeni turnuva oluştur
  Future<String> createTournament({
    required String name,
    required String type,
    required String category, // social veya personal
    required int maxParticipants,
    List<String>? invitedFriends, // Sadece social için gerekli
    List<String>? selectedPlayers, // Sadece personal için gerekli
    String? description,
    DateTime? startDate,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Category doğrulaması
      if (category != tournamentCategorySocial &&
          category != tournamentCategoryPersonal) {
        throw Exception('Geçersiz turnuva kategorisi');
      }

      // Minimum katılımcı kontrolü
      if (maxParticipants < 2) {
        throw Exception('Turnuva en az 2 katılımcı gerektirir');
      }

      // Turnuva tipine göre maksimum katılımcı kontrolü
      if (type == tournamentTypeElimination) {
        if (maxParticipants > 16) {
          throw Exception('Eleme turnuvaları maksimum 16 katılımcı olabilir');
        }
        // Eleme turnuvaları için 2'nin kuvveti kontrolü
        if ((maxParticipants & (maxParticipants - 1)) != 0) {
          throw Exception(
              'Eleme turnuvaları için katılımcı sayısı 2, 4, 8, 16 olmalıdır');
        }
      }

      // Kategori bazında validasyonlar
      if (category == tournamentCategorySocial) {
        if (invitedFriends == null || invitedFriends.isEmpty) {
          throw Exception('Sosyal turnuvalar için arkadaş davet etmelisiniz');
        }

        // Davet edilenler sadece arkadaş mı kontrol et
        for (final friendId in invitedFriends) {
          final isFriend =
              await _friendshipService.areFriends(currentUser.uid, friendId);
          if (!isFriend) {
            throw Exception(
                'Sadece arkadaşlarınızı turnuvaya davet edebilirsiniz');
          }
        }
      } else if (category == tournamentCategoryPersonal) {
        if (selectedPlayers == null || selectedPlayers.isEmpty) {
          throw Exception('Kişisel turnuvalar için oyuncu seçmelisiniz');
        }

        if (selectedPlayers.length != maxParticipants) {
          throw Exception(
              'Seçilen oyuncu sayısı maksimum katılımcı sayısına eşit olmalıdır');
        }
      }

      // Turnuva oluştur
      final tournamentRef = await _firestore.collection('tournaments').add({
        'name': name,
        'description': description ?? '',
        'type': type,
        'category': category,
        'status': tournamentPending,
        'maxParticipants': maxParticipants,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
        'participants': [],
        'matches': [],
        'bracket': null,
        'settings': {
          'allowSpectators': true,
          'showLeaderboard': true,
        },
      });

      if (category == tournamentCategorySocial) {
        // Sosyal turnuva için premium kontrolü
        // TEMPORARY: Premium system disabled - allow all social tournaments
        // final canCreateSocial =
        //     await _premiumService.canCreateSocialTournament();
        // if (!canCreateSocial) {
        //   throw Exception(
        //       'PREMIUM_REQUIRED:Sosyal turnuva oluşturmak için Premium\'a yükseltmeniz gerekiyor.');
        // }

        // Yaratıcıyı katılımcı olarak ekle
        await _addParticipant(
            tournamentRef.id, currentUser.uid, participantAccepted);

        // Davetleri gönder (sadece sosyal turnuvalar için)
        if (invitedFriends != null) {
          for (final friendId in invitedFriends) {
            await _sendTournamentInvitation(tournamentRef.id, friendId);
          }
        }
      } else if (category == tournamentCategoryPersonal) {
        // Kişisel turnuvalar için seçilen oyuncuları direkt katılımcı olarak ekle
        if (selectedPlayers != null) {
          for (final playerId in selectedPlayers) {
            await _addPersonalParticipant(tournamentRef.id, playerId);
          }
        }
      }

      _logService.info('Tournament created: ${tournamentRef.id}',
          tag: 'Tournament');
      return tournamentRef.id;
    } catch (e) {
      _logService.error('Failed to create tournament',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Turnuva listesini getir (kategori bazında)
  Stream<List<Map<String, dynamic>>> getTournaments({String? category}) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    Query query = _firestore.collection('tournaments');

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    // Social turnuvalar: kullanıcı ID'si participants'ta
    // Personal turnuvalar: kullanıcının oluşturduğu turnuvalar
    if (category == tournamentCategorySocial) {
      query = query.where('participants', arrayContains: currentUser.uid);
    } else if (category == tournamentCategoryPersonal) {
      query = query.where('createdBy', isEqualTo: currentUser.uid);
    } else {
      // Tüm turnuvalar: kullanıcının katıldığı social + oluşturduğu personal
      query = _firestore.collection('tournaments');
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final tournaments = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tournamentCategory = data['category'] ?? tournamentCategorySocial;

        // Filter logic for mixed query (when category is null)
        if (category == null) {
          if (tournamentCategory == tournamentCategorySocial) {
            final participants = data['participants'] as List<dynamic>? ?? [];
            if (!participants.contains(currentUser.uid)) continue;
          } else if (tournamentCategory == tournamentCategoryPersonal) {
            if (data['createdBy'] != currentUser.uid) continue;
          }
        }

        // Yaratıcı bilgilerini al
        final createdByDoc =
            await _firestore.collection('users').doc(data['createdBy']).get();

        final createdByData = createdByDoc.exists ? createdByDoc.data()! : {};

        // Katılımcı sayısını hesapla
        final participants = data['participants'] as List<dynamic>? ?? [];
        final participantCount = participants.length;

        tournaments.add({
          'id': doc.id,
          'name': data['name'],
          'description': data['description'],
          'type': data['type'],
          'category': tournamentCategory,
          'status': data['status'],
          'maxParticipants': data['maxParticipants'],
          'participantCount': participantCount,
          'createdBy': data['createdBy'],
          'createdByName': createdByData['username'] ?? 'Bilinmeyen',
          'createdAt': data['createdAt'],
          'startDate': data['startDate'],
          'isCreator': data['createdBy'] == currentUser.uid,
        });
      }

      return tournaments;
    });
  }

  /// Turnuva davetlerini getir
  Stream<List<Map<String, dynamic>>> getTournamentInvitations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('tournament_invitations')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: participantPending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final invitations = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Turnuva bilgilerini al
        final tournamentDoc = await _firestore
            .collection('tournaments')
            .doc(data['tournamentId'])
            .get();

        if (!tournamentDoc.exists) continue;

        final tournamentData = tournamentDoc.data()!;

        // Gönderen bilgilerini al
        final fromUserDoc =
            await _firestore.collection('users').doc(data['fromUserId']).get();

        final fromUserData = fromUserDoc.exists ? fromUserDoc.data()! : {};

        invitations.add({
          'id': doc.id,
          'tournamentId': data['tournamentId'],
          'tournamentName': tournamentData['name'],
          'tournamentType': tournamentData['type'],
          'tournamentDescription': tournamentData['description'],
          'fromUserId': data['fromUserId'],
          'fromUserName': fromUserData['username'] ?? 'Bilinmeyen',
          'createdAt': data['createdAt'],
          'maxParticipants': tournamentData['maxParticipants'],
          'participantCount':
              (tournamentData['participants'] as List<dynamic>?)?.length ?? 0,
        });
      }

      return invitations;
    });
  }

  /// Turnuva davetini kabul et
  Future<void> acceptTournamentInvitation(String invitationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Davet bilgilerini al
      final invitationDoc = await _firestore
          .collection('tournament_invitations')
          .doc(invitationId)
          .get();

      if (!invitationDoc.exists) {
        throw Exception('Davet bulunamadı');
      }

      final invitationData = invitationDoc.data()!;

      if (invitationData['toUserId'] != currentUser.uid) {
        throw Exception('Bu daveti kabul etme yetkiniz yok');
      }

      final tournamentId = invitationData['tournamentId'];

      // Turnuva bilgilerini kontrol et
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        throw Exception('Turnuva bulunamadı');
      }

      final tournamentData = tournamentDoc.data()!;

      if (tournamentData['status'] != tournamentPending) {
        throw Exception('Bu turnuva artık katılıma açık değil');
      }

      final participants =
          tournamentData['participants'] as List<dynamic>? ?? [];
      if (participants.length >= tournamentData['maxParticipants']) {
        throw Exception('Turnuva dolu');
      }

      // Katılımcı olarak ekle
      await _addParticipant(tournamentId, currentUser.uid, participantAccepted);

      // Davet durumunu güncelle
      await _firestore
          .collection('tournament_invitations')
          .doc(invitationId)
          .update({
        'status': participantAccepted,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Turnuva yaratıcısına bildirim gönder
      await _sendTournamentNotification(
        tournamentData['createdBy'],
        currentUser.uid,
        'tournament_joined',
        tournamentData['name'],
      );

      _logService.info('Tournament invitation accepted: $invitationId',
          tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to accept tournament invitation',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Turnuva davetini reddet
  Future<void> declineTournamentInvitation(String invitationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      await _firestore
          .collection('tournament_invitations')
          .doc(invitationId)
          .update({
        'status': participantDeclined,
        'declinedAt': FieldValue.serverTimestamp(),
      });

      _logService.info('Tournament invitation declined: $invitationId',
          tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to decline tournament invitation',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Turnuvayı başlat
  Future<void> startTournament(String tournamentId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Turnuva bilgilerini al
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        throw Exception('Turnuva bulunamadı');
      }

      final tournamentData = tournamentDoc.data()!;

      if (tournamentData['createdBy'] != currentUser.uid) {
        throw Exception('Bu turnuvayı başlatma yetkiniz yok');
      }

      if (tournamentData['status'] != tournamentPending) {
        throw Exception('Bu turnuva zaten başlatılmış');
      }

      final participants =
          tournamentData['participants'] as List<dynamic>? ?? [];
      if (participants.length < 2) {
        throw Exception('Turnuva başlatmak için en az 2 katılımcı gereklidir');
      }

      // Bracket oluştur
      final bracket =
          await _createBracket(tournamentData['type'], participants);

      // Turnuvayı başlat
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'status': tournamentActive,
        'startedAt': FieldValue.serverTimestamp(),
        'bracket': bracket,
      });

      // Katılımcılara bildirim gönder
      for (final participantId in participants) {
        if (participantId != currentUser.uid) {
          await _sendTournamentNotification(
            participantId,
            currentUser.uid,
            'tournament_started',
            tournamentData['name'],
          );
        }
      }

      _logService.info('Tournament started: $tournamentId', tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to start tournament',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Turnuva daveti gönder
  Future<void> _sendTournamentInvitation(
      String tournamentId, String toUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Zaten davet var mı kontrol et
      final existingInvitation = await _firestore
          .collection('tournament_invitations')
          .where('tournamentId', isEqualTo: tournamentId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: participantPending)
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        return; // Zaten davet var
      }

      // Davet oluştur
      await _firestore.collection('tournament_invitations').add({
        'tournamentId': tournamentId,
        'fromUserId': currentUser.uid,
        'toUserId': toUserId,
        'status': participantPending,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Bildirim gönder
      await _sendTournamentNotification(
        toUserId,
        currentUser.uid,
        'tournament_invitation',
        '',
      );
    } catch (e) {
      _logService.error('Failed to send tournament invitation',
          tag: 'Tournament', error: e);
    }
  }

  /// Katılımcı ekle
  Future<void> _addParticipant(
      String tournamentId, String userId, String status) async {
    await _firestore.collection('tournaments').doc(tournamentId).update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  /// Kişisel turnuva katılımcısı ekle (player)
  Future<void> _addPersonalParticipant(
      String tournamentId, String playerId) async {
    await _firestore.collection('tournaments').doc(tournamentId).update({
      'participants': FieldValue.arrayUnion([playerId]),
    });
  }

  /// Bracket oluştur
  Future<Map<String, dynamic>> _createBracket(
      String type, List<dynamic> participants) async {
    if (type == tournamentTypeElimination) {
      return _createEliminationBracket(participants);
    } else if (type == tournamentTypeRoundRobin) {
      return _createRoundRobinBracket(participants);
    }

    throw Exception('Bilinmeyen turnuva tipi');
  }

  /// Eleme bracketi oluştur
  Map<String, dynamic> _createEliminationBracket(List<dynamic> participants) {
    final shuffledParticipants = List.from(participants)..shuffle();
    final rounds = <Map<String, dynamic>>[];

    // İlk round
    final firstRoundMatches = <Map<String, dynamic>>[];
    for (int i = 0; i < shuffledParticipants.length; i += 2) {
      firstRoundMatches.add({
        'id': 'match_${i ~/ 2}',
        'player1': shuffledParticipants[i],
        'player2': i + 1 < shuffledParticipants.length
            ? shuffledParticipants[i + 1]
            : null,
        'winner': null,
        'status': 'pending',
        'round': 1,
      });
    }

    rounds.add({
      'roundNumber': 1,
      'matches': firstRoundMatches,
    });

    return {
      'type': 'elimination',
      'rounds': rounds,
      'currentRound': 1,
      'totalRounds': _calculateTotalRounds(shuffledParticipants.length),
    };
  }

  /// Round robin bracketi oluştur
  Map<String, dynamic> _createRoundRobinBracket(List<dynamic> participants) {
    final matches = <Map<String, dynamic>>[];
    int matchId = 0;

    for (int i = 0; i < participants.length; i++) {
      for (int j = i + 1; j < participants.length; j++) {
        matches.add({
          'id': 'match_${matchId++}',
          'player1': participants[i],
          'player2': participants[j],
          'winner': null,
          'status': 'pending',
        });
      }
    }

    return {
      'type': 'round_robin',
      'matches': matches,
      'standings': participants
          .map((p) => {
                'playerId': p,
                'wins': 0,
                'losses': 0,
                'points': 0,
              })
          .toList(),
    };
  }

  /// Toplam round sayısını hesapla
  int _calculateTotalRounds(int participantCount) {
    if (participantCount <= 1) return 0;
    return (participantCount - 1).bitLength;
  }

  /// Maç sonucunu kaydet
  Future<void> recordMatchResult(
    String tournamentId,
    String matchId,
    String winnerId,
    int winnerScore,
    int loserScore,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Turnuva bilgilerini al
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        throw Exception('Turnuva bulunamadı');
      }

      final tournamentData = tournamentDoc.data()!;

      // Sadece turnuva yaratıcısı maç sonucu girebilir
      if (tournamentData['createdBy'] != currentUser.uid) {
        throw Exception('Bu turnuvada maç sonucu girme yetkiniz yok');
      }

      if (tournamentData['status'] != tournamentActive) {
        throw Exception('Turnuva aktif değil');
      }

      // Bracket'i güncelle
      final bracket = Map<String, dynamic>.from(tournamentData['bracket']);
      await _updateMatchResult(
          bracket, matchId, winnerId, winnerScore, loserScore);

      // Firestore'u güncelle
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'bracket': bracket,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Turnuva bitip bitmediğini kontrol et
      await _checkTournamentComplete(tournamentId, bracket);

      _logService.info('Match result recorded: $matchId', tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to record match result',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Bracket'te maç sonucunu güncelle
  Future<void> _updateMatchResult(
    Map<String, dynamic> bracket,
    String matchId,
    String winnerId,
    int winnerScore,
    int loserScore,
  ) async {
    if (bracket['type'] == 'elimination') {
      await _updateEliminationMatchResult(
          bracket, matchId, winnerId, winnerScore, loserScore);
    } else if (bracket['type'] == 'round_robin') {
      await _updateRoundRobinMatchResult(
          bracket, matchId, winnerId, winnerScore, loserScore);
    }
  }

  /// Eleme turnuvasında maç sonucunu güncelle
  Future<void> _updateEliminationMatchResult(
    Map<String, dynamic> bracket,
    String matchId,
    String winnerId,
    int winnerScore,
    int loserScore,
  ) async {
    final rounds = bracket['rounds'] as List<dynamic>;

    // Maçı bul ve güncelle
    for (final round in rounds) {
      final matches = round['matches'] as List<dynamic>;
      final matchIndex = matches.indexWhere((m) => m['id'] == matchId);

      if (matchIndex != -1) {
        final match = matches[matchIndex];
        matches[matchIndex] = {
          ...match,
          'winner': winnerId,
          'winnerScore': winnerScore,
          'loserScore': loserScore,
          'status': 'completed',
          'completedAt': Timestamp.fromDate(DateTime.now()),
        };

        // Bir sonraki tura geçir
        await _advanceWinnerToNextRound(
            bracket, winnerId, round['roundNumber']);
        break;
      }
    }
  }

  /// Round robin turnuvasında maç sonucunu güncelle
  Future<void> _updateRoundRobinMatchResult(
    Map<String, dynamic> bracket,
    String matchId,
    String winnerId,
    int winnerScore,
    int loserScore,
  ) async {
    final matches = bracket['matches'] as List<dynamic>;
    final standings = bracket['standings'] as List<dynamic>;

    // Maçı bul ve güncelle
    final matchIndex = matches.indexWhere((m) => m['id'] == matchId);

    if (matchIndex != -1) {
      final match = matches[matchIndex];
      final loserId =
          match['player1'] == winnerId ? match['player2'] : match['player1'];

      matches[matchIndex] = {
        ...match,
        'winner': winnerId,
        'winnerScore': winnerScore,
        'loserScore': loserScore,
        'status': 'completed',
        'completedAt': Timestamp.fromDate(DateTime.now()),
      };

      // Standings'i güncelle
      await _updateStandings(standings, winnerId, loserId);
    }
  }

  /// Kazananı bir sonraki tura geçir
  Future<void> _advanceWinnerToNextRound(
    Map<String, dynamic> bracket,
    String winnerId,
    int currentRound,
  ) async {
    final rounds = bracket['rounds'] as List<dynamic>;
    final totalRounds = bracket['totalRounds'] as int;

    if (currentRound < totalRounds) {
      // Mevcut round'daki tüm maçların tamamlanıp tamamlanmadığını kontrol et
      final currentRoundData =
          rounds.firstWhere((r) => r['roundNumber'] == currentRound);
      final currentRoundMatches = currentRoundData['matches'] as List<dynamic>;
      final completedMatches =
          currentRoundMatches.where((m) => m['status'] == 'completed').toList();

      // Mevcut round'daki tüm maçlar tamamlanmışsa, bir sonraki round'u oluştur
      if (completedMatches.length == currentRoundMatches.length) {
        // Sonraki round'u bul veya oluştur
        final nextRoundIndex =
            rounds.indexWhere((r) => r['roundNumber'] == currentRound + 1);

        if (nextRoundIndex == -1) {
          // Tüm kazananları topla
          final winners =
              completedMatches.map((match) => match['winner']).toList();

          // Sonraki round'un maçlarını oluştur
          final nextRoundMatches = <Map<String, dynamic>>[];
          for (int i = 0; i < winners.length; i += 2) {
            if (i + 1 < winners.length) {
              nextRoundMatches.add({
                'id': 'match_${currentRound + 1}_${i ~/ 2}',
                'player1': winners[i],
                'player2': winners[i + 1],
                'winner': null,
                'status': 'pending',
                'round': currentRound + 1,
              });
            }
          }

          // Sonraki round'u ekle
          rounds.add({
            'roundNumber': currentRound + 1,
            'matches': nextRoundMatches,
          });

          // Current round'u güncelle
          bracket['currentRound'] = currentRound + 1;
        }
      }
    }
  }

  /// Standings'i güncelle
  Future<void> _updateStandings(
    List<dynamic> standings,
    String winnerId,
    String loserId,
  ) async {
    // Kazanan için
    final winnerIndex = standings.indexWhere((s) => s['playerId'] == winnerId);
    if (winnerIndex != -1) {
      standings[winnerIndex] = {
        ...standings[winnerIndex],
        'wins': (standings[winnerIndex]['wins'] ?? 0) + 1,
        'points': (standings[winnerIndex]['points'] ?? 0) + 3,
      };
    }

    // Kaybeden için
    final loserIndex = standings.indexWhere((s) => s['playerId'] == loserId);
    if (loserIndex != -1) {
      standings[loserIndex] = {
        ...standings[loserIndex],
        'losses': (standings[loserIndex]['losses'] ?? 0) + 1,
      };
    }
  }

  /// Turnuva bitip bitmediğini kontrol et
  Future<void> _checkTournamentComplete(
    String tournamentId,
    Map<String, dynamic> bracket,
  ) async {
    bool isComplete = false;

    if (bracket['type'] == 'elimination') {
      // Eleme turnuvasında final maçının bitip bitmediğini kontrol et
      final rounds = bracket['rounds'] as List<dynamic>;
      if (rounds.isNotEmpty) {
        final finalRound = rounds.last;
        final finalMatches = finalRound['matches'] as List<dynamic>;

        // Final round'da en az 1 maç olmalı ve hepsi tamamlanmış olmalı
        isComplete = finalMatches.isNotEmpty &&
            finalMatches.every((match) => match['status'] == 'completed');
      }
    } else if (bracket['type'] == 'round_robin') {
      // Round robin'de manuel bitiş kontrolü
      // Turnuva sadece kullanıcı manuel olarak bitirdiğinde biter
      // Otomatik bitiş için minimum maç sayısı kontrolü yapmayız

      // Turnuva bilgilerini al
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (tournamentDoc.exists) {
        final tournamentData = tournamentDoc.data()!;
        // Sadece explicit olarak 'completed' status'u verilmişse bitir
        isComplete = tournamentData['status'] == tournamentCompleted;
      }
    }

    if (isComplete) {
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'status': tournamentCompleted,
        'completedAt': FieldValue.serverTimestamp(),
      });

      _logService.info('Tournament completed: $tournamentId',
          tag: 'Tournament');
    }
  }

  /// Turnuva detaylarını getir
  Future<Map<String, dynamic>?> getTournamentDetails(
      String tournamentId) async {
    try {
      final doc =
          await _firestore.collection('tournaments').doc(tournamentId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      _logService.error('Failed to get tournament details',
          tag: 'Tournament', error: e);
      return null;
    }
  }

  /// Turnuvayı manuel olarak bitir
  Future<void> finishTournament(String tournamentId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Turnuva bilgilerini al
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        throw Exception('Turnuva bulunamadı');
      }

      final tournamentData = tournamentDoc.data()!;

      // Sadece turnuva yaratıcısı bitirebilir
      if (tournamentData['createdBy'] != currentUser.uid) {
        throw Exception('Bu turnuvayı bitirme yetkiniz yok');
      }

      if (tournamentData['status'] != tournamentActive) {
        throw Exception('Turnuva zaten bitmiş veya aktif değil');
      }

      // Turnuva durumunu güncelle
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'status': tournamentCompleted,
        'completedAt': FieldValue.serverTimestamp(),
      });

      _logService.info('Tournament manually finished: $tournamentId',
          tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to finish tournament',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Turnuvayı düzenle
  Future<void> editTournament(
    String tournamentId, {
    String? name,
    String? description,
    int? maxParticipants,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Turnuva bilgilerini al
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        throw Exception('Turnuva bulunamadı');
      }

      final tournamentData = tournamentDoc.data()!;

      // Sadece turnuva yaratıcısı düzenleyebilir
      if (tournamentData['createdBy'] != currentUser.uid) {
        throw Exception('Bu turnuvayı düzenleme yetkiniz yok');
      }

      // Güncellenecek alanları hazırla
      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (name != null && name.isNotEmpty) {
        updates['name'] = name;
      }

      if (description != null) {
        updates['description'] = description;
      }

      if (maxParticipants != null && maxParticipants > 0) {
        final participants =
            tournamentData['participants'] as List<dynamic>? ?? [];

        // Mevcut katılımcı sayısından az olamaz
        if (maxParticipants < participants.length) {
          throw Exception(
              'Maksimum katılımcı sayısı mevcut katılımcı sayısından ($participants.length) az olamaz');
        }

        updates['maxParticipants'] = maxParticipants;
      }

      // Güncellemeyi uygula
      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .update(updates);

      _logService.info('Tournament edited: $tournamentId', tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to edit tournament',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Turnuvayı sil
  Future<void> deleteTournament(String tournamentId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Turnuva bilgilerini al
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        throw Exception('Turnuva bulunamadı');
      }

      final tournamentData = tournamentDoc.data()!;

      // Sadece turnuva yaratıcısı silebilir
      if (tournamentData['createdBy'] != currentUser.uid) {
        throw Exception('Bu turnuvayı silme yetkiniz yok');
      }

      // Batch işlem başlat
      final batch = _firestore.batch();

      // Turnuva davetlerini sil
      final invitationsQuery = await _firestore
          .collection('tournament_invitations')
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      for (final doc in invitationsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Turnuva bildirimlerini sil
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      for (final doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Turnuvayı sil
      batch.delete(_firestore.collection('tournaments').doc(tournamentId));

      // Batch işlemi uygula
      await batch.commit();

      _logService.info('Tournament deleted: $tournamentId', tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to delete tournament',
          tag: 'Tournament', error: e);
      rethrow;
    }
  }

  /// Turnuva maçlarını getir
  Stream<List<Map<String, dynamic>>> getTournamentMatches(String tournamentId) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) return [];

      final data = doc.data()!;
      final bracket = data['bracket'] as Map<String, dynamic>?;
      final tournamentCategory = data['category'] ?? tournamentCategorySocial;

      if (bracket == null) return [];

      final matches = <Map<String, dynamic>>[];

      if (bracket['type'] == 'elimination') {
        final rounds = bracket['rounds'] as List<dynamic>? ?? [];
        for (final round in rounds) {
          final roundMatches = round['matches'] as List<dynamic>? ?? [];
          for (final match in roundMatches) {
            matches.add({
              ...match,
              'round': round['roundNumber'],
            });
          }
        }
      } else if (bracket['type'] == 'round_robin') {
        final roundRobinMatches = bracket['matches'] as List<dynamic>? ?? [];
        matches.addAll(roundRobinMatches.cast<Map<String, dynamic>>());
      }

      // Kişisel turnuvalar için oyuncu ID'lerini isimlerine çevir
      if (tournamentCategory == tournamentCategoryPersonal) {
        for (int i = 0; i < matches.length; i++) {
          final match = matches[i];

          // Player1 ismini al
          if (match['player1'] != null) {
            final player1Name = await _getPlayerName(match['player1']);
            match['player1Name'] = player1Name;
          }

          // Player2 ismini al
          if (match['player2'] != null) {
            final player2Name = await _getPlayerName(match['player2']);
            match['player2Name'] = player2Name;
          }

          // Winner ismini al
          if (match['winner'] != null) {
            final winnerName = await _getPlayerName(match['winner']);
            match['winnerName'] = winnerName;
          }
        }
      } else {
        // Sosyal turnuvalar için user ID'lerini username'lere çevir
        for (int i = 0; i < matches.length; i++) {
          final match = matches[i];

          // Player1 ismini al
          if (match['player1'] != null) {
            final player1Name = await _getUserName(match['player1']);
            match['player1Name'] = player1Name;
          }

          // Player2 ismini al
          if (match['player2'] != null) {
            final player2Name = await _getUserName(match['player2']);
            match['player2Name'] = player2Name;
          }

          // Winner ismini al
          if (match['winner'] != null) {
            final winnerName = await _getUserName(match['winner']);
            match['winnerName'] = winnerName;
          }
        }
      }

      return matches;
    });
  }

  /// Oyuncu ismini getir
  Future<String> _getPlayerName(String playerId) async {
    try {
      final doc = await _firestore.collection('players').doc(playerId).get();
      if (doc.exists) {
        return doc.data()!['name'] ?? 'Bilinmeyen Oyuncu';
      }
      return 'Bilinmeyen Oyuncu';
    } catch (e) {
      return 'Bilinmeyen Oyuncu';
    }
  }

  /// Kullanıcı ismini getir
  Future<String> _getUserName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()!['username'] ?? 'Bilinmeyen Kullanıcı';
      }
      return 'Bilinmeyen Kullanıcı';
    } catch (e) {
      return 'Bilinmeyen Kullanıcı';
    }
  }

  /// Turnuva bildirimi gönder
  Future<void> _sendTournamentNotification(String toUserId, String fromUserId,
      String type, String tournamentName) async {
    try {
      // Gönderen kullanıcı bilgilerini al
      final fromUserDoc =
          await _firestore.collection('users').doc(fromUserId).get();
      if (!fromUserDoc.exists) return;

      final fromUserData = fromUserDoc.data()!;
      final fromUserName = fromUserData['username'] ?? 'Bilinmeyen Kullanıcı';

      // Alıcının bildirim tercihlerini kontrol et
      final toUserDoc =
          await _firestore.collection('users').doc(toUserId).get();
      if (!toUserDoc.exists) return;

      final toUserData = toUserDoc.data()!;
      if (toUserData['socialNotifications'] != true) return;

      String title;
      String body;
      String payload;

      switch (type) {
        case 'tournament_invitation':
          title = 'Turnuva Daveti';
          body = '$fromUserName size turnuva daveti gönderdi';
          payload = 'tournament_invitation:$fromUserId';
          break;
        case 'tournament_joined':
          title = 'Turnuva Katılımı';
          body = '$fromUserName "$tournamentName" turnuvasına katıldı';
          payload = 'tournament_joined:$fromUserId';
          break;
        case 'tournament_started':
          title = 'Turnuva Başladı';
          body = '"$tournamentName" turnuvası başladı';
          payload = 'tournament_started:$fromUserId';
          break;
        default:
          return;
      }

      // Firebase'e bildirim kaydı yap
      await _firestore.collection('notifications').add({
        'userId': toUserId,
        'title': title,
        'body': body,
        'type': 'tournament',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'payload': payload,
          'source': 'tournament',
          'fromUserId': fromUserId,
          'fromUserName': fromUserName,
          'type': type,
          'tournamentName': tournamentName,
        },
      });

      _logService.info('Tournament notification saved to Firebase',
          tag: 'Tournament');
    } catch (e) {
      _logService.error('Failed to send tournament notification',
          tag: 'Tournament', error: e);
    }
  }
}
