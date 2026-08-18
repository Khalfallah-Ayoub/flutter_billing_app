import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/recognition_bloc.dart';
import '../../domain/entities/ranked_product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_storage_service.dart';
import '../../../../core/service_locator.dart' show sl;

class SmartRecognitionPage extends StatefulWidget {
  const SmartRecognitionPage({super.key});

  @override
  State<SmartRecognitionPage> createState() => _SmartRecognitionPageState();
}

class _SmartRecognitionPageState extends State<SmartRecognitionPage> {
  final ImageStorageService _imageService = ImageStorageService();
  String? _capturedImagePath;

  Future<void> _captureAndRecognize(BuildContext blocContext) async {
    final file = await _imageService.captureImage();
    if (file != null) {
      setState(() => _capturedImagePath = file.path);
      blocContext
          .read<RecognitionBloc>()
          .add(RecognizeFromImage(file.path));
    }
  }

  Future<void> _pickAndRecognize(BuildContext blocContext) async {
    final file = await _imageService.pickImage();
    if (file != null) {
      setState(() => _capturedImagePath = file.path);
      blocContext
          .read<RecognitionBloc>()
          .add(RecognizeFromImage(file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecognitionBloc>(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Smart Recognition',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: BlocBuilder<RecognitionBloc, RecognitionState>(
            builder: (blocContext, state) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image preview area
                    _buildImagePreview(state),
                    const SizedBox(height: 16),

                    // Capture buttons
                    if (state.status != RecognitionStatus.processing)
                      _buildCaptureButtons(blocContext),
                    const SizedBox(height: 16),

                    // Status / Loading
                    if (state.status == RecognitionStatus.processing)
                      _buildProcessingIndicator(),

                    // OCR extracted text
                    if (state.ocrResult != null && state.ocrResult!.hasText)
                      _buildOcrInfo(state),

                    // Results
                    if (state.status == RecognitionStatus.success &&
                        state.results.isNotEmpty)
                      _buildResults(blocContext, state),

                    // No results
                    if (state.status == RecognitionStatus.success &&
                        state.results.isEmpty &&
                        state.errorMessage != null)
                      _buildNoResults(state),

                    // Error
                    if (state.status == RecognitionStatus.error)
                      _buildError(state),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(RecognitionState state) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _capturedImagePath != null && !kIsWeb
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(_capturedImagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                ),
                if (state.status == RecognitionStatus.processing)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_camera_outlined,
            size: 48,
            color: AppTheme.primaryColor.withValues(alpha: 0.4)),
        const SizedBox(height: 8),
        Text(
          'Take a photo of the product',
          style: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'The AI will try to identify it',
          style: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButtons(BuildContext blocContext) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _captureAndRecognize(blocContext),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickAndRecognize(blocContext),
            icon: const Icon(Icons.photo_library, size: 20),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Analyzing product...',
              style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Running OCR + Visual matching',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOcrInfo(RecognitionState state) {
    final ocr = state.ocrResult!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text('Detected Text',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey[600],
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ocr.fullText.length > 100
                ? '${ocr.fullText.substring(0, 100)}...'
                : ocr.fullText,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
          if (ocr.detectedBrand != null) ...[
            const SizedBox(height: 6),
            Chip(
              label: Text('Brand: ${ocr.detectedBrand}'),
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.1),
              labelStyle: const TextStyle(fontSize: 11),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
          if (ocr.detectedSize != null) ...[
            const SizedBox(height: 4),
            Chip(
              label: Text('Size: ${ocr.detectedSize}'),
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              labelStyle: const TextStyle(fontSize: 11),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext blocContext, RecognitionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Matches Found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Tap to confirm the correct product',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 12),
        ...state.results.asMap().entries.map((entry) {
          final index = entry.key;
          final result = entry.value;
          return _buildResultCard(blocContext, result, index == 0);
        }),
      ],
    );
  }

  Widget _buildResultCard(
      BuildContext blocContext, RankedProduct result, bool isTopMatch) {
    final product = result.product;
    final scoreColor = result.finalScore > 0.7
        ? Colors.green
        : result.finalScore > 0.4
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTopMatch
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : Colors.grey[200]!,
          width: isTopMatch ? 2 : 1,
        ),
        boxShadow: isTopMatch
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: InkWell(
        onTap: () {
          if (_capturedImagePath != null) {
            blocContext.read<RecognitionBloc>().add(
                  ConfirmRecognition(product, _capturedImagePath!),
                );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${product.name} confirmed!'),
                backgroundColor: Colors.green,
              ),
            );
            // Return the product to the billing page
            context.pop(product);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Score circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${result.percentScore}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isTopMatch) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('BEST',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('₹${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                        if (product.brand != null) ...[
                          const SizedBox(width: 8),
                          Text('• ${product.brand}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                        ],
                        if (product.size != null) ...[
                          const SizedBox(width: 8),
                          Text('• ${product.size}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults(RecognitionState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 40, color: Colors.orange),
          const SizedBox(height: 8),
          Text(state.errorMessage ?? 'No matches found',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Try capturing from a different angle',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError(RecognitionState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(state.errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
