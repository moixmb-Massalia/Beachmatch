// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> downloadFileOnWeb(Uint8List bytes, String filename) async {
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();

    // Clean up safely after download initiates
    Future.delayed(const Duration(seconds: 5), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
    return true;
  } catch (e) {
    return false;
  }
}
