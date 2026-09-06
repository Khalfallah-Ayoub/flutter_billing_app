import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/invoice.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/invoice_bloc.dart';
import '../../data/services/customer_service.dart';
import '../../data/services/invoice_pdf_service.dart';
import '../../../craftsman/presentation/bloc/craftsman_bloc.dart';
import '../../../craftsman/domain/entities/craftsman.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'debt'; // 'debt' | 'name' | 'purchases'
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    context.read<CustomerBloc>().add(LoadCustomersEvent());
    context.read<InvoiceBloc>().add(LoadInvoicesEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog([Customer? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    // Load craftsman for existing customer
    Craftsman? selectedCraftsman;
    if (existing?.craftsmanId != null && existing!.craftsmanId!.isNotEmpty) {
      final craftsmen = context.read<CraftsmanBloc>().state.craftsmen;
      try {
        selectedCraftsman = craftsmen.firstWhere((c) => c.id == existing.craftsmanId);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final craftsmen = context.read<CraftsmanBloc>().state.craftsmen;
            return AlertDialog(
              title: Row(children: [
                Icon(existing == null ? Icons.person_add : Icons.edit,
                    color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 8),
                Text(existing == null ? 'إضافة زبون' : 'تعديل الزبون'),
              ]),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogField(ctrl: nameCtrl, label: 'الاسم *', icon: Icons.person),
                    const SizedBox(height: 10),
                    _DialogField(
                        ctrl: phoneCtrl,
                        label: 'الهاتف *',
                        icon: Icons.phone,
                        type: TextInputType.phone),
                    const SizedBox(height: 10),
                    _DialogField(
                        ctrl: addressCtrl,
                        label: 'العنوان (اختياري)',
                        icon: Icons.location_on),
                    const SizedBox(height: 10),
                    _DialogField(
                        ctrl: notesCtrl,
                        label: 'ملاحظات (اختياري)',
                        icon: Icons.note_alt),
                    const SizedBox(height: 14),
                    // ── Craftsman Linking ──
                    if (craftsmen.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('ربط بحرفي (اختياري)',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedCraftsman != null
                                ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Craftsman?>(
                            value: selectedCraftsman,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            hint: const Row(children: [
                              Icon(Icons.engineering, size: 18, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('بدون حرفي', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ]),
                            items: [
                              const DropdownMenuItem<Craftsman?>(
                                value: null,
                                child: Text('بدون حرفي', style: TextStyle(color: Colors.grey)),
                              ),
                              ...craftsmen.map((c) => DropdownMenuItem<Craftsman?>(
                                value: c,
                                child: Row(children: [
                                  Icon(Icons.engineering, size: 16, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text('${c.name}${c.specialty != null ? " (${c.specialty})" : ""}'),
                                ]),
                              )),
                            ],
                            onChanged: (c) => setDialogState(() => selectedCraftsman = c),
                          ),
                        ),
                      ),
                      if (selectedCraftsman != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Icon(Icons.link, size: 14, color: Colors.green[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'سيتم ربط هذا الزبون بالحرفي ${selectedCraftsman!.name}',
                                style: TextStyle(fontSize: 11, color: Colors.green[700]),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton.icon(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    if (name.isEmpty || phone.isEmpty) return;
                    final customer = Customer(
                      id: existing?.id ?? _uuid.v4(),
                      name: name,
                      phone: phone,
                      address: addressCtrl.text.trim().isEmpty
                          ? null
                          : addressCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      createdAt: existing?.createdAt ?? DateTime.now(),
                      craftsmanId: selectedCraftsman?.id,
                      craftsmanName: selectedCraftsman?.name,
                    );
                    if (existing == null) {
                      context.read<CustomerBloc>().add(AddCustomerEvent(customer));
                    } else {
                      context.read<CustomerBloc>().add(UpdateCustomerEvent(customer));
                    }
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save, size: 18, color: Colors.white),
                  label: const Text('حفظ', style: TextStyle(color: Colors.white)),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.red, size: 22),
          SizedBox(width: 8),
          Text('حذف الزبون'),
        ]),
        content: Text('هل تريد حذف "${customer.name}"؟\nسيتم حذف بياناته فقط، الفواتير ستبقى.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton.icon(
            onPressed: () {
              context.read<CustomerBloc>().add(DeleteCustomerEvent(customer.id));
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.delete, size: 18, color: Colors.white),
            label: const Text('حذف', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  List<Customer> _sortCustomers(
      List<Customer> customers, List<Invoice> invoices) {
    switch (_sortBy) {
      case 'debt':
        return [...customers]..sort((a, b) {
            final da = CustomerService.getCustomerTotalDebt(a.id, invoices);
            final db = CustomerService.getCustomerTotalDebt(b.id, invoices);
            return db.compareTo(da);
          });
      case 'name':
        return [...customers]..sort((a, b) => a.name.compareTo(b.name));
      case 'purchases':
        return [...customers]..sort((a, b) {
            final pa = CustomerService.getCustomerTotalPurchases(a.id, invoices);
            final pb = CustomerService.getCustomerTotalPurchases(b.id, invoices);
            return pb.compareTo(pa);
          });
      default:
        return customers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل العملاء والديون',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'ترتيب',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'debt', child: Text('ترتيب: الديون الأعلى')),
              const PopupMenuItem(value: 'name', child: Text('ترتيب: الاسم أبجدياً')),
              const PopupMenuItem(value: 'purchases', child: Text('ترتيب: المشتريات الأكثر')),
            ],
          ),
        ],
      ),
      body: BlocConsumer<CustomerBloc, CustomerState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message!),
                  backgroundColor: AppTheme.primaryColor),
            );
          }
        },
        builder: (context, state) {
          if (state.status == CustomerStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoices = context.watch<InvoiceBloc>().state.allInvoices;

          final filtered = state.customers.where((c) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.phone.toLowerCase().contains(q) ||
                (c.address ?? '').toLowerCase().contains(q);
          }).toList();

          final sorted = _sortCustomers(filtered, invoices);

          final totalDebt = state.customers.fold(0.0, (sum, c) {
            return sum + CustomerService.getCustomerTotalDebt(c.id, invoices);
          });
          final debtorCount =
              state.customers.where((c) =>
                  CustomerService.getCustomerTotalDebt(c.id, invoices) > 0).length;

          return Column(
            children: [
              // ── Header ────────────────────────────────────────────
              Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  children: [
                    // Stats row
                    Row(children: [
                      Expanded(
                        child: _QuickStat(
                          icon: Icons.people,
                          label: 'إجمالي العملاء',
                          value: '${state.customers.length}',
                          color: AppTheme.primaryColor,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickStat(
                          icon: Icons.account_balance_wallet,
                          label: 'إجمالي الديون',
                          value: AppConstants.formatPrice(totalDebt),
                          color: totalDebt > 0 ? Colors.red : Colors.green,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickStat(
                          icon: Icons.warning_amber,
                          label: 'عملاء مديونون',
                          value: '$debtorCount',
                          color: debtorCount > 0 ? Colors.orange : Colors.green,
                          isDark: isDark,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),

                    // Search bar
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم، الهاتف، أو العنوان...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
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

              // ── Customer List ──────────────────────────────────────
              Expanded(
                child: sorted.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final c = sorted[index];
                          final debt = CustomerService.getCustomerTotalDebt(
                              c.id, invoices);
                          final purchases =
                              CustomerService.getCustomerTotalPurchases(
                                  c.id, invoices);
                          final invoiceCount = invoices
                              .where((i) => i.customerId == c.id)
                              .length;
                          return _buildCustomerCard(
                              c, debt, purchases, invoiceCount, theme, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('إضافة زبون',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildCustomerCard(Customer c, double debt, double purchases,
      int invoiceCount, ThemeData theme, bool isDark) {
    final hasDebt = debt > 0;
    final accentColor =
        hasDebt ? Colors.red : AppTheme.primaryColor;
    final initials =
        c.name.trim().isEmpty ? 'Z' : c.name.trim()[0].toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDebt
              ? Colors.red.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        onTap: () {
          // Navigate to customer invoices filtered
          context.push('/invoices');
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Avatar + Name + Actions ──────────────────
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(initials,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: accentColor)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Row(children: [
                          const Icon(Icons.phone_outlined,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(c.phone,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ]),
                        if (c.craftsmanName != null && c.craftsmanName!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(children: [
                              Icon(Icons.engineering,
                                  size: 13, color: Colors.blue[600]),
                              const SizedBox(width: 3),
                              Text('حرفي: ${c.craftsmanName}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.blue[600],
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SmallBtn(
                        icon: Icons.call,
                        color: Colors.green,
                        onTap: () =>
                            InvoicePdfService.callCustomer(c.phone),
                      ),
                      const SizedBox(width: 4),
                      _SmallBtn(
                        icon: Icons.edit_outlined,
                        color: Colors.blueGrey,
                        onTap: () => _showAddEditDialog(c),
                      ),
                      const SizedBox(width: 4),
                      _SmallBtn(
                        icon: Icons.delete_outline,
                        color: Colors.red.shade400,
                        onTap: () => _confirmDelete(c),
                      ),
                    ],
                  ),
                ],
              ),

              if (c.address != null || c.notes != null) ...[
                const SizedBox(height: 6),
                if (c.address != null)
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(c.address!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
              ],

              const SizedBox(height: 10),

              // ── Row 2: Stats ─────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _InfoChip(
                      icon: Icons.receipt_long,
                      label: 'فواتير',
                      value: '$invoiceCount',
                      color: AppTheme.primaryColor,
                    ),
                    Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.grey.withValues(alpha: 0.2)),
                    _InfoChip(
                      icon: Icons.shopping_bag_outlined,
                      label: 'مشتريات',
                      value: AppConstants.formatPrice(purchases),
                      color: theme.colorScheme.onSurface,
                    ),
                    Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.grey.withValues(alpha: 0.2)),
                    _InfoChip(
                      icon: hasDebt
                          ? Icons.warning_amber
                          : Icons.check_circle,
                      label: 'الدين',
                      value: hasDebt
                          ? AppConstants.formatPrice(debt)
                          : 'لا شيء',
                      color: hasDebt ? Colors.red : Colors.green,
                    ),
                  ],
                ),
              ),

              // ── Row 3: Debt pay button ───────────────────────────
              if (hasDebt) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/invoices'),
                    icon: const Icon(Icons.payments, size: 16,
                        color: Colors.orange),
                    label: Text(
                      'تسديد الدين: ${AppConstants.formatPrice(debt)}',
                      style: const TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
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
          Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('لا يوجد عملاء مسجلون',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'أضف بيانات عملائك لمتابعة مشترياتهم\nوديونهم بسهولة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
            label: const Text('إضافة زبون',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 13, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 9.5, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType type;

  const _DialogField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.type = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
