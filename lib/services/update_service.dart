import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UpdateService {
  static const String _baseUrl = 'https://backend.arcmedialabs.in';

  // Set to 'user' for User App
  static String appType = 'user';

  /// Call this method when app starts to check for updates
  static Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    // 1. Get current app version from the native build
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    print('📱 Current app version: $currentVersion');

    // 2. Fetch remote version info from backend
    final remoteVersion = await _fetchRemoteVersion();
    if (remoteVersion == null) {
      print('❌ No remote version data - skipping update check');
      return;
    }

    final minimumVersion = remoteVersion['minimum_version'] as String? ?? '0.0.0';
    final latestVersion  = remoteVersion['latest_version'] as String? ?? currentVersion;
    final forceUpdate    = remoteVersion['force_update'] as bool? ?? false;
    final updateUrl      = remoteVersion['update_url'] as String? ?? '';

    print('📱 Remote minimum version: $minimumVersion');
    print('📱 Remote latest version: $latestVersion');
    print('📱 Force update: $forceUpdate');

    final belowMinimum = _compareVersions(currentVersion, minimumVersion) < 0;
    final belowLatest  = _compareVersions(currentVersion, latestVersion) < 0;

    if (forceUpdate && belowMinimum) {
      print('⚠️ Showing FORCED update dialog');
      _showForceUpdateDialog(context, updateUrl);
    } else if (belowMinimum) {
      print('⚠️ Showing OPTIONAL update dialog (below minimum)');
      _showOptionalUpdateDialog(context, updateUrl, minimumVersion);
    } else if (belowLatest) {
      print('⚠️ Showing OPTIONAL update dialog (new version available)');
      _showOptionalUpdateDialog(context, updateUrl, latestVersion);
    } else {
      print('✅ App is up to date - no dialog');
    }
  }

  static Future<Map<String, dynamic>?> _fetchRemoteVersion() async {
    final platform = Platform.isAndroid ? 'android' : 'ios';
    final url = Uri.parse(
      '$_baseUrl/api/admin/app-version/?platform=$platform&app_type=$appType',
    );
    print('📡 Checking update from: $url');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['data'];
      }
    } catch (e) {
      print('❌ App version check failed: $e');
    }
    return null;
  }

  static int _compareVersions(String v1, String v2) {
    try {
      String cleanV1 = v1.split('+').first;
      String cleanV2 = v2.split('+').first;

      final parts1 = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;

      for (int i = 0; i < maxLength; i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;
        if (p1 > p2) return 1;
        if (p1 < p2) return -1;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static void _showForceUpdateDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          title: const Row(
            children: [
              Icon(Icons.system_update_alt, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update Required',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of the app is available.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 10),
              Text(
                'Please update to continue using the app.',
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openStore(url, context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Update Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showOptionalUpdateDialog(BuildContext context, String url, String targetVersion) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        title: Row(
          children: [
            Icon(Icons.system_update_alt, color: Colors.green.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'New Update Available',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version $targetVersion is available with improvements and fixes.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text('Would you like to update now?', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              _openStore(url, context);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  static void _openStore(String url, BuildContext context) async {
    if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      final fallbackUrl = Platform.isAndroid
          ? 'https://play.google.com/store/apps/details?id=com.book_your_turf.app'
          : 'https://apps.apple.com/in/app/book_your_turf/id6756934347';

      if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      }
    }
  }
}