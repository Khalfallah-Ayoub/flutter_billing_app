import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../domain/entities/invoice.dart';
import '../bloc/invoice_bloc.dart';
import '../../data/services/invoice_pdf_service.dart';

class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final statuses = ['all', 'paid', 'debt'];
        _onStatusFilterSelected(statuses[_tabController.index]);
      }
    });
    context.read<InvoiceBloc>().add(LoadInvoicesEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    context.read<InvoiceBloc>().add(FilterInvoicesEvent(
          searchQuery: val,
          statusFilter: _selectedStatus,
        ));
  }

  void _onStatusFilterSelected(String status) {
    setState(() => _selectedStatus = status);
    context.read<InvoiceBloc>().add(FilterInvoicesEvent(
          searchQuery: _searchController.text,
          statusFilter: status,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير والديون',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt),
            color: AppTheme.primaryColor,
            tooltip: 'إدارة العملاء',
            onPressed: () => context.push('/customers'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppTheme.primaryColor,
            tooltip: 'تحديث',
            onPressed: () => context.read<InvoiceBloc>().add(LoadInvoicesEvent()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'الكل'),
            Tab(icon: Icon(Icons.check_circle, size: 18), text: 'مدفوعة'),
            Tab(icon: Icon(Icons.warning_amber, size: 18), text: 'ديون'),
          ],
        ),
      ),
      body: BlocConsumer<InvoiceBloc, InvoiceState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message!), backgroundColor: AppTheme.primaryColor),
            );
          }
        },
        builder: (context, state) {
          if (state.status == InvoiceStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allInvoices = state.allInvoices;
          final invoices = state.filteredInvoices;
          final totalRevenue = state.totalRevenue;
          final totalDebt = state.totalRemainingDebt;

          return Column(
            children: [
              // ── Stats Header ─────────────────────────────────────
              Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                        child: _StatCard(
                          label: 'إجمالي المبيعات',
                          value: AppConstants.formatPrice(totalRevenue),
                          icon: Icons.trending_up,
                          color: Colors.green,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'الديون المعلقة',
                          value: AppConstants.formatPrice(totalDebt),
                          icon: Icons.account_balance_wallet,
                          color: totalDebt > 0 ? Colors.orange : Colors.green,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'عدد الفواتير',
                          value: '${allInvoices.length}',
                          icon: Icons.receipt_long,
                          color: AppTheme.primaryColor,
                          isDark: isDark,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),

                    // Search bar
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'بحث: اسم الزبون، رقم الفاتورة، الهاتف...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Invoice List ─────────────────────────────────────
              Expanded(
                child: invoices.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: invoices.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildInvoiceCard(invoices[index], isDark, theme),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/invoices/create'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('فاتورة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice inv, bool isDark, ThemeData theme) {
    final dateFormat = DateFormat('dd/MM/yyyy  HH:mm');

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (inv.paymentStatus) {
      case PaymentStatus.paid:
        statusColor = Colors.green;
        statusText = 'مدفوعة';
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.unpaid:
        statusColor = Colors.red;
        statusText = 'غير مدفوعة';
        statusIcon = Icons.cancel;
        break;
      case PaymentStatus.partial:
        statusColor = Colors.orange;
        statusText = 'دين جزئي';
        statusIcon = Icons.timelapse;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/invoices/detail', extra: inv),
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left status stripe
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [statusColor, statusColor.withValues(alpha: 0.6)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Invoice number + status badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.receipt_long,
                                  color: AppTheme.primaryColor, size: 18),
                              const SizedBox(width: 6),
                              Text(inv.invoiceNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15)),
                            ]),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 13, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(statusText,
                                      style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Row 2: Customer info
                        Row(children: [
                          const Icon(Icons.person_outline,
                              size: 15, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text(inv.customerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          if (inv.customerPhone?.isNotEmpty == true) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.phone_outlined,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 3),
                            Text(inv.customerPhone!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ]),
                        const SizedBox(height: 10),

                        // Row 3: Financial summary
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              _MiniStat(
                                  label: 'الإجمالي',
                                  value: AppConstants.formatPrice(inv.totalAmount),
                                  color: theme.colorScheme.onSurface),
                              const _Divider(),
                              _MiniStat(
                                  label: 'المدفوع',
                                  value: AppConstants.formatPrice(inv.paidAmount),
                                  color: Colors.green),
                              if (inv.remainingAmount > 0) ...[
                                const _Divider(),
                                _MiniStat(
                                    label: 'الدين',
                                    value: AppConstants.formatPrice(
                                        inv.remainingAmount),
                                    color: Colors.red),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Row 4: Date + actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.access_time,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(dateFormat.format(inv.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ]),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (inv.customerPhone?.isNotEmpty == true)
                                  _ActionBtn(
                                    icon: Icons.call,
                                    color: Colors.green,
                                    tooltip: 'اتصال',
                                    onTap: () => InvoicePdfService.callCustomer(
                                        inv.customerPhone!),
                                  ),
                                _ActionBtn(
                                  icon: Icons.share,
                                  color: AppTheme.primaryColor,
                                  tooltip: 'مشاركة PDF',
                                  onTap: () =>
                                      InvoicePdfService.shareInvoicePdf(inv),
                                ),
                                _ActionBtn(
                                  icon: Icons.print,
                                  color: Colors.blueGrey,
                                  tooltip: 'طباعة',
                                  onTap: () =>
                                      InvoicePdfService.printInvoice(inv),
                                ),
                                if (inv.remainingAmount > 0)
                                  _ActionBtn(
                                    icon: Icons.payments,
                                    color: Colors.orange,
                                    tooltip: 'تسديد دين',
                                    onTap: () => context
                                        .push('/invoices/detail', extra: inv),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('لا توجد فواتير',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'أكمل عملية بيع أو أنشئ فاتورة جديدة\nليتم تسجيلها هنا تلقائياً',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 13, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 9.5, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 1),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
