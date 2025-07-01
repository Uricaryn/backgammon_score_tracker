import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';

class GuestDataService {
  static final GuestDataService _instance = GuestDataService._internal();
  factory GuestDataService() => _instance;
  GuestDataService._internal();

  static const String _guestGamesKey = 'guest_games';
  static const String _guestPlayersKey = 'guest_players';
  static const String _guestDataMigratedKey = 'guest_data_migrated';
  static const String _migrationDialogShownKey = 'migration_dialog_shown';

  final LogService _logService = LogService();

  // Misafir oyunları kaydet
  Future<void> saveGuestGame({
    required String player1,
    required String player2,
    required int player1Score,
    required int player2Score,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gamesJson = prefs.getString(_guestGamesKey) ?? '[]';
      final games = List<Map<String, dynamic>>.from(jsonDecode(gamesJson));

      final newGame = {
        'player1': player1,
        'player2': player2,
        'player1Score': player1Score,
        'player2Score': player2Score,
        'timestamp': DateTime.now().toIso8601String(),
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      games.add(newGame);
      await prefs.setString(_guestGamesKey, jsonEncode(games));

      _logService.info('Misafir oyun kaydedildi: $player1 vs $player2',
          tag: 'GuestData');
    } catch (e) {
      _logService.error('Misafir oyun kaydedilemedi',
          tag: 'GuestData', error: e);
      throw Exception('Misafir oyun kaydedilemedi');
    }
  }

  // Misafir oyuncu kaydet
  Future<void> saveGuestPlayer(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playersJson = prefs.getString(_guestPlayersKey) ?? '[]';
      final players = List<Map<String, dynamic>>.from(jsonDecode(playersJson));

      // Oyuncu zaten var mı kontrol et
      final existingPlayer = players.any((player) => player['name'] == name);
      if (existingPlayer) {
        throw Exception('Bu isimde bir oyuncu zaten var');
      }

      final newPlayer = {
        'name': name,
        'createdAt': DateTime.now().toIso8601String(),
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      players.add(newPlayer);
      await prefs.setString(_guestPlayersKey, jsonEncode(players));

      _logService.info('Misafir oyuncu kaydedildi: $name', tag: 'GuestData');
    } catch (e) {
      _logService.error('Misafir oyuncu kaydedilemedi',
          tag: 'GuestData', error: e);
      throw Exception('Misafir oyuncu kaydedilemedi');
    }
  }

  // Misafir oyunları getir
  Future<List<Map<String, dynamic>>> getGuestGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gamesJson = prefs.getString(_guestGamesKey) ?? '[]';
      final games = List<Map<String, dynamic>>.from(jsonDecode(gamesJson));

      // Tarihe göre sırala (en yeni önce)
      games.sort((a, b) => DateTime.parse(b['timestamp'])
          .compareTo(DateTime.parse(a['timestamp'])));

      return games;
    } catch (e) {
      _logService.error('Misafir oyunlar getirilemedi',
          tag: 'GuestData', error: e);
      return [];
    }
  }

  // Misafir oyuncuları getir
  Future<List<Map<String, dynamic>>> getGuestPlayers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playersJson = prefs.getString(_guestPlayersKey) ?? '[]';
      final players = List<Map<String, dynamic>>.from(jsonDecode(playersJson));

      // İsme göre sırala
      players.sort((a, b) => a['name'].compareTo(b['name']));

      return players;
    } catch (e) {
      _logService.error('Misafir oyuncular getirilemedi',
          tag: 'GuestData', error: e);
      return [];
    }
  }

  // Misafir oyunu sil
  Future<void> deleteGuestGame(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gamesJson = prefs.getString(_guestGamesKey) ?? '[]';
      final games = List<Map<String, dynamic>>.from(jsonDecode(gamesJson));

      games.removeWhere((game) => game['id'] == gameId);
      await prefs.setString(_guestGamesKey, jsonEncode(games));

      _logService.info('Misafir oyun silindi: $gameId', tag: 'GuestData');
    } catch (e) {
      _logService.error('Misafir oyun silinemedi', tag: 'GuestData', error: e);
      throw Exception('Misafir oyun silinemedi');
    }
  }

  // Misafir oyuncu sil
  Future<void> deleteGuestPlayer(String playerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playersJson = prefs.getString(_guestPlayersKey) ?? '[]';
      final players = List<Map<String, dynamic>>.from(jsonDecode(playersJson));

      players.removeWhere((player) => player['id'] == playerId);
      await prefs.setString(_guestPlayersKey, jsonEncode(players));

      _logService.info('Misafir oyuncu silindi: $playerId', tag: 'GuestData');
    } catch (e) {
      _logService.error('Misafir oyuncu silinemedi',
          tag: 'GuestData', error: e);
      throw Exception('Misafir oyuncu silinemedi');
    }
  }

  // Misafir verileri Firebase'e aktar
  Future<void> migrateGuestDataToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      final prefs = await SharedPreferences.getInstance();
      final isMigrated = prefs.getBool(_guestDataMigratedKey) ?? false;

      if (isMigrated) {
        return; // Zaten aktarılmış
      }

      // Oyuncuları aktar
      final playersJson = prefs.getString(_guestPlayersKey) ?? '[]';
      final players = List<Map<String, dynamic>>.from(jsonDecode(playersJson));

      for (final player in players) {
        await FirebaseFirestore.instance.collection('players').add({
          'name': player['name'],
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Oyunları aktar
      final gamesJson = prefs.getString(_guestGamesKey) ?? '[]';
      final games = List<Map<String, dynamic>>.from(jsonDecode(gamesJson));

      for (final game in games) {
        await FirebaseFirestore.instance.collection('games').add({
          'player1': game['player1'],
          'player2': game['player2'],
          'player1Score': game['player1Score'],
          'player2Score': game['player2Score'],
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user.uid,
        });
      }

      // Aktarım tamamlandı olarak işaretle
      await prefs.setBool(_guestDataMigratedKey, true);

      // Misafir verileri temizle
      await prefs.remove(_guestGamesKey);
      await prefs.remove(_guestPlayersKey);

      _logService.info('Misafir veriler Firebase\'e aktarıldı',
          tag: 'GuestData');
    } catch (e) {
      _logService.error('Misafir veriler aktarılamadı',
          tag: 'GuestData', error: e);
      throw Exception('Veriler aktarılamadı');
    }
  }

  // Misafir veri var mı kontrol et
  Future<bool> hasGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gamesJson = prefs.getString(_guestGamesKey) ?? '[]';
      final playersJson = prefs.getString(_guestPlayersKey) ?? '[]';

      final games = List<Map<String, dynamic>>.from(jsonDecode(gamesJson));
      final players = List<Map<String, dynamic>>.from(jsonDecode(playersJson));

      return games.isNotEmpty || players.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Misafir verilerinin aktarılıp aktarılmadığını kontrol et
  Future<bool> isGuestDataMigrated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_guestDataMigratedKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  // Migration dialog'unun gösterilip gösterilmediğini kontrol et
  Future<bool> hasShownMigrationDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_migrationDialogShownKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  // Migration dialog'unun gösterildiğini işaretle
  Future<void> markMigrationDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationDialogShownKey, true);
      _logService.info('Migration dialog gösterildi olarak işaretlendi',
          tag: 'GuestData');
    } catch (e) {
      _logService.error('Migration dialog durumu kaydedilemedi',
          tag: 'GuestData', error: e);
    }
  }

  // Misafir verileri temizle
  Future<void> clearGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestGamesKey);
      await prefs.remove(_guestPlayersKey);
      await prefs.remove(_guestDataMigratedKey);
      await prefs.remove(_migrationDialogShownKey);

      _logService.info('Misafir veriler temizlendi', tag: 'GuestData');
    } catch (e) {
      _logService.error('Misafir veriler temizlenemedi',
          tag: 'GuestData', error: e);
    }
  }
}
