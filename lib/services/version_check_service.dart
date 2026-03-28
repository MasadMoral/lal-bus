import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  static Future<void> check(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_update').get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final latestVersionName = data['latest_version_name'] as String? ?? '';
      final updateUrl = data['update_url'] as String? ?? '';
      final isMandatory = data['is_mandatory'] as bool? ?? false;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Proper version comparison (e.g. 1.6.0 vs 1.5.0)
      bool isNewer(String current, String latest) {
        if (latest.isEmpty) return false;
        if (current == latest) return false;
        
        List<int> currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        List<int> lateParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        
        for (int i = 0; i < 3; i++) {
          int c = i < currParts.length ? currParts[i] : 0;
          int l = i < lateParts.length ? lateParts[i] : 0;
          if (l > c) return true;
          if (c > l) return false;
        }
        return false;
      }

      if (isNewer(currentVersion, latestVersionName)) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersionName, updateUrl, isMandatory);
        }
      }
    } catch (e) {
      debugPrint("Version check error: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String version, String url, bool mandatory) {
    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (context) => PopScope(
        canPop: !mandatory,
        child: AlertDialog(
          title: Text(mandatory ? 'Update Required' : 'Update Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version ($version) is available.'),
              const SizedBox(height: 10),
              const Text('Please update to continue using the latest features and fixes.'),
            ],
          ),
          actions: [
            if (!mandatory)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC0000),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                var finalUrl = url.trim();
                if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
                  finalUrl = 'https://' + finalUrl;
                }
                final uri = Uri.parse(finalUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open the update URL. Please check your browser.')),
                    );
                  }
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
