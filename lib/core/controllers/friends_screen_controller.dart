import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/services/friendship_service.dart';

class FriendsScreenController extends ChangeNotifier {
  FriendsScreenController({FriendshipService? friendshipService})
      : _friendshipService = friendshipService ?? FriendshipService() {
    _friendsSub = _friendshipService.getFriends().listen(
      (value) {
        friends = value;
        friendsError = null;
        friendsLoading = false;
        notifyListeners();
      },
      onError: (error) {
        friendsError = error;
        friendsLoading = false;
        notifyListeners();
      },
    );
    _incomingSub = _friendshipService.getIncomingFriendRequests().listen(
      (value) {
        incomingRequests = value;
        incomingError = null;
        incomingLoading = false;
        notifyListeners();
      },
      onError: (error) {
        incomingError = error;
        incomingLoading = false;
        notifyListeners();
      },
    );
    _outgoingSub = _friendshipService.getOutgoingFriendRequests().listen(
      (value) {
        outgoingRequests = value;
        outgoingError = null;
        outgoingLoading = false;
        notifyListeners();
      },
      onError: (error) {
        outgoingError = error;
        outgoingLoading = false;
        notifyListeners();
      },
    );
  }

  final FriendshipService _friendshipService;
  StreamSubscription<List<Map<String, dynamic>>>? _friendsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _incomingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _outgoingSub;

  List<Map<String, dynamic>> friends = const [];
  List<Map<String, dynamic>> incomingRequests = const [];
  List<Map<String, dynamic>> outgoingRequests = const [];
  Object? friendsError;
  Object? incomingError;
  Object? outgoingError;
  bool friendsLoading = true;
  bool incomingLoading = true;
  bool outgoingLoading = true;

  @override
  void dispose() {
    _friendsSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    super.dispose();
  }
}
