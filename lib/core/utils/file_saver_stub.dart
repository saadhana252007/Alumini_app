import 'dart:typed_data';

Future<String> saveBytes({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  throw UnsupportedError('File saving is not supported on this platform.');
}
