import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../invoice/presentation/bloc/invoice_bloc.dart';
import '../../../invoice/domain/entities/invoice.dart';
import '../../../expense/presentation/bloc/expense_bloc.dart';
import '../../../expense/domain/entities/expense.dart';
import '../../data/services/profit_report_pdf_service.dart';

class ProfitAnalyticsPage extends StatefulWidget {
  const ProfitAnalyticsPage({super.key});

  @override
  State<ProfitAnalyticsPage> createState() => _ProfitAnalyticsPageState();
}

class _ProfitAnalyticsPageState extends State<ProfitAnalyticsPage> {
  String _timeRange = 'today'; // 'today', 'week', 'month', 'all'

  List<Invoice> _filterInvoices(List<Invoice> allInvoices) {
    final now = DateTime.now();
    return allInvoices.where((inv) {
      if (_timeRange == 'today') {
        return inv.createdAt.year == now.year &&
            inv.createdAt.month == now.month &&
            inv.createdAt.day == now.day;
      } else if (_timeRange == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return inv.createdAt.isAfter(startOfDay);
      } else if (_timeRange == 'month') {
        return inv.createdAt.year == now.year && inv.createdAt.month == now.month;
      }
      return true; // 'all'
    }).toList();
  }

  List<Expense> _filterExpenses(List<Expense> allExpenses) {
    final now = DateTime.now();
    return allExpenses.where((exp) {
      if (_timeRange == 'today') {
        return exp.date.year == now.year &&
            exp.date.month == now.month &&
            exp.date.day == now.day;
      } else if (_timeRange == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return exp.date.isAfter(startOfDay);
      } else if (_timeRange == 'month') {
        return exp.date.year == now.year && exp.date.month == now.month;
      }
      return true; // 'all'
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allInvoices = context.watch<InvoiceBloc>().state.allInvoices;
    final allExpenses = context.watch<ExpenseBloc>().state.expenses;

    final filteredInvoices = _filterInvoices(allInvoices);
    final filteredExpenses = _filterExpenses(allExpenses);

    // Calculate Financial Metrics
    double grossRevenue = 0.0;
    double totalProductCost = 0.0;

    for (final inv in filteredInvoices) {
      grossRevenue += inv.totalAmount;
      for (final item in inv.items) {
        totalProductCost += item.itemCostTotal;
      }
    }

    final grossProfit = grossRevenue - totalProductCost;
    final totalExpensesAmount = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final netProfit = grossProfit - totalExpensesAmount;
    final marginPercent = grossRevenue > 0 ? (netProfit / grossRevenue) * 100 : 0.0;

    String timeLabel = 'اليوم';
    if (_timeRange == 'week') timeLabel = 'هذا الأسبوع';
    if (_timeRange == 'month') timeLabel = 'هذا الشهر';
    if (_timeRange == 'all') timeLabel = 'الإجمالي التراكمي';

    final timeRangeOptions = <Map<String, String>>[
      {'key': 'today', 'label': '📅 اليوم'},
      {'key': 'week', 'label': '📆 الأسبوع'},
      {'key': 'month', 'label': '🗓️ الشهر'},
      {'key': 'all', 'label': '📊 الكل'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحليلات الأرباح'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'تصدير PDF',
            onPressed: () {
              ProfitReportPdfService.printFinancialReport(
                timeFrameLabel: timeLabel,
                grossRevenue: grossRevenue,
                totalCost: totalProductCost,
                grossProfit: grossProfit,
                totalExpenses: totalExpensesAmount,
                netProfit: netProfit,
                invoices: filteredInvoices,
                expenses: filteredExpenses,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Range Selector (Segmented Control style)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: timeRangeOptions.map((opt) {
                  final isSelected = _timeRange == opt['key'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _timeRange = opt['key']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          opt['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Hero Net Profit Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: netProfit >= 0
                      ? [Colors.green.shade700, Colors.teal.shade600]
                      : [Colors.red.shade700, Colors.deepOrange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (netProfit >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'صافي الأرباح — $timeLabel',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${netProfit.toStringAsFixed(2)} دج',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          marginPercent >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'هامش الربح: ${marginPercent.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Financial Breakdown — Vertical waterfall style
            _buildBreakdownRow(
              icon: Icons.trending_up,
              color: Colors.blue.shade600,
              label: 'إجمالي المبيعات',
              value: grossRevenue,
              subtitle: '${filteredInvoices.length} فاتورة',
            ),
            _buildBreakdownRow(
              icon: Icons.inventory_2,
              color: Colors.purple.shade600,
              label: 'تكلفة البضاعة المباعة',
              value: -totalProductCost,
              subtitle: 'سعر شراء المنتجات',
              isNegative: true,
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(color: Colors.grey.shade300, thickness: 1),
            ),
            _buildBreakdownRow(
              icon: Icons.account_balance_wallet,
              color: Colors.teal.shade600,
              label: 'الأرباح الإجمالية (Gross)',
              value: grossProfit,
              subtitle: 'قبل خصم النفقات',
              isResult: true,
            ),
            _buildBreakdownRow(
              icon: Icons.money_off,
              color: Colors.orange.shade700,
              label: 'النفقات والمصاريف التشغيلية',
              value: -totalExpensesAmount,
              subtitle: '${filteredExpenses.length} عملية',
              isNegative: true,
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(color: Colors.grey.shade300, thickness: 2),
            ),
            _buildBreakdownRow(
              icon: netProfit >= 0 ? Icons.emoji_events : Icons.warning,
              color: netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              label: 'صافي الربح النهائي (Net)',
              value: netProfit,
              subtitle: 'بعد كل الخصومات',
              isResult: true,
              isHighlight: true,
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(Icons.receipt_long, color: Colors.orange.shade700),
                    ),
                    title: const Text('إدارة النفقات اليومية', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('تسجيل وجبات العمال والنقل والصيانة'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => context.push('/expenses'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.shade100,
                      child: Icon(Icons.receipt, color: Colors.amber.shade800),
                    ),
                    title: const Text('عرض الفواتير', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('مراجعة سجل المبيعات والفواتير الصادرة'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => context.push('/invoices'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow({
    required IconData icon,
    required Color color,
    required String label,
    required double value,
    required String subtitle,
    bool isNegative = false,
    bool isResult = false,
    bool isHighlight = false,
  }) {
    final displayValue = isNegative ? value : value;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(isHighlight ? 14 : 10),
      decoration: isHighlight
          ? BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            )
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isResult ? FontWeight.bold : FontWeight.w600,
                    fontSize: isHighlight ? 14 : 13,
                  ),
                ),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(
            '${displayValue.toStringAsFixed(2)} دج',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 16 : 14,
              color: isNegative ? Colors.red.shade600 : color,
            ),
          ),
        ],
      ),
    );
  }
}
