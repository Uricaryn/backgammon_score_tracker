import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme_extensions.dart';
import 'package:backgammon_score_tracker/presentation/screens/premium_upgrade_screen.dart';

class PremiumUpsellBanner extends StatelessWidget {
  const PremiumUpsellBanner({
    super.key,
    required this.source,
    this.compact = false,
  });

  final String source;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final premiumAccent = context.appThemeExtensions.premiumAccent;

    return FutureBuilder<bool>(
      future: PremiumService().hasPremiumAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.data == true) {
          return const SizedBox.shrink();
        }

        if (compact) {
          return ListTile(
            leading: Icon(Icons.workspace_premium, color: premiumAccent),
            title: const Text('Premium\'a yükselt'),
            subtitle: const Text('Reklamsız deneyim ve daha fazlası'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _openPremium(context),
          );
        }

        return Card(
          child: InkWell(
            onTap: () => _openPremium(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: premiumAccent, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium\'a yükselt',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reklamsız deneyim ve ek özellikler',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: premiumAccent, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPremium(BuildContext context) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PremiumUpgradeScreen(source: source),
      ),
    );
  }
}
