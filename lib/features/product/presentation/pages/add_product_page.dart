import 'dart:io';
import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/image_storage_service.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  double _costPrice = 0.0;
  String _category = '';
  String _brand = '';
  String _size = '';
  String _description = '';
  String _usageInstructions = '';
  final List<File> _capturedImages = [];
  final ImageStorageService _imageService = ImageStorageService();
  bool _isSaving = false;

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_capturedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final file = await _imageService.captureImage();
    if (file != null) {
      setState(() => _capturedImages.add(file));
    }
  }

  Future<void> _pickPhoto() async {
    if (_capturedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final file = await _imageService.pickImage();
    if (file != null) {
      setState(() => _capturedImages.add(file));
    }
  }

  void _removeImage(int index) {
    setState(() => _capturedImages.removeAt(index));
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode "$_barcode" already exists!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSaving = true);

      final productId = const Uuid().v4();

      // Save images locally
      List<String> savedPaths = [];
      for (final img in _capturedImages) {
        final path = await _imageService.saveProductImage(productId, img);
        if (path != null) savedPaths.add(path);
      }

      final product = Product(
        id: productId,
        name: _name,
        barcode: _barcode,
        price: _price,
        costPrice: _costPrice,
        category: _category.isEmpty ? null : _category,
        brand: _brand.isEmpty ? null : _brand,
        size: _size.isEmpty ? null : _size,
        description: _description.isEmpty ? null : _description,
        usageInstructions: _usageInstructions.isEmpty ? null : _usageInstructions,
        imagePaths: savedPaths,
      );

      if (mounted) {
        context.read<ProductBloc>().add(AddProduct(product));
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Add Product',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Barcode ---
                const InputLabel(text: 'Barcode'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(_barcode),
                        initialValue: _barcode,
                        decoration: const InputDecoration(
                          hintText: 'Scan or enter barcode',
                        ),
                        validator:
                            AppValidators.required('Please enter a barcode'),
                        onSaved: (value) => _barcode = value!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: AppTheme.primaryColor),
                        onPressed: _scanBarcode,
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Tap the icon to open camera scanner',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                const SizedBox(height: 24),

                // --- Product Name ---
                const InputLabel(text: 'Product Name'),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'e.g. Basmati Rice',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required('Please enter a name'),
                  onSaved: (value) => _name = value!,
                ),
                const SizedBox(height: 24),

                // --- Price ---
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const InputLabel(text: 'سعر البيع *'),
                          TextFormField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              suffixText: ' د.ج',
                            ),
                            validator: AppValidators.price,
                            onSaved: (value) => _price = double.parse(value!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const InputLabel(text: 'سعر التكلفة / الشراء'),
                          TextFormField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              suffixText: ' د.ج',
                            ),
                            onSaved: (value) => _costPrice = double.tryParse(value ?? '') ?? 0.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Category (optional) ---
                const InputLabel(text: 'Category (optional)'),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'e.g. Fasteners, Electrical',
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSaved: (value) => _category = value ?? '',
                ),
                const SizedBox(height: 24),

                // --- Brand (optional) ---
                const InputLabel(text: 'Brand (optional)'),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'e.g. Bosch, Fischer',
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSaved: (value) => _brand = value ?? '',
                ),
                const SizedBox(height: 24),

                // --- Size (optional) ---
                const InputLabel(text: 'Size / Dimensions (optional)'),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'e.g. M8 x 30mm, 16A',
                  ),
                  onSaved: (value) => _size = value ?? '',
                ),
                const SizedBox(height: 24),

                // --- Description (optional) ---
                const InputLabel(text: 'وصف المنتج (اختياري - للمساعد الذكي)'),
                TextFormField(
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'وصف خاص بمكونات أو خامات المنتج لتوليد اقتراحات المساعد الذكي',
                  ),
                  onSaved: (value) => _description = value ?? '',
                ),
                const SizedBox(height: 24),

                // --- Usage Instructions (optional) ---
                const InputLabel(text: 'كيفية الاستعمال والتركيب (اختياري - للمساعد الذكي)'),
                TextFormField(
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'طريقة الاستعمال أو تعليمات السلامة والتركيب للمستخدم',
                  ),
                  onSaved: (value) => _usageInstructions = value ?? '',
                ),
                const SizedBox(height: 24),

                // --- Product Images ---
                const InputLabel(text: 'Product Images (optional, max 3)'),
                const SizedBox(height: 8),
                _buildImageSection(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PrimaryButton(
        onPressed: _isSaving ? null : _submit,
        icon: _isSaving ? Icons.hourglass_top : Icons.add_circle,
        label: _isSaving ? 'Saving...' : 'Add Product',
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        // Captured images preview
        if (_capturedImages.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _capturedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? Container(
                              width: 100,
                              height: 100,
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              child: const Icon(Icons.image,
                                  color: AppTheme.primaryColor, size: 40),
                            )
                          : Image.file(
                              _capturedImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Add image buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
