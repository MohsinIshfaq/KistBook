import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../core/utils/currency_helper.dart';
import '../../data/models/dashboard_models.dart';

class PdfGenerator {
  static Future<List<int>> buildDueInstallmentReport({
    required DateTime date,
    required List<DueInstallmentDetail> dueItems,
  }) async {
    final document = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Daily Due Installments',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Date: ${dateFormat.format(date)}'),
          pw.SizedBox(height: 16),
          if (dueItems.isEmpty)
            pw.Text('No installments are due today.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Customer', 'Phone', 'CNIC', 'Item', 'Payable'],
              data: dueItems
                  .map(
                    (item) => [
                      item.customer.name,
                      item.customer.phone,
                      item.customer.cnic,
                      item.product?.name ?? item.plan.itemName,
                      CurrencyHelper.pkr.format(item.installment.remainingAmount),
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );

    return document.save();
  }
}
