import 'dart:typed_data';
import 'web_file_downloader_stub.dart'
    if (dart.library.html) 'web_file_downloader_web.dart' as platform_impl;

class WebFileDownloader {
  static Future<bool> download(Uint8List bytes, String filename) async {
    return await platform_impl.downloadFileOnWeb(bytes, filename);
  }
}
