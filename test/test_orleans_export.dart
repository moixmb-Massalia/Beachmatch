import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Test save and sharePdf signature', () async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) => pw.Center(child: pw.Text("Test PDF Landscape")),
      ),
    );
    final bytes = await doc.save();
    expect(bytes.isNotEmpty, true);
  });
}
