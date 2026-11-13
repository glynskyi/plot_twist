import 'package:flutter/services.dart';

/// Copies [url] to the clipboard, because there is no browser to open it in.
///
/// Returns false: the link was not opened.
Future<bool> openUrl(String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  return false;
}
