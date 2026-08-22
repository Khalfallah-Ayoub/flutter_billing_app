import 'dart:io';
import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/image_storage_service.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _price;
  late String _category;
  late String _brand;
  late String _size;
  late String _description;
  late String _usageInstructions;
  late List<String> _existingImagePaths;
  final List<File> _newImages = [];
  final ImageStorageService _imageService = ImageStorageService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _price = widget.product.price;
    _category = widget.product.category ?? '';
    _brand = widget.product.brand ?? '';
    _size = widget.product.size ?? '';
    _description = widget.product.description ?? '';
    _usageInstructions = widget.product.usageInstructions ?? '';
    _existingImagePaths = List<String>.from(widget.product.imagePaths);
  }

  int get _totalImages => _existingImagePaths.length + _newImages.length;

  Future<void> _capturePhoto() async {
    if (_totalImages >= 3) {
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
      setState(() => _newImages.add(file));
    }
  }

  Future<void> _pickPhoto() async {
    if (_totalImages >= 3) {
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
      setState(() => _newImages.add(file));
    }
  }

  void _removeExistingImage(int index) {
    final path = _existingImagePaths[index];
    _imageService.deleteProductImage(path);
    setState(() => _existingImagePaths.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isSaving = true);

      // Save new images
      List<String> newPaths = [];
      for (final img in _newImages) {
        final path =
            await _imageService.saveProductImage(widget.product.id, img);
        if (path != null) newPaths.add(path);
      }

      final allPaths = [..._existingImagePaths, ...newPaths];

      final updatedProduct = widget.product.copyWith(
        name: _name,
        price: _price,
        category: _category.isEmpty ? null : _category,
        brand: _brand.isEmpty ? null : _brand,
        size: _size.isEmpty ? null : _size,
        description: _description.isEmpty ? null : _description,
        usageInstructions: _usageInstructions.isEmpty ? null : _usageInstructions,
        imagePaths: allPaths,
      );

      if (mounted) {
        context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 32, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Product',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Barcode details (immutable block)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner,
                          color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BARCODE',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.7))),
                          const SizedBox(height: 2),
                          Text(widget.product.barcode,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- Product Name ---
                const InputLabel(text: 'Product Name'),
                TextFormField(
                  initialValue: _name,
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required('Please enter a name'),
                  onSaved: (value) => _name = value!,
                ),
                const SizedBox(height: 24),

                // --- Price ---
                const InputLabel(text: 'Price'),
                TextFormField(
                  initialValue: _price.toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    suffixText: ' د.ج',
                    prefixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black),
                  ),
                  validator: AppValidators.price,
                  onSaved: (value) => _price = double.parse(value!),
                ),
                const SizedBox(height: 24),

                // --- Category (optional) ---
                const InputLabel(text: 'Category (optional)'),
                TextFormField(
                  initialValue: _category,
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
                  initialValue: _brand,
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
                  initialValue: _size,
                  decoration: const InputDecoration(
                    hintText: 'e.g. M8 x 30mm, 16A',
                  ),
                  onSaved: (value) => _size = value ?? '',
                ),
                const SizedBox(height: 24),

                // --- Description (optional) ---
                const InputLabel(text: 'وصف المنتج (اختياري - للمساعد الذكي)'),
                TextFormField(
                  initialValue: _description,
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
                  initialValue: _usageInstructions,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'طريقة الاستعمال أو تعليمات السلامة والتركيب للمستخدم',
                  ),
                  onSaved: (value) => _usageInstructions = value ?? '',
                ),
                const SizedBox(height: 24),

                // --- Product Images ---
                const InputLabel(text: 'Product Images (max 3)'),
                const SizedBox(height: 8),
                _buildImageSection(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PrimaryButton(
        onPressed: _isSaving ? null : _submit,
        icon: _isSaving ? Icons.hourglass_top : Icons.save,
        label: _isSaving ? 'Saving...' : 'Save Changes',
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        // Existing + new images preview
        if (_totalImages > 0) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _totalImages,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isExisting = index < _existingImagePaths.length;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildImageWidget(index, isExisting),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => isExisting
                            ? _removeExistingImage(index)
                            : _removeNewImage(
                                index - _existingImagePaths.length),
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
                    // Badge for new images
                    if (!isExisting)
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NEW',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 8)),
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
        if (_totalImages < 3)
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

  Widget _buildImageWidget(int index, bool isExisting) {
    if (kIsWeb) {
      return Container(
        width: 100,
        height: 100,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: const Icon(Icons.image,
            color: AppTheme.primaryColor, size: 40),
      );
    }

    if (isExisting) {
      final path = _existingImagePaths[index];
      return Image.file(
        File(path),
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 100,
          height: 100,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      final newIndex = index - _existingImagePaths.length;
      return Image.file(
        _newImages[newIndex],
        width: 100,
        height: 100,
        fit: BoxFit.cover,
      );
    }
  }
}
