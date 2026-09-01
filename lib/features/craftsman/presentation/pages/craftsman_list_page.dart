import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../invoice/presentation/bloc/invoice_bloc.dart';
import '../bloc/craftsman_bloc.dart';
import '../../domain/entities/craftsman.dart';

class CraftsmanListPage extends StatefulWidget {
  const CraftsmanListPage({super.key});

  @override
  State<CraftsmanListPage> createState() => _CraftsmanListPageState();
}

class _CraftsmanListPageState extends State<CraftsmanListPage> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<CraftsmanBloc>().add(LoadCraftsmenEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('الحرفيون', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showAddCraftsmanSheet(context),
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'إضافة حرفي',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim()),
                decoration: InputDecoration(
                  hintText: 'بحث عن حرفي...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _search = ''),
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Summary card
          BlocBuilder<InvoiceBloc, InvoiceState>(
            builder: (context, invoiceState) {
              return BlocBuilder<CraftsmanBloc, CraftsmanState>(
                builder: (context, state) {
                final totalDebt = invoiceState.allInvoices
                      .where((inv) => inv.craftsmanId != null)
                      .fold<double>(0, (s, i) => s + i.remainingAmount);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.75)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.engineering, color: Colors.white, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${state.craftsmen.length} حرفي مسجل',
                                  style: const TextStyle(color: Colors.white, fontSize: 13)),
                              Text(
                                'إجمالي الديون المرتبطة: ${AppConstants.formatPrice(totalDebt)}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: BlocBuilder<CraftsmanBloc, CraftsmanState>(
              builder: (context, state) {
                final filtered = state.craftsmen
                    .where((c) => _search.isEmpty ||
                        c.name.contains(_search) ||
                        c.phone.contains(_search) ||
                        (c.specialty?.contains(_search) ?? false))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.engineering, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(_search.isEmpty ? 'لا يوجد حرفيون مسجلون بعد'
                            : 'لا نتائج لـ "$_search"',
                            style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                        if (_search.isEmpty) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _showAddCraftsmanSheet(context),
                            icon: const Icon(Icons.add),
                            label: const Text('أضف أول حرفي'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _CraftsmanCard(
                    craftsman: filtered[i],
                    onTap: () => context.push('/craftsman/${filtered[i].id}',
                        extra: filtered[i]),
                    onEdit: () => _showEditSheet(context, filtered[i]),
                    onDelete: () => _confirmDelete(context, filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCraftsmanSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('حرفي جديد'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddCraftsmanSheet(BuildContext context) =>
      _showSheet(context, null);

  void _showEditSheet(BuildContext context, Craftsman craftsman) =>
      _showSheet(context, craftsman);

  void _showSheet(BuildContext ctx, Craftsman? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String specialty = existing?.specialty ?? 'سبّاك';

    final specialties = ['سبّاك', 'كهربائي', 'بنّاء', 'نجّار', 'دهّان', 'حدّاد', 'أخرى'];

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(existing == null ? 'إضافة حرفي جديد' : 'تعديل بيانات الحرفي',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Specialty chips
                  const Text('التخصص', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: specialties.map((s) {
                      final selected = specialty == s;
                      return ChoiceChip(
                        label: Text(s, style: TextStyle(fontSize: 12,
                            color: selected ? Colors.white : null)),
                        selected: selected,
                        selectedColor: AppTheme.primaryColor,
                        onSelected: (_) => setSheetState(() => specialty = s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _field(nameCtrl, 'الاسم الكامل *', Icons.person),
                  const SizedBox(height: 12),
                  _field(phoneCtrl, 'رقم الهاتف *', Icons.phone,
                      keyboard: TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(addressCtrl, 'العنوان (اختياري)', Icons.location_on),
                  const SizedBox(height: 12),
                  _field(notesCtrl, 'ملاحظات', Icons.notes, maxLines: 2),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      if (existing == null) {
                        ctx.read<CraftsmanBloc>().add(AddCraftsmanEvent(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                          specialty: specialty,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        ));
                      } else {
                        ctx.read<CraftsmanBloc>().add(UpdateCraftsmanEvent(existing.copyWith(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                          specialty: specialty,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        )));
                      }
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(existing == null ? 'إضافة الحرفي' : 'حفظ التعديلات',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, Craftsman craftsman) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الحرفي؟'),
        content: Text('هل تريد حذف "${craftsman.name}"؟ لن تُحذف بيانات عملائه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ctx.read<CraftsmanBloc>().add(DeleteCraftsmanEvent(craftsman.id));
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _CraftsmanCard extends StatelessWidget {
  final Craftsman craftsman;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CraftsmanCard({
    required this.craftsman,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _specialtyColor {
    switch (craftsman.specialty) {
      case 'كهربائي': return Colors.amber.shade700;
      case 'سبّاك': return Colors.blue.shade700;
      case 'بنّاء': return Colors.brown.shade600;
      case 'نجّار': return Colors.orange.shade700;
      case 'دهّان': return Colors.green.shade700;
      case 'حدّاد': return Colors.grey.shade700;
      default: return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<InvoiceBloc, InvoiceState>(
      builder: (context, invoiceState) {
        final clientInvoices = invoiceState.allInvoices
            .where((inv) => inv.craftsmanId == craftsman.id).toList();
        final totalDebt = clientInvoices.fold<double>(0, (s, i) => s + i.remainingAmount);
        final clientCount = invoiceState.allInvoices
            .where((inv) => inv.craftsmanId == craftsman.id)
            .map((inv) => inv.customerId)
            .toSet()
            .length;

        return Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          elevation: 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _specialtyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _specialtyColor.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        craftsman.name.isNotEmpty ? craftsman.name[0].toUpperCase() : '؟',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _specialtyColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(craftsman.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            if (craftsman.specialty != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _specialtyColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(craftsman.specialty!,
                                    style: TextStyle(fontSize: 10, color: _specialtyColor,
                                        fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(craftsman.phone,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.people_outline, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text('$clientCount عميل', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(width: 16),
                            if (totalDebt > 0) ...[
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 14, color: Colors.red[400]),
                              const SizedBox(width: 4),
                              Text(AppConstants.formatPrice(totalDebt),
                                  style: TextStyle(fontSize: 12, color: Colors.red[600],
                                      fontWeight: FontWeight.bold)),
                            ] else ...[
                              const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text('لا ديون', style: TextStyle(fontSize: 12, color: Colors.green[600])),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('تعديل'),
                      ])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red)),
                      ])),
                    ],
                    child: const Icon(Icons.more_vert, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
