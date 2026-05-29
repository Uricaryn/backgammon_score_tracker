import 'package:cloud_firestore/cloud_firestore.dart';

class LiveGameMessage {
  const LiveGameMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final String userId;
  final String username;
  final String message;
  final DateTime? timestamp;

  factory LiveGameMessage.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final ts = data['timestamp'];
    DateTime? time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is String) {
      time = DateTime.tryParse(ts);
    }
    return LiveGameMessage(
      id: id,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? 'Oyuncu',
      message: data['message'] as String? ?? '',
      timestamp: time,
    );
  }
}
