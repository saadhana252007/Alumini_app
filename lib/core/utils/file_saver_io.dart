import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveBytes({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final mobile = Platform.isAndroid || Platform.isIOS;
  final Directory dir = mobile
      ? await getTemporaryDirectory()
      : (await getDownloadsDirectory()) ??
          await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  if (mobile) {
    // Hands the file to the OS share sheet so it can be saved / sent.
    await Share.shareXFiles([XFile(file.path, mimeType: mimeType)],
        subject: fileName);
  }
  return file.path;
}
