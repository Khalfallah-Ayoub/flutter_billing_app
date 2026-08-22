import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/product_export_service.dart';

class ImportConflictDialog extends StatefulWidget {
  final ImportAnalysisResult analysis;

  const ImportConflictDialog({super.key, required this.analysis});

  static Future<Map<String, int>?> show(
    BuildContext context,
    ImportAnalysisResult analysis,
  ) {
    return showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImportConflictDialog(analysis: analysis),
    );
  }

  @override
  State<ImportConflictDialog> createState() => _ImportConflictDialogState();
}

class _ImportConflictDialogState extends State<ImportConflictDialog> {
  late List<ProductImportConflict> _conflicts;
  bool _isManualReview = false;

  @override
  void initState() {
    super.initState();
    _conflicts = widget.analysis.conflicts;
  }

  void _applyGlobalAction(ConflictAction action) {
    setState(() {
      for (final conflict in _conflicts) {
        conflict.action = action;
      }
    });
  }

  Future<void> _confirmAndExecute() async {
    final summary = await ProductExportService.executeImport(widget.analysis);
    if (mounted) {
      Navigator.of(context).pop(summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.sync_alt, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'توفيق وتحديد أسعار الاستيراد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Analysis Summary Stat Cards
                  Row(
                    children: [
                      _buildStatCard(
                        'منتجات جديدة',
                        '${widget.analysis.newProducts.length}',
                        'ستُضاف مباشرة',
                        Colors.green,
                        Icons.add_circle_outline,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'متطابقة تماماً',
                        '${widget.analysis.identicalProducts.length}',
                        'تُتخطى تلقائياً',
                        Colors.grey,
                        Icons.skip_next,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'اختلاف أسعار',
                        '${widget.analysis.conflicts.length}',
                        'تطلب قرارك',
                        Colors.amber[800]!,
                        Icons.warning_amber_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Global Action Selection ("Copy/Paste" style Apply All)
                  if (widget.analysis.hasConflicts) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.copy_all, color: AppTheme.primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'تطبيق قرار جماعي على جميع التعارضات:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _applyGlobalAction(ConflictAction.overwrite),
                                  icon: const Icon(Icons.published_with_changes, size: 16),
                                  label: const Text('تحديث الكل بالجديد'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _applyGlobalAction(ConflictAction.keepExisting),
                                  icon: const Icon(Icons.shield_outlined, size: 16),
                                  label: const Text('الإبقاء على الحالي للكل'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manual Review Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'مراجعة المنتجات المتعارضة عنصرًا بعنصر:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isManualReview,
                          activeThumbColor: AppTheme.primaryColor,
                          onChanged: (val) => setState(() => _isManualReview = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Itemized Conflicts List
                    if (_isManualReview)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _conflicts.length,
                        itemBuilder: (context, index) {
                          final conflict = _conflicts[index];
                          return _buildConflictItemCard(conflict, index);
                        },
                      ),
                  ] else ...[
                    // No Conflicts Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                          SizedBox(height: 10),
                          Text(
                            'ممتاز! لا يوجد أي تعارض في الأسعار',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'تم تصفية الملف وتلقائياً تخطي المنتجات المطابقة، وجاهز لاستيراد المنتجات الجديدة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Execution Button Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
            ),
            child: ElevatedButton.icon(
              onPressed: _confirmAndExecute,
              icon: const Icon(Icons.download_done),
              label: Text(
                'تأكيد الاستيراد (${widget.analysis.newProducts.length} جديد, ${_conflicts.where((c) => c.action == ConflictAction.overwrite).length} تحديث)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, String subtitle, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictItemCard(ProductImportConflict conflict, int index) {
    final theme = Theme.of(context);
    final existing = conflict.existingProduct;
    final imported = conflict.importedProduct;
    final isOverwrite = conflict.action == ConflictAction.overwrite;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existing.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (existing.barcode.isNotEmpty)
              Text('الباركود: ${existing.barcode}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),

            // Price Comparison Row
            Row(
              children: [
                // Local Price Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !isOverwrite ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: !isOverwrite ? Colors.green : Colors.transparent),
                    ),
                    child: Column(
                      children: [
                        const Text('السعر الحالي بالمحل:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.formatPrice(existing.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: !isOverwrite ? Colors.green[800] : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                const SizedBox(width: 8),

                // Imported Price Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isOverwrite ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isOverwrite ? AppTheme.primaryColor : Colors.transparent),
                    ),
                    child: Column(
                      children: [
                        const Text('السعر في الملف المستورد:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.formatPrice(imported.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isOverwrite ? AppTheme.primaryColor : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Radio Options for this item
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: isOverwrite,
                    label: const Text('تحديث بالسعر الجديد'),
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(color: isOverwrite ? Colors.white : theme.colorScheme.onSurface, fontSize: 12),
                    onSelected: (val) {
                      setState(() {
                        conflict.action = ConflictAction.overwrite;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    selected: !isOverwrite,
                    label: const Text('الاحتفاظ بالسعر الحالي'),
                    selectedColor: Colors.green,
                    labelStyle: TextStyle(color: !isOverwrite ? Colors.white : theme.colorScheme.onSurface, fontSize: 12),
                    onSelected: (val) {
                      setState(() {
                        conflict.action = ConflictAction.keepExisting;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
