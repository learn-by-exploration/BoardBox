import 'package:flutter/material.dart';

import 'package:common_games/games/minesweeper/minesweeper_model.dart';

/// The Minesweeper play screen. Built out in the next commit; this
/// stub is what the setup screen pushes to so the route compiles.
class MinesweeperGameScreen extends StatelessWidget {
  const MinesweeperGameScreen({super.key, required this.difficulty});

  final MinesweeperDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Minesweeper · ${difficulty.label}')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
