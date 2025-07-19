import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_scoreboard_card.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final GuestDataService _guestDataService = GuestDataService();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isLoading = false;
  bool _isGuestUser = false;
  Map<String, dynamic>? _cachedGameData;

  @override
  void initState() {
    super.initState();
    _checkUserTypeAndLoadData();
  }

  void _checkUserTypeAndLoadData() async {
    setState(() => _isLoading = true);
    _isGuestUser = _firebaseService.isCurrentUserGuest();
    if (_isGuestUser) {
      final games = await _guestDataService.getGuestGames();
      _cachedGameData = {
        'timestamp': DateTime.now(),
        'data': games,
      };
    } else {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('games')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .get();
        _cachedGameData = {
          'timestamp': DateTime.now(),
          'data': snapshot.docs
              .map((doc) => {
                    ...doc.data(),
                    'id': doc.id,
                  })
              .toList(),
        };
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _shareScoreboard() async {
    try {
      // Ekran görüntüsü al
      final image = await _screenshotController.capture();
      if (image != null) {
        // Geçici dosya oluştur
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/scoreboard.png').create();
        await file.writeAsBytes(image);

        // Paylaş
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Tavla Skor Tablosu',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ekran görüntüsü alınamadı')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skorboard'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: HomeScoreboardCard(
                    cachedGameData: _cachedGameData,
                    isGuestUser: _isGuestUser,
                    screenshotController: _screenshotController,
                    onShare: _shareScoreboard,
                  ),
                ),
        ),
      ),
    );
  }
}
