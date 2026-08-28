import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../invoice/presentation/bloc/invoice_bloc.dart';
import '../../../expense/presentation/bloc/expense_bloc.dart';

class FinancialHubPage extends StatelessWidget {
  const FinancialHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final allInvoices = context.watch<InvoiceBloc>().state.allInvoices;
    final theme = Theme.of(context);

    // Filter today's figures
    final todayInvoices = allInvoices.where((inv) {
      return inv.createdAt.year == now.year &&
          inv.createdAt.month == now.month &&
          inv.createdAt.day == now.day;
    }).toList();

    double todaySales = 0.0;
    double todayCost = 0.0;
    for (final inv in todayInvoices) {
      todaySales += inv.totalAmount;
      for (final item in inv.items) {
        todayCost += item.itemCostTotal;
      }
    }

    final todayGrossProfit = todaySales - todayCost;
    final todayExpenses = context.watch<ExpenseBloc>().state.todayExpenseAmount;
    final todayNetProfit = todayGrossProfit - todayExpenses;
    final todayInvoiceCount = todayInvoices.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المركز المالي'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Live Today Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Colors.indigo.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'ملخص النشاط المالي لليوم',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$todayInvoiceCount فاتورة',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 3-column stats
                  Row(
                    children: [
                      Expanded(child: _buildSummaryItem('💰 المبيعات', todaySales, Colors.white)),
                      Container(height: 40, width: 1, color: Colors.white24),
                      Expanded(child: _buildSummaryItem('💸 المصاريف', todayExpenses, Colors.orangeAccent)),
                      Container(height: 40, width: 1, color: Colors.white24),
                      Expanded(
                        child: _buildSummaryItem(
                          todayNetProfit >= 0 ? '📈 الربح' : '📉 خسارة',
                          todayNetProfit,
                          todayNetProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'الأقسام والخدمات المالية:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Primary Financial Actions (2 prominent tiles)
            Row(
              children: [
                Expanded(
                  child: _buildPrimaryTile(
                    context,
                    title: 'تحليلات الأرباح',
                    subtitle: 'صافي الربح وتقارير PDF',
                    icon: Icons.analytics,
                    gradient: [Colors.green.shade600, Colors.teal.shade700],
                    route: '/profit-analytics',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrimaryTile(
                    context,
                    title: 'المصاريف اليومية',
                    subtitle: 'غداء العمال والنفقات',
                    icon: Icons.money_off,
                    gradient: [Colors.orange.shade600, Colors.deepOrange.shade700],
                    route: '/expenses',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Secondary Tiles (list style)
            _buildSecondaryTile(
              context,
              title: 'إدارة الفواتير والمبيعات',
              subtitle: 'سجل كامل للمبيعات النقدية والآجلة',
              icon: Icons.receipt_long,
              color: Colors.amber.shade800,
              route: '/invoices',
            ),
            _buildSecondaryTile(
              context,
              title: 'سجل الديون والعملاء',
              subtitle: 'متابعة الدفعات وأرقام هواتف الزبائن',
              icon: Icons.people,
              color: Colors.purple.shade700,
              route: '/customers',
            ),
            _buildSecondaryTile(
              context,
              title: 'بيع وقطع الأنابيب',
              subtitle: 'حساب الأمتار وتوليد فواتير القطع',
              icon: Icons.content_cut,
              color: Colors.blue.shade700,
              route: '/pipe-sales',
            ),
            _buildSecondaryTile(
              context,
              title: 'المساعد الذكي',
              subtitle: 'استفسار سريع عن أسعار المنتجات محلياً',
              icon: Icons.smart_toy,
              color: AppTheme.primaryColor,
              route: '/ai-chat',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${value.toStringAsFixed(0)} دج',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => context.push(route),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
      ),
    );
  }
}
