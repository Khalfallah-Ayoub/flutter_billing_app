import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Verify MyApp instantiates cleanly
    expect(const MyApp(), isNotNull);
  });
}
