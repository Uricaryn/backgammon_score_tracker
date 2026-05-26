class DiceRoll {
  const DiceRoll({
    required this.die1,
    required this.die2,
  });

  final int die1;
  final int die2;

  bool get isDouble => die1 == die2;

  List<int> toMoves() => isDouble ? [die1, die1, die1, die1] : [die1, die2];

  Map<String, dynamic> toMap() {
    return {
      'die1': die1,
      'die2': die2,
      'isDouble': isDouble,
    };
  }

  factory DiceRoll.fromMap(Map<String, dynamic> map) {
    return DiceRoll(
      die1: (map['die1'] as num?)?.toInt() ?? 1,
      die2: (map['die2'] as num?)?.toInt() ?? 1,
    );
  }
}
