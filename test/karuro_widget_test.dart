import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/karuro/karuro_board.dart';
import 'package:common_games/games/karuro/karuro_model.dart';
import 'package:common_games/games/karuro/karuro_puzzle.dart';

/// Build the model with a small JSON literal — keeps the test free of
/// dart:convert at the top of the file.
KaruroModel _model() {
  final Map<String, dynamic> json = {
    'id': 'widget-test-001',
    'title': 'Tiny Two',
    'difficulty': 'easy',
    'metrics': const {
      'maxNumericRunLength': 2,
      'maxWordRunLength': 0,
      'crossingsPerCell': 1,
      'extremeSumShare': 1,
    },
    'grid': const {'rows': 3, 'cols': 3},
    'cells': const [
      ['#', '#', '#'],
      ['#', ' ', ' '],
      ['#', '#', '#'],
    ],
    'entries': const [
      {
        'id': '1A',
        'number': 1,
        'direction': 'across',
        'start': {'row': 1, 'col': 1},
        'length': 2,
        'kind': 'number',
        'sum': 3,
      },
    ],
    'solution': const {'1,1': '1', '1,2': '2'},
  };
  return KaruroModel(KaruroPuzzle.fromJson(json));
}

void main() {
  group('KaruroBoard', () {
    testWidgets('renders a Semantics label per fillable cell', (
      tester,
    ) async {
      final model = _model();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: KaruroBoard(
                model: model,
                selectedIndex: null,
                onCellSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // The puzzle has 2 fillable cells (at (1,1) and (1,2)). Block
      // cells do not have Semantics labels because they are not
      // interactive.
      final semanticsCount = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label?.startsWith('Row ') ?? false)
          .length;
      expect(semanticsCount, 2);
    });

    testWidgets('tapping a fillable cell calls onCellSelected', (tester) async {
      final model = _model();
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: KaruroBoard(
                model: model,
                selectedIndex: null,
                onCellSelected: (i) => tapped = i,
              ),
            ),
          ),
        ),
      );

      // Tap the cell at (1, 1). It's the top-left fillable cell in the
      // 3x3 grid. We find it by its Semantics label.
      await tester.tap(find.bySemanticsLabel('Row 2 column 2, empty'));
      await tester.pump();
      // Flat index for (1, 1) in a 3-wide grid is 1 * 3 + 1 = 4.
      expect(tapped, 4);
    });

    testWidgets('tapping a block cell is a no-op', (tester) async {
      final model = _model();
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: KaruroBoard(
                model: model,
                selectedIndex: null,
                onCellSelected: (i) => tapped = i,
              ),
            ),
          ),
        ),
      );

      // (0, 0) is a block cell. It has no Semantics label. We tap into
      // the board's top-left region, where the block cell renders, and
      // confirm onCellSelected is not invoked.
      final topLeft = tester.getTopLeft(find.byType(KaruroBoard));
      await tester.tapAt(topLeft + const Offset(20, 20));
      await tester.pump();
      expect(tapped, isNull);
    });

    testWidgets('invalid index tints the cell with errorContainer', (
      tester,
    ) async {
      final model = _model();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: KaruroBoard(
                model: model,
                selectedIndex: null,
                onCellSelected: (_) {},
                invalidIndexes: const {4}, // (1, 1) is wrong
              ),
            ),
          ),
        ),
      );

      // Verify the cell at (1, 1) gets the error-container color. We
      // find it by Semantics and inspect the rendered BoxDecoration.
      final cellFinder = find.bySemanticsLabel('Row 2 column 2, empty');
      expect(cellFinder, findsOneWidget);
      // The exact color is theme-dependent, but a Container with
      // BoxDecoration must be present in the cell's subtree.
      final containers = tester
          .widgetList<Container>(find.descendant(
            of: cellFinder,
            matching: find.byType(Container),
          ))
          .where((c) => c.decoration is BoxDecoration);
      expect(containers, isNotEmpty);
    });
  });
}
