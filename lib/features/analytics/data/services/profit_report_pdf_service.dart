import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../invoice/domain/entities/invoice.dart';
import '../../../expense/domain/entities/expense.dart';

class ProfitReportPdfService {
  static Future<void> printFinancialReport({
    required String timeFrameLabel,
    required double grossRevenue,
    required double totalCost,
    required double grossProfit,
    required double totalExpenses,
    required double netProfit,
    required List<Invoice> invoices,
    required List<Expense> expenses,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Title
                pw.Center(
                  child: pw.Text(
                    'تقرير الأرباح والتحليلات المالية - $timeFrameLabel',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'تاريخ التقرير: ${dateFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
                pw.SizedBox(height: 20),

                // Financial Overview Table Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    children: [
                      _buildPdfRow('إجمالي المبيعات (الإيرادات)', '${grossRevenue.toStringAsFixed(2)} دج', fontBold),
                      _buildPdfRow('إجمالي تكلفة المنتجات والمشتريات', '-${totalCost.toStringAsFixed(2)} دج', fontBold),
                      pw.Divider(),
                      _buildPdfRow('الأرباح الإجمالية (Gross Profit)', '${grossProfit.toStringAsFixed(2)} دج', fontBold, isHeader: true),
                      _buildPdfRow('إجمالي النفقات والمصاريف اليومية', '-${totalExpenses.toStringAsFixed(2)} دج', fontBold),
                      pw.Divider(),
                      _buildPdfRow(
                        'صافي الأرباح النهائية (Net Profit)',
                        '${netProfit.toStringAsFixed(2)} دج',
                        fontBold,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Summary Stats
                pw.Text('ملخص العمليات الفعالة:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.Text('• عدد الفواتير الصادرة: ${invoices.length} فاتورة'),
                pw.Text('• عدد النفقات المسجلة: ${expenses.length} عملية مصروفات'),
                pw.SizedBox(height: 24),

                // Footer
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'تم إنشاء التقرير المالي بواسطة نظام إدارة الفواتير والأرباح الذكي',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Financial_Profit_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildPdfRow(String label, String value, pw.Font fontBold,
      {bool isBold = false, bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold || isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isHeader ? 12 : 11,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold || isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isHeader ? 12 : 11,
              color: isHeader ? PdfColors.blue800 : (isBold ? PdfColors.green800 : PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
