import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../invoice/presentation/bloc/customer_bloc.dart';
import '../../../invoice/presentation/bloc/invoice_bloc.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../invoice/domain/entities/invoice.dart';
import '../../../returns/presentation/bloc/return_bloc.dart';
import '../../domain/entities/craftsman.dart';

class CraftsmanDetailPage extends StatefulWidget {
  final Craftsman craftsman;

  const CraftsmanDetailPage({super.key, required this.craftsman});

  @override
  State<CraftsmanDetailPage> createState() => _CraftsmanDetailPageState();
}

class _CraftsmanDetailPageState extends State<CraftsmanDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    context.read<ReturnBloc>().add(LoadReturnsEvent());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<InvoiceBloc, InvoiceState>(
      builder: (context, invoiceState) {
        // All invoices linked to this craftsman
        final craftsmanInvoices = invoiceState.allInvoices
            .where((inv) => inv.craftsmanId == widget.craftsman.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final totalSales = craftsmanInvoices.fold<double>(0, (s, i) => s + i.totalAmount);
        final totalDebt = craftsmanInvoices.fold<double>(0, (s, i) => s + i.remainingAmount);
        final totalPaid = craftsmanInvoices.fold<double>(0, (s, i) => s + i.paidAmount);

        // Unique clients from invoices
        final invoiceClientIds = craftsmanInvoices.map((i) => i.customerId).whereType<String>().toSet();
        
        // Also include customers directly linked via Customer.craftsmanId
        final directLinkedIds = context.read<CustomerBloc>().state.customers
            .where((c) => c.craftsmanId == widget.craftsman.id)
            .map((c) => c.id)
            .toSet();
        
        // Merge both sources
        final allClientIds = {...invoiceClientIds, ...directLinkedIds};

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: NestedScrollView(
            headerSliverBuilder: (ctx, inner) => [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  child: Text(
                                    widget.craftsman.name[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.craftsman.name,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 20,
                                              fontWeight: FontWeight.bold)),
                                      Text(widget.craftsman.specialty ?? 'حرفي',
                                          style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 13)),
                                      Text(widget.craftsman.phone,
                                          style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _summaryChip(Icons.receipt_long, '${craftsmanInvoices.length} فاتورة'),
                                const SizedBox(width: 10),
                                _summaryChip(Icons.people, '${allClientIds.length} عميل'),
                                const SizedBox(width: 10),
                                if (totalDebt > 0)
                                  _summaryChip(Icons.warning_amber, AppConstants.formatPrice(totalDebt),
                                      color: Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  title: Text(widget.craftsman.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabHeaderDelegate(
                  TabBar(
                    controller: _tab,
                    tabs: const [Tab(text: 'الفواتير'), Tab(text: 'العملاء')],
                  ),
                ),
              ),
            ],
            body: Column(
              children: [
                // Financial summary row
                Container(
                  color: theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _finBox('إجمالي المبيعات', totalSales, Colors.blue),
                      const SizedBox(width: 8),
                      _finBox('المدفوع', totalPaid, Colors.green),
                      const SizedBox(width: 8),
                      _finBox('الديون', totalDebt, Colors.red),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _InvoicesTab(invoices: craftsmanInvoices, craftsman: widget.craftsman),
                      _ClientsTab(
                        clientIds: allClientIds,
                        invoices: craftsmanInvoices,
                        craftsmanId: widget.craftsman.id,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.white),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 12,
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _finBox(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(AppConstants.formatPrice(amount),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Invoices Tab ───────────────────────────────────────────────
class _InvoicesTab extends StatelessWidget {
  final List<Invoice> invoices;
  final Craftsman craftsman;

  const _InvoicesTab({required this.invoices, required this.craftsman});

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('لا توجد فواتير بعد', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final inv = invoices[i];
        final statusColor = inv.isPaid ? Colors.green : inv.remainingAmount > 0 ? Colors.orange : Colors.red;

        return Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => context.push('/invoice/${inv.id}', extra: inv),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(inv.invoiceNumber,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(inv.customerName,
                                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(AppConstants.formatPrice(inv.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            if (inv.remainingAmount > 0)
                              Text('متبقي: ${AppConstants.formatPrice(inv.remainingAmount)}',
                                  style: TextStyle(color: Colors.red[400], fontSize: 12)),
                          ],
                        ),
                        Text(
                          _formatDate(inv.createdAt),
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      context.read<BillingBloc>().add(LoadInvoiceForEditEvent(inv));
                      context.go('/');
                    },
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'تعديل الفاتورة في سلة المشتريات',
                    color: Colors.amber.shade800,
                  ),
                  if (inv.remainingAmount > 0)
                    IconButton(
                      onPressed: () => context.push('/return/${inv.id}', extra: inv),
                      icon: const Icon(Icons.assignment_return_outlined, size: 20),
                      tooltip: 'إرجاع بضاعة',
                      color: AppTheme.primaryColor,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Clients Tab ────────────────────────────────────────────────
class _ClientsTab extends StatelessWidget {
  final Set<String> clientIds;
  final List<Invoice> invoices;
  final String craftsmanId;

  const _ClientsTab({
    required this.clientIds,
    required this.invoices,
    required this.craftsmanId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        // Get all customers: directly linked + from invoices
        final directLinked = state.customers
            .where((c) => c.craftsmanId == craftsmanId)
            .toList();
        final invoiceLinked = state.customers
            .where((c) => clientIds.contains(c.id) && c.craftsmanId != craftsmanId)
            .toList();
        
        // Merge without duplicates
        final allClientsMap = <String, dynamic>{};
        for (final c in directLinked) {
          allClientsMap[c.id] = c;
        }
        for (final c in invoiceLinked) {
          allClientsMap[c.id] = c;
        }
        final allClients = allClientsMap.values.toList();

        if (allClients.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('لا عملاء مرتبطون بهذا الحرفي',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 8),
                Text('أضف زبائن من صفحة العملاء وأربطهم بهذا الحرفي',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: allClients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final client = allClients[i];
            final clientInvoices = invoices.where((inv) => inv.customerId == client.id).toList();
            final debt = clientInvoices.fold<double>(0, (s, inv) => s + inv.remainingAmount);
            final totalPurchases = clientInvoices.fold<double>(0, (s, inv) => s + inv.totalAmount);
            final isDirectlyLinked = client.craftsmanId == craftsmanId;

            return Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => context.push('/customer/${client.id}', extra: client),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: (isDirectlyLinked ? Colors.blue : AppTheme.primaryColor)
                                .withValues(alpha: 0.12),
                            child: Text(client.name[0].toUpperCase(),
                                style: TextStyle(
                                    color: isDirectlyLinked ? Colors.blue : AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(client.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    if (isDirectlyLinked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('مرتبط',
                                            style: TextStyle(fontSize: 9, color: Colors.blue,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                Text(client.phone,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${clientInvoices.length} فاتورة',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              if (totalPurchases > 0)
                                Text(AppConstants.formatPrice(totalPurchases),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              if (debt > 0)
                                Text(AppConstants.formatPrice(debt),
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.red,
                                        fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Tab Header Delegate ─────────────────────────────────────────
class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabHeaderDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
