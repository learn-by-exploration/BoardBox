import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/main.dart';

void main() {
  testWidgets('App renders splash then navigates to home', (tester) async {
    await tester.pumpWidget(const CommonGamesApp());
    // Splash screen shows app name immediately.
    expect(find.text('Board Box'), findsOneWidget);

    // After the splash delay + transition, we land on home screen.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // At least the first game tile is visible in the grid.
    expect(find.text('Gomoku'), findsOneWidget);
  });
}
