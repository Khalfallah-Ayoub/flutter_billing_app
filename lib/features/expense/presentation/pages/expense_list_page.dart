import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/expense.dart';
import '../bloc/expense_bloc.dart';

class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({super.key});

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  final _uuid = const Uuid();
  String _selectedCategoryFilter = 'الكل';

  final List<String> _categories = [
    'وجبات وعمال',
    'نقل وشحن',
    'صيانة وإصلاح',
    'فواتير ومصاريف',
    'أخرى',
  ];

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'وجبات وعمال':
        return Icons.restaurant;
      case 'نقل وشحن':
        return Icons.local_shipping;
      case 'صيانة وإصلاح':
        return Icons.build;
      case 'فواتير ومصاريف':
        return Icons.receipt;
      default:
        return Icons.money_off;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'وجبات وعمال':
        return Colors.red.shade600;
      case 'نقل وشحن':
        return Colors.blue.shade600;
      case 'صيانة وإصلاح':
        return Colors.amber.shade700;
      case 'فواتير ومصاريف':
        return Colors.purple.shade600;
      default:
        return Colors.orange.shade700;
    }
  }

  void _showAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = _categories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.add_circle, color: Colors.orange, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'تسجيل نفقة جديدة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'وصف النفقة *',
                        hintText: 'مثلاً: غداء العمال',
                        prefixIcon: const Icon(Icons.description),
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'المبلغ (دج) *',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.attach_money),
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Category chips
                    const Text('فئة النفقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _categories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_categoryIcon(cat), size: 16, color: isSel ? Colors.white : _categoryColor(cat)),
                              const SizedBox(width: 4),
                              Text(cat),
                            ],
                          ),
                          selected: isSel,
                          selectedColor: _categoryColor(cat),
                          labelStyle: TextStyle(color: isSel ? Colors.white : null, fontWeight: FontWeight.bold),
                          onSelected: (val) {
                            if (val) setSheetState(() => selectedCategory = cat);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        prefixIcon: const Icon(Icons.note),
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final title = titleCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                          if (title.isEmpty || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إدخال الوصف والمبلغ'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final expense = Expense(
                            id: _uuid.v4(),
                            title: title,
                            amount: amount,
                            category: selectedCategory,
                            date: DateTime.now(),
                            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                          );

                          context.read<ExpenseBloc>().add(AddExpenseEvent(expense));
                          Navigator.pop(sheetCtx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ تم تسجيل: $title — ${amount.toStringAsFixed(2)} دج'),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text('حفظ النفقة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد الحذف'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف "${expense.title}" بقيمة ${expense.amount.toStringAsFixed(2)} دج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExpenseBloc>().add(DeleteExpenseEvent(expense.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف النفقة'), behavior: SnackBarBehavior.floating),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd — HH:mm');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة النفقات والمصاريف'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة نفقة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          final allExpenses = state.expenses;
          final filteredExpenses = _selectedCategoryFilter == 'الكل'
              ? allExpenses
              : allExpenses.where((e) => e.category == _selectedCategoryFilter).toList();

          return Column(
            children: [
              // Statistics Top Header Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade700, Colors.deepOrange.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('نفقات اليوم', state.todayExpenseAmount, Colors.white),
                    Container(height: 40, width: 1, color: Colors.white30),
                    _buildStatCol('الإجمالي', state.totalExpenseAmount, Colors.white),
                    Container(height: 40, width: 1, color: Colors.white30),
                    _buildStatCol('عدد العمليات', allExpenses.length.toDouble(), Colors.white, isCount: true),
                  ],
                ),
              ),

              // Filter Chips
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['الكل', ..._categories].map((cat) {
                    final isSel = _selectedCategoryFilter == cat;
                    final color = cat == 'الكل' ? AppTheme.primaryColor : _categoryColor(cat);
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(cat, style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : null,
                        )),
                        selected: isSel,
                        selectedColor: color,
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategoryFilter = cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Expense List
              Expanded(
                child: filteredExpenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _selectedCategoryFilter == 'الكل'
                                  ? 'لا توجد نفقات مسجلة بعد'
                                  : 'لا توجد نفقات في فئة "$_selectedCategoryFilter"',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اضغط على الزر أسفل لإضافة نفقة جديدة',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filteredExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = filteredExpenses[index];
                          final catColor = _categoryColor(expense.category);
                          return Dismissible(
                            key: Key(expense.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              _confirmDelete(expense);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_categoryIcon(expense.category), color: catColor, size: 22),
                                ),
                                title: Text(
                                  expense.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            expense.category,
                                            style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          dateFormat.format(expense.date),
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                    if (expense.note != null && expense.note!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        expense.note!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Text(
                                  '-${expense.amount.toStringAsFixed(2)} دج',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCol(String label, double value, Color color, {bool isCount = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          isCount ? value.toInt().toString() : '${value.toStringAsFixed(2)} دج',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
