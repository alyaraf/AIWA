import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/l10n.dart';

/// Opens [uri] in another app (dialer, WhatsApp, maps, browser) and tells the
/// user when nothing could open it (H-5). No `canLaunchUrl` guard: it answers
/// false on Android 11+ / iOS for any scheme missing from the manifest
/// `<queries>` or `LSApplicationQueriesSchemes`, which made the button do
/// nothing at all.
Future<void> openExternal(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).linkOpenFailed)),
    );
  }
}
