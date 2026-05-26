enum PlayerColor { white, black }

enum GameStatus { waiting, openingRoll, active, finished }

enum WinType { normal, mars, kapiMarsi }

class GameState {
  const GameState({
    required this.points,
    required this.bar,
    required this.borneOff,
    required this.currentTurn,
    required this.remainingDice,
    required this.status,
    required this.version,
    this.winner,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.lastMoveHit = false,
    this.lastMoveBearOff = false,
    this.lastMovePlayer,
    this.winType,
    this.openingRollWhite,
    this.openingRollBlack,
    this.openingShowWhite,
    this.openingShowBlack,
    this.openingShowFirst,
    this.turnUndoPoints,
    this.turnUndoBar,
    this.turnUndoBorneOff,
    this.turnUndoDice,
  });

  final List<int> points;
  final Map<PlayerColor, int> bar;
  final Map<PlayerColor, int> borneOff;
  final PlayerColor currentTurn;
  final List<int> remainingDice;
  final GameStatus status;
  final int version;
  final PlayerColor? winner;
  final int? lastMoveFrom;
  final int? lastMoveTo;
  final bool lastMoveHit;
  final bool lastMoveBearOff;
  final PlayerColor? lastMovePlayer;
  final WinType? winType;
  final int? openingRollWhite;
  final int? openingRollBlack;

  /// Açılış zarı sonucu (oyun [GameStatus.active] olduktan sonra bilgi amaçlı;
  /// ilk hamleden sonra temizlenir).
  final int? openingShowWhite;
  final int? openingShowBlack;
  final PlayerColor? openingShowFirst;

  /// Snapshot at start of current turn (after dice are set); used for undo.
  final List<int>? turnUndoPoints;
  final Map<PlayerColor, int>? turnUndoBar;
  final Map<PlayerColor, int>? turnUndoBorneOff;
  final List<int>? turnUndoDice;

  static GameState initial() {
    final points = List<int>.filled(24, 0);
    points[23] = 2;
    points[12] = 5;
    points[7] = 3;
    points[5] = 5;
    points[0] = -2;
    points[11] = -5;
    points[16] = -3;
    points[18] = -5;
    return GameState(
      points: points,
      bar: const {PlayerColor.white: 0, PlayerColor.black: 0},
      borneOff: const {PlayerColor.white: 0, PlayerColor.black: 0},
      currentTurn: PlayerColor.white,
      remainingDice: const [],
      status: GameStatus.openingRoll,
      version: 0,
    );
  }

  GameState copyWith({
    List<int>? points,
    Map<PlayerColor, int>? bar,
    Map<PlayerColor, int>? borneOff,
    PlayerColor? currentTurn,
    List<int>? remainingDice,
    GameStatus? status,
    int? version,
    PlayerColor? winner,
    bool clearWinner = false,
    int? lastMoveFrom,
    int? lastMoveTo,
    bool? lastMoveHit,
    bool? lastMoveBearOff,
    PlayerColor? lastMovePlayer,
    bool clearLastMove = false,
    WinType? winType,
    bool clearWinType = false,
    int? openingRollWhite,
    int? openingRollBlack,
    bool clearOpeningRolls = false,
    int? openingShowWhite,
    int? openingShowBlack,
    PlayerColor? openingShowFirst,
    bool clearOpeningBanner = false,
    List<int>? turnUndoPoints,
    Map<PlayerColor, int>? turnUndoBar,
    Map<PlayerColor, int>? turnUndoBorneOff,
    List<int>? turnUndoDice,
    bool clearTurnUndo = false,
  }) {
    return GameState(
      points: points ?? this.points,
      bar: bar ?? this.bar,
      borneOff: borneOff ?? this.borneOff,
      currentTurn: currentTurn ?? this.currentTurn,
      remainingDice: remainingDice ?? this.remainingDice,
      status: status ?? this.status,
      version: version ?? this.version,
      winner: clearWinner ? null : (winner ?? this.winner),
      lastMoveFrom: clearLastMove ? null : (lastMoveFrom ?? this.lastMoveFrom),
      lastMoveTo: clearLastMove ? null : (lastMoveTo ?? this.lastMoveTo),
      lastMoveHit: clearLastMove ? false : (lastMoveHit ?? this.lastMoveHit),
      lastMoveBearOff: clearLastMove ? false : (lastMoveBearOff ?? this.lastMoveBearOff),
      lastMovePlayer: clearLastMove ? null : (lastMovePlayer ?? this.lastMovePlayer),
      winType: clearWinType ? null : (winType ?? this.winType),
      openingRollWhite: clearOpeningRolls ? null : (openingRollWhite ?? this.openingRollWhite),
      openingRollBlack: clearOpeningRolls ? null : (openingRollBlack ?? this.openingRollBlack),
      openingShowWhite: clearOpeningBanner ? null : (openingShowWhite ?? this.openingShowWhite),
      openingShowBlack: clearOpeningBanner ? null : (openingShowBlack ?? this.openingShowBlack),
      openingShowFirst: clearOpeningBanner ? null : (openingShowFirst ?? this.openingShowFirst),
      turnUndoPoints: clearTurnUndo ? null : (turnUndoPoints ?? this.turnUndoPoints),
      turnUndoBar: clearTurnUndo ? null : (turnUndoBar ?? this.turnUndoBar),
      turnUndoBorneOff: clearTurnUndo ? null : (turnUndoBorneOff ?? this.turnUndoBorneOff),
      turnUndoDice: clearTurnUndo ? null : (turnUndoDice ?? this.turnUndoDice),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'points': points,
      'bar': {
        'white': bar[PlayerColor.white] ?? 0,
        'black': bar[PlayerColor.black] ?? 0,
      },
      'borneOff': {
        'white': borneOff[PlayerColor.white] ?? 0,
        'black': borneOff[PlayerColor.black] ?? 0,
      },
      'currentTurn': currentTurn.name,
      'remainingDice': remainingDice,
      'status': status.name,
      'version': version,
      'winner': winner?.name,
      'lastMoveFrom': lastMoveFrom,
      'lastMoveTo': lastMoveTo,
      'lastMoveHit': lastMoveHit,
      'lastMoveBearOff': lastMoveBearOff,
      'lastMovePlayer': lastMovePlayer?.name,
      'winType': winType?.name,
      'openingRollWhite': openingRollWhite,
      'openingRollBlack': openingRollBlack,
      'openingShowWhite': openingShowWhite,
      'openingShowBlack': openingShowBlack,
      'openingShowFirst': openingShowFirst?.name,
      'turnUndoPoints': turnUndoPoints,
      'turnUndoBar': turnUndoBar == null
          ? null
          : {
              'white': turnUndoBar![PlayerColor.white] ?? 0,
              'black': turnUndoBar![PlayerColor.black] ?? 0,
            },
      'turnUndoBorneOff': turnUndoBorneOff == null
          ? null
          : {
              'white': turnUndoBorneOff![PlayerColor.white] ?? 0,
              'black': turnUndoBorneOff![PlayerColor.black] ?? 0,
            },
      'turnUndoDice': turnUndoDice,
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map) {
    final points = (map['points'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => (e as num).toInt())
        .toList();
    final safePoints = points.length == 24 ? points : List<int>.filled(24, 0);
    final barMap = (map['bar'] as Map<String, dynamic>?) ?? {};
    final borneOffMap = (map['borneOff'] as Map<String, dynamic>?) ?? {};
    final currentTurnRaw = (map['currentTurn'] as String?) ?? 'white';
    final statusRaw = (map['status'] as String?) ?? 'active';
    final winnerRaw = map['winner'] as String?;
    final lastMovePlayerRaw = map['lastMovePlayer'] as String?;
    return GameState(
      points: safePoints,
      bar: {
        PlayerColor.white: (barMap['white'] as num?)?.toInt() ?? 0,
        PlayerColor.black: (barMap['black'] as num?)?.toInt() ?? 0,
      },
      borneOff: {
        PlayerColor.white: (borneOffMap['white'] as num?)?.toInt() ?? 0,
        PlayerColor.black: (borneOffMap['black'] as num?)?.toInt() ?? 0,
      },
      currentTurn: currentTurnRaw == 'black' ? PlayerColor.black : PlayerColor.white,
      remainingDice: (map['remainingDice'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => (e as num).toInt())
          .toList(),
      status: GameStatus.values.firstWhere(
        (e) => e.name == statusRaw,
        orElse: () => GameStatus.active,
      ),
      version: (map['version'] as num?)?.toInt() ?? 0,
      winner: winnerRaw == null
          ? null
          : PlayerColor.values.firstWhere(
              (e) => e.name == winnerRaw,
              orElse: () => PlayerColor.white,
            ),
      lastMoveFrom: (map['lastMoveFrom'] as num?)?.toInt(),
      lastMoveTo: (map['lastMoveTo'] as num?)?.toInt(),
      lastMoveHit: map['lastMoveHit'] as bool? ?? false,
      lastMoveBearOff: map['lastMoveBearOff'] as bool? ?? false,
      lastMovePlayer: lastMovePlayerRaw == null
          ? null
          : PlayerColor.values.firstWhere(
              (e) => e.name == lastMovePlayerRaw,
              orElse: () => PlayerColor.white,
            ),
      winType: _parseWinType(map['winType'] as String?),
      openingRollWhite: (map['openingRollWhite'] as num?)?.toInt(),
      openingRollBlack: (map['openingRollBlack'] as num?)?.toInt(),
      openingShowWhite: (map['openingShowWhite'] as num?)?.toInt(),
      openingShowBlack: (map['openingShowBlack'] as num?)?.toInt(),
      openingShowFirst: _parsePlayerColor(map['openingShowFirst'] as String?),
      turnUndoPoints: (map['turnUndoPoints'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      turnUndoBar: _parseBarMap(map['turnUndoBar'] as Map<String, dynamic>?),
      turnUndoBorneOff: _parseBorneOffMap(map['turnUndoBorneOff'] as Map<String, dynamic>?),
      turnUndoDice: (map['turnUndoDice'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }

  static Map<PlayerColor, int>? _parseBarMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return {
      PlayerColor.white: (m['white'] as num?)?.toInt() ?? 0,
      PlayerColor.black: (m['black'] as num?)?.toInt() ?? 0,
    };
  }

  static Map<PlayerColor, int>? _parseBorneOffMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return {
      PlayerColor.white: (m['white'] as num?)?.toInt() ?? 0,
      PlayerColor.black: (m['black'] as num?)?.toInt() ?? 0,
    };
  }

  static PlayerColor? _parsePlayerColor(String? raw) {
    if (raw == null) return null;
    return PlayerColor.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PlayerColor.white,
    );
  }

  static WinType? _parseWinType(String? raw) {
    if (raw == null) return null;
    return WinType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WinType.normal,
    );
  }
}
