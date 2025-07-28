import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_card.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_container.dart';
import 'package:backgammon_score_tracker/core/services/payment_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  final String? source; // Hangi sayfadan geldiği bilgisi

  const PremiumUpgradeScreen({
    super.key,
    this.source,
  });

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  final PremiumService _premiumService = PremiumService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
  }

  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize();

      // Ürünlerin yüklenmesini bekle
      await Future.delayed(const Duration(seconds: 3));

      // Eğer hala ürün yoksa test ürünlerini zorla ekle
      if (_paymentService.products.isEmpty) {
        debugPrint('Ürünler yüklenmedi, test ürünleri zorla ekleniyor...');
        _paymentService.addTestProducts();
      }

      // Her durumda setState çağır
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Payment service initialization error: $e');
      // Hata durumunda da test ürünleri ekle
      _paymentService.addTestProducts();

      if (mounted) {
        setState(() {
          _errorMessage = 'Ödeme sistemi başlatılamadı: $e';
        });
      }
    }
  }

  Future<void> _purchaseProduct(String productId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Önce Play Store durumunu kontrol et
      final status = await _paymentService.checkPlayStoreStatus();

      if (!status['available']) {
        setState(() {
          _errorMessage = '${status['reason']}\n\nÇözüm: ${status['solution']}';
        });
        return;
      }

      final success = await _paymentService.purchaseProduct(productId);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Satın alma başlatıldı!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Satın alma başlatılamadı. Lütfen:\n'
              '• Uygulamanın Play Store\'dan indirildiğini kontrol edin\n'
              '• Test kullanıcısı olduğunuzdan emin olun\n'
              '• İnternet bağlantınızı kontrol edin';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Satın alma hatası: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Özellikler'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.star,
                            size: 48,
                            color: Colors.amber[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Premium\'a Yükselt',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Arkadaş ekleme ve sosyal turnuva özelliklerinin kilidini açın',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Premium özellikler
                StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.diamond,
                              color: Colors.amber[700],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Premium Özellikler',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                          Icons.people,
                          'Sınırsız Arkadaş Ekleme',
                          'Ücretsiz kullanıcılar sadece 3 arkadaş ekleyebilir',
                          Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.emoji_events,
                          'Sosyal Turnuva Oluşturma',
                          'Arkadaşlarınızla turnuva oluşturun ve yönetin',
                          Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.support_agent,
                          'Öncelikli Destek',
                          'Premium kullanıcılar için özel destek hattı',
                          Colors.purple,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.block,
                          'Reklamsız Deneyim',
                          'Rahatsız edici reklamlar olmadan kullanın',
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Ücretsiz limitler
                StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ücretsiz Limitler',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLimitItem(
                          'Arkadaş Ekleme',
                          '3 arkadaş',
                          Icons.people_outline,
                        ),
                        const SizedBox(height: 8),
                        _buildLimitItem(
                          'Sosyal Turnuva',
                          '0 turnuva',
                          Icons.emoji_events_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Premium satın alma butonları
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Premium Planları',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<ProductDetails>>(
                      stream: _paymentService.productsStream,
                      builder: (context, snapshot) {
                        // Başlangıç durumunda veya bağlantı beklerken loading göster
                        if (snapshot.connectionState ==
                                ConnectionState.waiting ||
                            snapshot.connectionState == ConnectionState.none) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Premium planları yükleniyor...'),
                                ],
                              ),
                            ),
                          );
                        }

                        final products = snapshot.data ?? [];

                        // Ürün yoksa test ürünlerini göster (hem debug hem release için)
                        if (products.isEmpty) {
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          Colors.orange.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'Play Store ürünleri yüklenemedi - Test ürünleri gösteriliyor',
                                  style: TextStyle(color: Colors.orange),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPlanCard(
                                'Aylık Premium (Test)',
                                '₺19.99/ay',
                                '1 ay premium erişim',
                                Icons.calendar_month,
                                Colors.blue,
                                () => _purchaseProduct('premium_monthly'),
                              ),
                              const SizedBox(height: 12),
                              // _buildPlanCard(
                              //   'Yıllık Premium (Test)',
                              //   '₺149.99/yıl',
                              //   '12 ay premium erişim (2 ay bedava)',
                              //   Icons.calendar_today,
                              //   Colors.green,
                              //   () => _purchaseProduct('premium_yearly'),
                              //   isRecommended: true,
                              // ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            if (_paymentService.getMonthlyPremium() != null)
                              _buildPlanCard(
                                _paymentService.getMonthlyPremium()!.title,
                                _paymentService.getMonthlyPremium()!.price,
                                '1 ay premium erişim',
                                Icons.calendar_month,
                                Colors.blue,
                                () => _purchaseProduct('premium_monthly'),
                              ),
                            if (_paymentService.getMonthlyPremium() != null &&
                                _paymentService.getYearlyPremium() != null)
                              const SizedBox(height: 12),
                            // if (_paymentService.getYearlyPremium() != null)
                            //   _buildPlanCard(
                            //     _paymentService.getYearlyPremium()!.title,
                            //     _paymentService.getYearlyPremium()!.price,
                            //     '12 ay premium erişim (2 ay bedava)',
                            //     Icons.calendar_today,
                            //     Colors.green,
                            //     () => _purchaseProduct('premium_yearly'),
                            //     isRecommended: true,
                            //   ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hata mesajı
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (_errorMessage != null) const SizedBox(height: 16),

                // Geri dön butonu
                if (widget.source != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Geri Dön'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
      IconData icon, String title, String description, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLimitItem(String title, String limit, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            limit,
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    String title,
    String price,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isRecommended = false,
  }) {
    return StyledContainer(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: isRecommended ? Border.all(color: color, width: 2) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isRecommended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ÖNERİLEN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Satın Al',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yakında'),
        content: const Text(
          'Premium özellikler yakında aktif olacak. Şimdilik admin tarafından premium durumunuz güncellenebilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
