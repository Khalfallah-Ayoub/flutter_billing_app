import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/invoice/domain/entities/invoice_item.dart';
import 'package:billing_app/features/expense/domain/entities/expense.dart';
import 'package:billing_app/features/expense/presentation/bloc/expense_bloc.dart';

void main() {
  group('Profit and Expenses Financial Tracking Tests', () {
    test('Product entity correctly calculates profit per unit', () {
      const product = Product(
        id: 'p1',
        name: 'كوع نحاس 1/2',
        barcode: '12345',
        price: 250.0, // Selling Price
        costPrice: 150.0, // Purchase Cost
      );

      expect(product.profitPerUnit, equals(100.0));
    });

    test('InvoiceItem calculates item total cost and line gross profit', () {
      const item = InvoiceItem(
        productId: 'p1',
        productName: 'أنبوب PVC 110mm',
        barcode: '54321',
        unitPrice: 500.0, // Selling price per meter
        costPrice: 350.0, // Cost price per meter
        quantity: 10.0, // 10 meters
        subtotal: 5000.0,
        isPipe: true,
      );

      expect(item.itemCostTotal, equals(3500.0)); // 350 * 10
      expect(item.itemGrossProfit, equals(1500.0)); // 5000 - 3500
    });

    test('ExpenseState calculates correct today and total amounts', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final expenses = [
        Expense(
          id: 'e1',
          title: 'غداء العمال',
          amount: 1200.0,
          category: 'وجبات وعمال',
          date: now,
        ),
        Expense(
          id: 'e2',
          title: 'وقود شاحنة النقل',
          amount: 800.0,
          category: 'نقل وشحن',
          date: now,
        ),
        Expense(
          id: 'e3',
          title: 'صيانة قاطعة الأنابيب',
          amount: 2500.0,
          category: 'صيانة وإصلاح',
          date: yesterday,
        ),
      ];

      final state = ExpenseState(expenses: expenses);

      expect(state.totalExpenseAmount, equals(4500.0)); // 1200 + 800 + 2500
      expect(state.todayExpenseAmount, equals(2000.0)); // 1200 + 800
    });

    test('Net Profit Calculation Formula operates accurately', () {
      const grossRevenue = 15000.0;
      const totalCostOfGoods = 9000.0;
      const grossProfit = grossRevenue - totalCostOfGoods; // 6000.0
      const totalExpenses = 2000.0;

      const netProfit = grossProfit - totalExpenses; // 4000.0
      const marginPercent = (netProfit / grossRevenue) * 100;

      expect(grossProfit, equals(6000.0));
      expect(netProfit, equals(4000.0));
      expect(marginPercent, closeTo(26.66, 0.01));
    });
  });
}
