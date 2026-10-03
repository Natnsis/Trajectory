import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Thin wrappers over OS integrations. Every call fails soft: a missing
/// notifier or mail client never breaks the app.
class PlatformServices {
  const PlatformServices();

  /// Opens a website in the default browser. Accepts bare domains.
  Future<bool> openSite(String site) {
    final url = site.startsWith('http') ? site : 'https://$site';
    return _launch(Uri.parse(url));
  }

  /// Opens the default mail client with a drafted message. Nothing is sent
  /// without the user pressing Send.
  Future<bool> draftEmail({required String to, required String subject, required String body}) => _launch(
        Uri(scheme: 'mailto', path: to, query: _query({'subject': subject, 'body': body})),
      );

  /// Desktop notification (Linux: notify-send / libnotify, macOS: osascript).
  Future<void> notify(String title, String body) async {
    try {
      if (Platform.isLinux) {
        await Process.run('notify-send', ['--app-name=Trajectory', title, body]);
      } else if (Platform.isMacOS) {
        final esc = (String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
        await Process.run('osascript', ['-e', 'display notification "${esc(body)}" with title "${esc(title)}"']);
      }
    } catch (_) {
      // No notifier available; notifications are best-effort.
    }
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  // mailto wants %20 for spaces, not '+', so encode manually.
  static String _query(Map<String, String> q) =>
      q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
}
