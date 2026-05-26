import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';

class MoveListPanel extends StatelessWidget {
  const MoveListPanel({
    super.key,
    required this.moves,
    required this.onMoveTap,
  });

  final List<Move> moves;
  final ValueChanged<Move> onMoveTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 180,
        child: moves.isEmpty
            ? const Center(child: Text('Bu zarla legal hamle yok.'))
            : ListView.builder(
                itemCount: moves.length,
                itemBuilder: (context, index) {
                  final move = moves[index];
                  final from = move.fromPoint == null ? 'BAR' : '${move.fromPoint}';
                  final to = move.toPoint == null ? 'OFF' : '${move.toPoint}';
                  return ListTile(
                    dense: true,
                    title: Text('$from -> $to'),
                    subtitle: Text('Zar ${move.dieUsed}'),
                    trailing: move.hit ? const Icon(Icons.flash_on, size: 18) : null,
                    onTap: () => onMoveTap(move),
                  );
                },
              ),
      ),
    );
  }
}
