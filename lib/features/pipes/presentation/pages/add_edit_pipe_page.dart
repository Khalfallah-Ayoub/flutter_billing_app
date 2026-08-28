import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';

import '../../domain/entities/pipe_category.dart';
import '../../data/services/pipe_category_service.dart';

class AddEditPipePage extends StatefulWidget {
  final Product? pipe;

  const AddEditPipePage({super.key, this.pipe});

  @override
  State<AddEditPipePage> createState() => _AddEditPipePageState();
}

class _AddEditPipePageState extends State<AddEditPipePage> {
  final _formKey = GlobalKey<FormState>();

  late List<PipeCategory> _availableCategories;
  String _pipeType = 'pvc';
  final TextEditingController _diameterController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController(text: '6.0');
  final TextEditingController _fullPriceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController(text: '10');
  final TextEditingController _originController = TextEditingController(text: 'الجزائر');
  final TextEditingController _colorController = TextEditingController(text: 'أبيض');
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _usageController = TextEditingController();

  double _calculatedPricePerMeter = 0.0;

  bool get isEditing => widget.pipe != null;

  @override
  void initState() {
    super.initState();
    _availableCategories = PipeCategoryService.getCategories();
    if (isEditing) {
      final p = widget.pipe!;
      _pipeType = p.pipeType ?? 'pvc';
      _diameterController.text = p.diameter ?? p.size ?? '';
      _lengthController.text = (p.fullLength ?? _getDefaultLength(_pipeType)).toString();
      _fullPriceController.text = (p.fullPrice ?? p.price).toString();
      _costPriceController.text = p.costPrice > 0 ? p.costPrice.toString() : '';
      _stockController.text = p.stock.toString();
      _originController.text = p.origin ?? 'الجزائر';
      _colorController.text = p.color ?? 'أبيض';
      _descController.text = p.description ?? '';
      _usageController.text = p.usageInstructions ?? '';
    } else {
      if (_availableCategories.isNotEmpty) {
        _pipeType = _availableCategories.first.name;
        _lengthController.text = _availableCategories.first.defaultLength.toString();
      }
    }
    _recalculateMeterRate();

    _fullPriceController.addListener(_recalculateMeterRate);
    _lengthController.addListener(_recalculateMeterRate);
  }

  @override
  void dispose() {
    _diameterController.dispose();
    _lengthController.dispose();
    _fullPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _originController.dispose();
    _colorController.dispose();
    _descController.dispose();
    _usageController.dispose();
    super.dispose();
  }

  double _getDefaultLength(String typeName) {
    return PipeCategoryService.getDefaultLengthForType(typeName);
  }

  void _onPipeTypeChanged(String newType) {
    setState(() {
      _pipeType = newType;
      // Auto-update length to default if user hasn't heavily customized it
      _lengthController.text = _getDefaultLength(newType).toString();
    });
    _recalculateMeterRate();
  }

  void _recalculateMeterRate() {
    final price = double.tryParse(_fullPriceController.text) ?? 0.0;
    final length = double.tryParse(_lengthController.text) ?? 0.0;
    setState(() {
      if (length > 0) {
        _calculatedPricePerMeter = price / length;
      } else {
        _calculatedPricePerMeter = 0.0;
      }
    });
  }

  String _generatePipeName() {
    String typeLabel = _pipeType.contains('أنبوب') ? _pipeType : 'أنبوب $_pipeType';
    final dia = _diameterController.text.trim();
    final color = _colorController.text.trim();
    final origin = _originController.text.trim();

    List<String> parts = [typeLabel];
    if (dia.isNotEmpty) parts.add(dia.startsWith('Ø') ? dia : 'Ø $dia');
    if (color.isNotEmpty) parts.add('($color)');
    if (origin.isNotEmpty) parts.add('[$origin]');

    return parts.join(' ');
  }

  void _savePipe() {
    if (_formKey.currentState!.validate()) {
      final name = _generatePipeName();
      final fullPrice = double.parse(_fullPriceController.text.trim());
      final fullLength = double.parse(_lengthController.text.trim());
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;
      final diameter = _diameterController.text.trim();
      final origin = _originController.text.trim();
      final color = _colorController.text.trim();
      final description = _descController.text.trim();
      final usage = _usageController.text.trim();
      final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
      final pricePerMeter = fullLength > 0 ? (fullPrice / fullLength) : fullPrice;

      final pipeProduct = Product(
        id: isEditing ? widget.pipe!.id : const Uuid().v4(),
        name: name,
        barcode: isEditing ? widget.pipe!.barcode : 'PIPE-${DateTime.now().millisecondsSinceEpoch}',
        price: pricePerMeter, // Store price per meter in standard price field for catalog compatibility
        costPrice: costPrice, // Total cost for the full pipe
        stock: stock,
        isPipe: true,
        pipeType: _pipeType,
        fullLength: fullLength,
        fullPrice: fullPrice,
        diameter: diameter,
        origin: origin,
        color: color,
        description: description.isNotEmpty ? description : null,
        usageInstructions: usage.isNotEmpty ? usage : null,
        category: 'أنابيب (Pipes)',
        size: diameter,
        brand: origin,
      );

      if (isEditing) {
        context.read<ProductBloc>().add(UpdateProduct(pipeProduct));
      } else {
        context.read<ProductBloc>().add(AddProduct(pipeProduct));
      }

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل بيانات الأنبوب' : 'إضافة أنبوب جديد',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Selector Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'نوع الفئة / المادة (Material Category):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await context.push('/pipes/categories');
                      setState(() {
                        _availableCategories = PipeCategoryService.getCategories();
                      });
                    },
                    icon: const Icon(Icons.settings_suggest, size: 18),
                    label: const Text('إدارة الفئات', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableCategories.map<Widget>((cat) {
                  final isSelected = _pipeType.trim().toLowerCase() == cat.name.trim().toLowerCase() ||
                      _pipeType.trim().toLowerCase() == cat.id.toLowerCase();
                  return ChoiceChip(
                    label: Text('${cat.name} (${cat.defaultLength}م)'),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : theme.dividerColor.withValues(alpha: 0.2)),
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : theme.colorScheme.onSurface,
                    ),
                    onSelected: (val) {
                      if (val) {
                        _onPipeTypeChanged(cat.name);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Dynamic Specs Form Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Diameter / Size Input
                    Text(
                      'القطر / المقاييس (Diameter / Size):',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _diameterController,
                      decoration: const InputDecoration(
                        hintText: 'مثلاً: 110 أو 50 أو 16 أو Ø22',
                        prefixIcon: Icon(Icons.architecture),
                      ),
                      validator: AppValidators.required('يرجى كتابة مقياس الأنبوب'),
                    ),
                    const SizedBox(height: 8),
                    // Quick Chips for Diameter
                    Wrap(
                      spacing: 6,
                      children: ['110', '90', '75', '50', '40', '16', '22'].map((d) {
                        return ActionChip(
                          label: Text('Ø $d'),
                          onPressed: () {
                            _diameterController.text = d;
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Country of Origin & Color Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('بلد الصنع (Origin):', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _originController,
                                decoration: const InputDecoration(
                                  hintText: 'الجزائر / فرنسا / إيطاليا',
                                  prefixIcon: Icon(Icons.flag_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('اللون (Color):', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _colorController,
                                decoration: const InputDecoration(
                                  hintText: 'أبيض / أسود / رمادي',
                                  prefixIcon: Icon(Icons.palette_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Length & Price Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('طول الأنبوب الأصلي (متر):', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _lengthController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  suffixText: 'متر',
                                  prefixIcon: Icon(Icons.straighten),
                                ),
                                validator: AppValidators.required('أدخل الطول'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('سعر الأنبوب الكامل:', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _fullPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  suffixText: AppConstants.currencySymbol,
                                  prefixIcon: Icon(Icons.attach_money),
                                ),
                                validator: AppValidators.required('أدخل السعر'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Price per Meter Indicator Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calculate, color: AppTheme.primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'سعر المتر التلقائي:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                          Text(
                            '${AppConstants.formatPrice(_calculatedPricePerMeter)} / متر',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cost Price & Stock Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('سعر شراء الأنبوب (التكلفة):', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _costPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  suffixText: AppConstants.currencySymbol,
                                  prefixIcon: Icon(Icons.price_change_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الكمية المتوفرة:', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '10 أنابيب',
                                  prefixIcon: Icon(Icons.inventory_2_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // AI Assistant Optional Fields
                    Text('وصف المادة (اختياري - للمساعد الذكي):',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'مثلاً: أنبوب مائي عالي التحمل للحرارة والضغط',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text('طريقة/تعليمات الاستعمال (اختياري - للمساعد الذكي):',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usageController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'مثلاً: يتم التلحيم بالحرارة أو التوصيل بالضغط للمياه الصالحة للشرب',
                        prefixIcon: Icon(Icons.integration_instructions_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton.icon(
                onPressed: _savePipe,
                icon: Icon(isEditing ? Icons.save : Icons.add_circle),
                label: Text(
                  isEditing ? 'حفظ التعديلات' : 'إضافة الأنبوب إلى المخزن',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChoiceChip(String type, String label, String defaultLen, Color accentColor) {
    final isSelected = _pipeType == type;
    return Expanded(
      child: InkWell(
        onTap: () => _onPipeTypeChanged(type),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.15) : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                  color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  defaultLen,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
