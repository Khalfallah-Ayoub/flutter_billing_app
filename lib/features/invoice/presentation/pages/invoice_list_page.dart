import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/invoice.dart';
import '../bloc/invoice_bloc.dart';
import '../../data/services/invoice_pdf_service.dart';

class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    context.read<InvoiceBloc>().add(LoadInvoicesEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    context.read<InvoiceBloc>().add(
          FilterInvoicesEvent(
            searchQuery: val,
            statusFilter: _selectedStatus,
          ),
        );
  }

  void _onStatusFilterSelected(String status) {
    setState(() {
      _selectedStatus = status;
    });
    context.read<InvoiceBloc>().add(
          FilterInvoicesEvent(
            searchQuery: _searchController.text,
            statusFilter: status,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفواتير والديون', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt, color: AppTheme.primaryColor),
            tooltip: 'إدارة العملاء والديون',
            onPressed: () => context.push('/customers'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            tooltip: 'تحديث البيانات',
            onPressed: () => context.read<InvoiceBloc>().add(LoadInvoicesEvent()),
          ),
        ],
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
              // Summary Metrics Header
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surface,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'إجمالي المبيعات',
                            value: '${totalRevenue.toStringAsFixed(0)} دج',
                            icon: Icons.payments,
                            color: Colors.green,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'الديون المعلقة',
                            value: '${totalDebt.toStringAsFixed(0)} دج',
                            icon: Icons.warning_amber_rounded,
                            color: Colors.orange,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Input
                    TextFormField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'بحث باسم الزبون، رقم الفاتورة، أو الهاتف...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'الكل (${allInvoices.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'paid',
                              'مدفوعة (${allInvoices.where((i) => i.isPaid).length})',
                              Colors.green),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'debt',
                              'ديون معلقة (${allInvoices.where((i) => i.hasDebt).length})',
                              Colors.orange),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Invoice Items List
              Expanded(
                child: invoices.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final inv = invoices[index];
                          return _buildInvoiceCard(inv, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/invoices/create'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'إنشاء فاتورة جديدة',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String statusKey, String label, [Color? activeColor]) {
    final isSelected = _selectedStatus == statusKey;
    final theme = Theme.of(context);
    final color = activeColor ?? AppTheme.primaryColor;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => _onStatusFilterSelected(statusKey),
    );
  }

  Widget _buildInvoiceCard(Invoice inv, bool isDark) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final theme = Theme.of(context);

    Color statusColor = Colors.green;
    String statusText = 'مدفوعة بالكامل ✅';
    if (inv.paymentStatus == PaymentStatus.unpaid) {
      statusColor = Colors.red;
      statusText = 'غير مدفوعة ❌';
    } else if (inv.paymentStatus == PaymentStatus.partial) {
      statusColor = Colors.orange;
      statusText = 'دين جزئي ⚠️';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Number & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      inv.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer Name & Phone
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  inv.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (inv.customerPhone != null && inv.customerPhone!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    inv.customerPhone!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Financial Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الإجمالي', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${inv.totalAmount.toStringAsFixed(2)} دج',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('المدفوع', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${inv.paidAmount.toStringAsFixed(2)} دج',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('المتبقي (الدين)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${inv.remainingAmount.toStringAsFixed(2)} دج',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: inv.remainingAmount > 0 ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(inv.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Row(
                  children: [
                    if (inv.customerPhone != null && inv.customerPhone!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.call, color: Colors.green, size: 20),
                        tooltip: 'اتصال بالزبون',
                        onPressed: () => InvoicePdfService.callCustomer(inv.customerPhone!),
                      ),
                    IconButton(
                      icon: const Icon(Icons.share, color: AppTheme.primaryColor, size: 20),
                      tooltip: 'مشاركة PDF عبر واتساب',
                      onPressed: () => InvoicePdfService.shareInvoicePdf(inv),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.blue, size: 20),
                      tooltip: 'طباعة الفاتورة',
                      onPressed: () => InvoicePdfService.printInvoice(inv),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      onPressed: () => context.push('/invoices/detail', extra: inv),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد فواتير مسجلة حالياً',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'قم بإضافة فاتورة جديدة أو إكمال عملية بيع ليتم تسجيلها تلقائياً',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
