import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';

class UpdateService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final LogService _logService = LogService();

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await _remoteConfig.setDefaults({
        'latest_version': '1.1.0',
        'latest_version_code': '10',
        'force_update': false,
        'update_message':
            'Yeni özellikler ve iyileştirmeler ile güncellenmiş versiyonumuzu deneyin!',
        'play_store_url':
            'https://play.google.com/store/apps/details?id=com.uricaryn.backgammon_score_tracker',
      });

      await _remoteConfig.fetchAndActivate();
      _logService.info('Remote Config başarıyla başlatıldı',
          tag: 'UpdateService');
    } catch (e) {
      _logService.error('Remote Config başlatılamadı',
          tag: 'UpdateService', error: e);
    }
  }

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final latestVersion = _remoteConfig.getString('latest_version');
      final latestVersionCode =
          int.tryParse(_remoteConfig.getString('latest_version_code')) ?? 0;
      final forceUpdate = _remoteConfig.getBool('force_update');
      final updateMessage = _remoteConfig.getString('update_message');
      final playStoreUrl = _remoteConfig.getString('play_store_url');

      _logService.info(
          'Versiyon kontrolü: Mevcut: $currentVersion ($currentVersionCode), Güncel: $latestVersion ($latestVersionCode)',
          tag: 'UpdateService');

      if (currentVersionCode < latestVersionCode) {
        _showUpdateDialog(context, forceUpdate, updateMessage, playStoreUrl);
      }
    } catch (e) {
      _logService.error('Güncelleme kontrolü başarısız',
          tag: 'UpdateService', error: e);
    }
  }

  void _showUpdateDialog(BuildContext context, bool forceUpdate, String message,
      String playStoreUrl) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.system_update,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Güncelleme Mevcut',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En son özellikleri ve güvenlik güncellemelerini almak için uygulamayı güncelleyin.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Daha Sonra'),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _launchPlayStore(playStoreUrl);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPlayStore(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logService.info('Play Store açıldı', tag: 'UpdateService');
      } else {
        _logService.error('Play Store açılamadı', tag: 'UpdateService');
      }
    } catch (e) {
      _logService.error('Play Store açma hatası',
          tag: 'UpdateService', error: e);
    }
  }
}
