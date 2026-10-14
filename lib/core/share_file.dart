import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [bytes] to a temporary file and opens the Android share sheet
/// (WhatsApp, Gmail, Drive, Bluetooth...).
Future<void> shareBytes(
  Uint8List bytes,
  String fileName, {
  required String mimeType,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      text: text,
    ),
  );
}
