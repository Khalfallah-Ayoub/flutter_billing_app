import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/invoice.dart';
import '../../../../core/data/hive_database.dart';
import '../../../shop/data/models/shop_model.dart';

class InvoicePdfService {
  /// Generate a PDF Document for an invoice
  static Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();

    // Fetch shop details from Hive
    ShopModel? shopInfo;
    try {
      shopInfo = HiveDatabase.shopBox.get('info');
    } catch (_) {}

    final shopName = shopInfo?.name ?? 'متجر الأنابيب ومواد البناء';
    final shopPhone = shopInfo?.phoneNumber ?? '0660 00 00 00';
    final shopAddress = shopInfo != null
        ? '${shopInfo.addressLine1} ${shopInfo.addressLine2}'.trim()
        : 'الجزائر';

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Font loading for Arabic support in PDF
    final arabicFont = await PdfGoogleFonts.cairoMedium();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shopName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('الهاتف: $shopPhone', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('العنوان: $shopAddress', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'فاتورة مبيعات',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('رقم الفاتورة: ${invoice.invoiceNumber}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('التاريخ: ${dateFormat.format(invoice.createdAt)}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 12),

              // 2. Customer Info Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الزبون: ${invoice.customerName}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty)
                      pw.Text('الهاتف: ${invoice.customerPhone}',
                          style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(
                      'طريقة الدفع: ${invoice.paymentMethod == 'cash' ? 'نقداً' : 'دين'}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // 3. Items Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
                headerHeight: 28,
                cellHeight: 24,
                cellAlignment: pw.Alignment.centerRight,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: <String>['المنتج / البيان', 'السعر الفردي', 'الكمية', 'الإجمالي'],
                data: invoice.items.map((item) {
                  final qtyStr = item.isPipe
                      ? '${item.quantity} متر'
                      : '${item.quantity.toInt()} ${item.unit}';
                  return [
                    item.productName,
                    '${item.unitPrice.toStringAsFixed(2)} دج',
                    qtyStr,
                    '${item.subtotal.toStringAsFixed(2)} دج',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),

              // 4. Financial Totals & Debt Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // QR code / Notes
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'INVOICE:${invoice.invoiceNumber}|TOTAL:${invoice.totalAmount}',
                        width: 70,
                        height: 70,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('شكراً لزيارتكم وطيب تعاملكم معنا!',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  // Totals Box
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        _buildTotalRow('المجموع الصافي:', '${invoice.subtotal.toStringAsFixed(2)} دج'),
                        if (invoice.discount > 0)
                          _buildTotalRow('الخصم:', '-${invoice.discount.toStringAsFixed(2)} دج'),
                        pw.Divider(color: PdfColors.grey300),
                        _buildTotalRow(
                          'المبلغ الإجمالي:',
                          '${invoice.totalAmount.toStringAsFixed(2)} دج',
                          isBold: true,
                        ),
                        _buildTotalRow('المبلغ المدفوع:', '${invoice.paidAmount.toStringAsFixed(2)} دج'),
                        pw.Divider(color: PdfColors.grey300),
                        _buildTotalRow(
                          'المبلغ المتبقي (الدين):',
                          '${invoice.remainingAmount.toStringAsFixed(2)} دج',
                          isBold: true,
                          color: invoice.remainingAmount > 0 ? PdfColors.red800 : PdfColors.green800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 5. Payment Installments History Table (إذا وجدت دفعات مسجلة)
              if (invoice.paymentHistory.isNotEmpty) ...[
                pw.Text(
                  'سجل دفعات الأقساط وتسديد الدين:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.amber50),
                  headerHeight: 22,
                  cellHeight: 20,
                  cellAlignment: pw.Alignment.centerRight,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headers: <String>['#', 'تاريخ الدفعة', 'المبلغ المدفوع', 'ملاحظات'],
                  data: invoice.paymentHistory.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final p = entry.value;
                    return [
                      '$idx',
                      dateFormat.format(p.date),
                      '${p.amount.toStringAsFixed(2)} دج',
                      p.note ?? 'تسديد جزء من الدين',
                    ];
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTotalRow(String label, String value,
      {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? PdfColors.black,
              )),
        ],
      ),
    );
  }

  /// Print invoice using available thermal/PDF printer
  static Future<void> printInvoice(Invoice invoice) async {
    final pdfBytes = await generateInvoicePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Invoice-${invoice.invoiceNumber}.pdf',
    );
  }

  /// Share Invoice PDF to WhatsApp or other apps
  static Future<void> shareInvoicePdf(Invoice invoice) async {
    final pdfBytes = await generateInvoicePdf(invoice);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(pdfBytes);

    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      text: '📄 فاتورة مبيعات رقم ${invoice.invoiceNumber}\nالزبون: ${invoice.customerName}\nالإجمالي: ${invoice.totalAmount} دج',
    );
  }

  /// Direct WhatsApp Text Message with phone number
  static Future<void> sendInvoiceToWhatsApp(Invoice invoice) async {
    final phone = invoice.customerPhone?.replaceAll(RegExp(r'\s+'), '') ?? '';
    final message = Uri.encodeComponent(
      '📄 *فاتورة مبيعات - ${invoice.invoiceNumber}*\n'
      'مرحباً بك ${invoice.customerName} 👋\n'
      '--------------------------------\n'
      '• إجمالي الفاتورة: *${invoice.totalAmount} دج*\n'
      '• المدفوع: *${invoice.paidAmount} دج*\n'
      '• المتبقي (الدين): *${invoice.remainingAmount} دج*\n'
      '--------------------------------\n'
      'شكراً لتعاملكم معنا! 🌹',
    );

    final String url;
    if (phone.isNotEmpty) {
      final formattedPhone = phone.startsWith('0') ? '+213${phone.substring(1)}' : phone;
      url = 'https://wa.me/$formattedPhone?text=$message';
    } else {
      url = 'https://wa.me/?text=$message';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Direct Phone Call to Customer
  static Future<void> callCustomer(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
