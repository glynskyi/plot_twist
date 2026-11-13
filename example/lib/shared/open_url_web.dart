import 'dart:js_interop';

@JS('window.open')
external JSAny? _windowOpen(String url, String target, String features);

/// Opens [url] in a new browser tab.
///
/// Returns true: the link was opened.
Future<bool> openUrl(String url) async {
  _windowOpen(url, '_blank', 'noopener');
  return true;
}
