import 'package:flutter_test/flutter_test.dart';
import 'package:lal_bus/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LalBusApp());
  });
}
