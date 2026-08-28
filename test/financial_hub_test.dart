import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/analytics/presentation/pages/financial_hub_page.dart';

void main() {
  group('FinancialHubPage Tests', () {
    test('FinancialHubPage instantiates cleanly', () {
      const page = FinancialHubPage();
      expect(page, isNotNull);
    });
  });
}
