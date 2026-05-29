import 'dart:async';

import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_card.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_container.dart';
import 'package:backgammon_score_tracker/core/services/payment_service.dart'
    show PaymentService, PurchaseUiEvent;
import 'package:backgammon_score_tracker/core/services/premium_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
  final PaymentService _paymentService = PaymentService();
  final PremiumService _premiumService = PremiumService();
  String? _errorMessage;
  bool _loadingProducts = true;
  bool _checkingMembership = true;
  bool _hasPremium = false;
  PremiumMembershipInfo? _membershipInfo;
  bool _awaitingPurchaseConfirmation = false;
  bool _activationHandled = false;
  StreamSubscription<bool>? _premiumActivatedSub;
  StreamSubscription<PurchaseUiEvent>? _purchaseUiSub;

  @override
  void initState() {
    super.initState();
    _initScreen();
    _premiumActivatedSub =
        _premiumService.premiumActivatedStream.listen((active) async {
      if (!active || !mounted) return;
      await _refreshMembershipStatus();
      if (_awaitingPurchaseConfirmation) {
        _onPremiumActivated();
      }
    });
    _purchaseUiSub = _paymentService.purchaseUiEvents.listen(_onPurchaseUiEvent);
  }

  void _onPurchaseUiEvent(PurchaseUiEvent event) {
    if (!mounted) return;
    switch (event) {
      case PurchaseUiEvent.pending:
        break;
      case PurchaseUiEvent.completed:
        break;
      case PurchaseUiEvent.canceled:
        setState(() => _awaitingPurchaseConfirmation = false);
        break;
      case PurchaseUiEvent.failed:
        setState(() {
          _awaitingPurchaseConfirmation = false;
          _errorMessage = PaymentService.friendlyPurchaseError;
        });
        break;
    }
  }

  Future<void> _initScreen() async {
    await _refreshMembershipStatus();
    if (!mounted) return;
    if (!_hasPremium) {
      await _loadProducts();
    } else {
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _refreshMembershipStatus() async {
    if (mounted) {
      setState(() => _checkingMembership = true);
    }
    final info = await _premiumService.fetchMembershipDetails();
    final active =
        info != null && info.isPremium && !info.isExpired;
    if (mounted) {
      setState(() {
        _membershipInfo = info;
        _hasPremium = active;
        _checkingMembership = false;
      });
    }
  }

  String? _formatExpiry(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd.MM.yyyy').format(date);
  }

  @override
  void dispose() {
    _premiumActivatedSub?.cancel();
    _purchaseUiSub?.cancel();
    super.dispose();
  }

  void _onPremiumActivated() {
    if (!mounted || _activationHandled) return;
    _activationHandled = true;
    setState(() => _awaitingPurchaseConfirmation = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Premium üyeliğiniz aktifleştirildi.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _errorMessage = null;
    });

    try {
      await _paymentService.reloadProducts();
    } catch (e) {
      debugPrint('Premium ürün yükleme hatası: $e');
    }

    if (mounted) {
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _purchaseProduct(String productId) async {
    setState(() {
      _errorMessage = null;
    });

    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _errorMessage =
            'Premium satın almak için önce giriş yapmanız gerekiyor.';
      });
      return;
    }

    final product = _paymentService.getMonthlyPremium();
    if (product == null) {
      await _paymentService.reloadProducts();
      if (_paymentService.getMonthlyPremium() == null) {
        setState(() {
          _errorMessage = _paymentService.userProductsLoadMessage;
        });
        return;
      }
    }

    try {
      setState(() => _awaitingPurchaseConfirmation = true);

      final success = await _paymentService.purchaseProduct(productId);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Satın alma işleniyor… Onaylandığında premium açılacak.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _awaitingPurchaseConfirmation = false;
            _errorMessage = PaymentService.friendlyPurchaseError;
          });
        }
      }
    } catch (e) {
      debugPrint('Purchase exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = PaymentService.friendlyPurchaseError;
          _awaitingPurchaseConfirmation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hasPremium ? 'Premium Üyeliğim' : 'Premium Özellikler'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          BackgroundBoard(
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
                          _hasPremium
                              ? 'Premium Aktif'
                              : 'Premium\'a Yükselt',
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
                          _hasPremium
                              ? 'Tüm premium özellikler hesabınızda açık.'
                              : 'Arkadaş ekleme ve sosyal turnuva özelliklerinin kilidini açın',
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
                if (!_hasPremium) ...[
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
                ],

                if (_checkingMembership)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_hasPremium)
                  _buildActiveMembershipSection()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Premium Planları',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPlansSection(),
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
          if (_awaitingPurchaseConfirmation)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Satın alma onaylanıyor…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveMembershipSection() {
    final expiry = _formatExpiry(_membershipInfo?.expiryDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyledCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Üyeliğiniz aktif',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ],
                ),
                if (expiry != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Geçerlilik: $expiry',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 16),
                _buildFeatureItem(
                  Icons.people,
                  'Sınırsız arkadaş ekleme',
                  'Hesabınızda aktif',
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  Icons.emoji_events,
                  'Sosyal turnuva oluşturma',
                  'Hesabınızda aktif',
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  Icons.block,
                  'Reklamsız deneyim',
                  'Hesabınızda aktif',
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await _paymentService.restorePurchases();
              await _premiumService.refreshPremiumStatus();
              await _refreshMembershipStatus();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Satın alımlar kontrol edildi.'),
                ),
              );
            },
            icon: const Icon(Icons.restore),
            label: const Text('Satın Alımları Geri Yükle'),
          ),
        ),
      ],
    );
  }

  Widget _buildPlansSection() {
    if (_hasPremium) {
      return const SizedBox.shrink();
    }

    if (_loadingProducts) {
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

    final monthly = _paymentService.getMonthlyPremium();
    if (monthly != null) {
      return Column(
        children: [
          _buildPlanCard(
            monthly.title,
            monthly.price,
            monthly.description,
            Icons.calendar_month,
            Colors.blue,
            () => _purchaseProduct('premium_monthly'),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Text(
            _paymentService.userProductsLoadMessage,
            style: const TextStyle(color: Colors.orange),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden Dene'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _paymentService.restorePurchases();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Satın alımlar geri yükleniyor...'),
                    ),
                  );
                },
                icon: const Icon(Icons.restore),
                label: const Text('Geri Yükle'),
              ),
            ),
          ],
        ),
      ],
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

}
