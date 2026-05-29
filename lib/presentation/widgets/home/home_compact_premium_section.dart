import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme_extensions.dart';
import 'package:backgammon_score_tracker/presentation/screens/premium_upgrade_screen.dart';

class HomeCompactPremiumSection extends StatelessWidget {
  const HomeCompactPremiumSection({
    super.key,
    required this.hasPremiumFuture,
  });

  final Future<bool> hasPremiumFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasPremiumFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.data == true) {
          return const SizedBox.shrink();
        }

        final premiumAccent = context.appThemeExtensions.premiumAccent;
        final premiumContainer =
            context.appThemeExtensions.premiumAccentContainer;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                premiumContainer.withValues(alpha: isDark ? 0.35 : 0.9),
                premiumContainer.withValues(alpha: isDark ? 0.15 : 0.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: premiumAccent.withValues(alpha: isDark ? 0.2 : 0.45),
              width: isDark ? 1 : 1.3,
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const PremiumUpgradeScreen(source: 'home'),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, color: premiumAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium\'a yükselt',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: premiumAccent,
                              fontWeight: FontWeight.bold,
                            ),
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
        );
      },
    );
  }
}
