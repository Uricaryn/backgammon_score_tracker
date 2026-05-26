import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/services/cloud_functions_safe_service.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';

class PaymentService {
  static const String _monthlyPremiumId = 'premium_monthly';
  // static const String _yearlyPremiumId = 'premium_yearly'; // Geçici olarak devre dışı

  // Payment system enabled for production
  static const bool _paymentSystemDisabled = false;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudFunctionsSafeService _functionsSafe = CloudFunctionsSafeService();

  // Premium ürün ID'leri
  static const Set<String> _productIds = {
    _monthlyPremiumId,
    // _yearlyPremiumId, // Geçici olarak devre dışı
  };

  // Mevcut ürünler
  List<ProductDetails> _products = [];
  String? _lastLoadError;
  bool _purchaseListenerAttached = false;
  static const Duration _productQueryTimeout = Duration(seconds: 15);

  /// Kullanıcıya gösterilecek genel mesaj. Teknik StoreKit/BillingClient
  /// hatalarını sızdırmaz; detaylar yalnızca debug log'a yazılır.
  static const String _friendlyLoadError =
      'Premium ürünleri şu anda yüklenemiyor. Lütfen daha sonra tekrar deneyin.';
  static const String _friendlyPurchaseError =
      'Satın alma şu anda tamamlanamıyor. Lütfen daha sonra tekrar deneyin.';

  String? get lastLoadError => _lastLoadError;
  bool get hasProducts => _products.isNotEmpty;
  bool _usingLocalTestProducts = false;
  bool _productsUnavailableFromStore = false;

  /// Simulator/debug'da sahte ProductDetails ile mağaza sorgusu yapılmaz.
  bool get usingLocalTestProducts => _usingLocalTestProducts;

  /// Premium planları yüklenemediğinde gösterilecek kullanıcı metni.
  String get userProductsLoadMessage {
    if (kDebugMode) {
      return _friendlyLoadError;
    }
    if (_productsUnavailableFromStore) {
      return '$_friendlyLoadError\n\n'
          'TestFlight veya Mac üzerinde test ediyorsanız: App Store, '
          'premium_monthly ürünü onaylanana kadar listeyi göstermeyebilir. '
          'Onay sonrası Mac Ayarlar → App Store → Sandbox hesabı ile giriş yapıp '
          'yeniden deneyin. Geliştirme testi için iOS Simulator kullanın.';
    }
    return _friendlyLoadError;
  }

  // Stream controller'lar
  final StreamController<List<ProductDetails>> _productsController =
      StreamController<List<ProductDetails>>.broadcast();
  final StreamController<bool> _isAvailableController =
      StreamController<bool>.broadcast();

  // Stream'ler
  Stream<List<ProductDetails>> get productsStream => _productsController.stream;
  Stream<bool> get isAvailableStream => _isAvailableController.stream;

  // Getter'lar
  List<ProductDetails> get products => _products;
  Future<bool> get isAvailable => _inAppPurchase.isAvailable();

  // Singleton pattern
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _storeName => _isIos ? 'App Store' : 'Play Store';

  String get _purchasePlatform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'android';
  }

  void _publishProducts(List<ProductDetails> products) {
    _products = products;
    if (!_productsController.isClosed) {
      _productsController.add(List.unmodifiable(_products));
    }
  }

  void _attachPurchaseListener() {
    if (_purchaseListenerAttached) return;
    _purchaseListenerAttached = true;
    _inAppPurchase.purchaseStream.listen(_handlePurchaseUpdates);
  }

  // Servisi başlat
  Future<void> initialize() async {
    if (_paymentSystemDisabled) {
      debugPrint('Payment system temporarily disabled for deployment');
      _isAvailableController.add(false);
      _publishProducts([]);
      return;
    }

    _publishProducts([]);
    _attachPurchaseListener();

    try {
      if (kDebugMode) {
        debugPrint('Debug modunda premium ürünleri yükleniyor...');
        await _loadProductsForDebug();
        return;
      }

      await reloadProducts();
    } catch (e) {
      debugPrint('Payment service başlatılırken hata: $e');
      _lastLoadError = _friendlyLoadError;
      if (kDebugMode) {
        _addTestProducts();
      } else {
        _publishProducts([]);
      }
    }
  }

  Future<void> reloadProducts() async {
    _lastLoadError = null;
    _productsUnavailableFromStore = false;

    if (_paymentSystemDisabled) {
      _publishProducts([]);
      return;
    }

    if (kDebugMode) {
      await _loadProductsForDebug();
      return;
    }

    try {
      final available = await _inAppPurchase.isAvailable();
      _isAvailableController.add(available);

      if (!available) {
        debugPrint('In-app purchase $_storeName üzerinde kullanılamıyor.');
        _productsUnavailableFromStore = true;
        _lastLoadError = _friendlyLoadError;
        _publishProducts([]);
        return;
      }

      const attempts = 2;
      for (var i = 0; i < attempts; i++) {
        if (i > 0) {
          debugPrint('Premium ürün sorgusu yeniden deneniyor (${i + 1}/$attempts)...');
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        await _loadProducts().timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            debugPrint('Premium ürün sorgusu zaman aşımına uğradı.');
            _productsUnavailableFromStore = true;
            _lastLoadError = _friendlyLoadError;
            _publishProducts([]);
          },
        );
        if (_products.isNotEmpty) break;
      }

      if (_products.isEmpty) {
        _productsUnavailableFromStore = true;
        debugPrint(
            '$_storeName üzerinde "$_monthlyPremiumId" ürünü yüklenemedi.');
        _lastLoadError = _friendlyLoadError;
        _publishProducts([]);
      }
    } catch (e) {
      debugPrint('Ürün yenileme hatası: $e');
      _productsUnavailableFromStore = true;
      _lastLoadError = _friendlyLoadError;
      _publishProducts([]);
    }
  }

  /// Debug: önce StoreKit Configuration / sandbox ürünlerini dene, olmazsa yerel test.
  Future<void> _loadProductsForDebug() async {
    _usingLocalTestProducts = false;
    try {
      final available = await _inAppPurchase.isAvailable();
      if (available) {
        await _loadProducts();
        if (_products.isNotEmpty) {
          debugPrint(
              'Debug: mağaza ürünleri yüklendi (${_products.length} adet).');
          return;
        }
      }
    } catch (e) {
      debugPrint('Debug mağaza sorgusu başarısız, yerel test ürünleri: $e');
    }
    _addTestProducts();
  }

  // Debug modunda test ürünleri ekle
  void _addTestProducts() {
    _usingLocalTestProducts = true;
    _products = [
      ProductDetails(
        id: _monthlyPremiumId,
        title: 'Aylık Premium (Test)',
        description: '1 ay premium erişim',
        price: '₺19.99',
        rawPrice: 19.99,
        currencyCode: 'TRY',
      ),
      // ProductDetails(
      //   id: _yearlyPremiumId,
      //   title: 'Yıllık Premium (Test)',
      //   description: '12 ay premium erişim',
      //   price: '₺149.99',
      //   rawPrice: 149.99,
      //   currencyCode: 'TRY',
      // ),
    ];
    _lastLoadError = null;
    _publishProducts(_products);
    _isAvailableController.add(true);

    debugPrint('Test ürünleri yüklendi.');
  }

  // Test ürünlerini zorla ekle (public metod)
  void addTestProducts() {
    _addTestProducts();
  }

  /// Mağaza ve ürün durumunu kontrol eder (iOS + Android).
  ///
  /// Dönen `reason` alanı kullanıcıya gösterilebilecek genel bir mesajdır;
  /// teknik detaylar `debugReason` içindedir ve debug log'a yazılır.
  Future<Map<String, dynamic>> checkStoreStatus() async {
    if (_paymentSystemDisabled) {
      return {
        'available': false,
        'reason': _friendlyLoadError,
        'debugReason': 'Payment system disabled',
      };
    }

    // Debug + yüklü ürün: gerçek App Store'a tekrar sorma (simülatörde storekit_no_response).
    if (kDebugMode && _products.isNotEmpty) {
      return {
        'available': true,
        'products_count': _products.length,
        'products': _products.map((p) => p.id).toList(),
        'debugReason': _usingLocalTestProducts
            ? 'debug_local_test_products'
            : 'debug_cached_store_products',
      };
    }

    try {
      final available = await _inAppPurchase.isAvailable();

      if (!available) {
        debugPrint('checkStoreStatus: $_storeName not available');
        return {
          'available': false,
          'reason': _friendlyLoadError,
          'debugReason': 'In-app purchase not available on this device',
        };
      }

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds).timeout(
        _productQueryTimeout,
      );

      if (response.error != null) {
        debugPrint('checkStoreStatus error: ${response.error}');
        return {
          'available': false,
          'reason': _friendlyLoadError,
          'debugReason': response.error.toString(),
        };
      }

      if (response.notFoundIDs.isNotEmpty ||
          response.productDetails.isEmpty) {
        debugPrint(
            'checkStoreStatus: missing IDs ${response.notFoundIDs.join(', ')}');
        return {
          'available': false,
          'reason': _friendlyLoadError,
          'debugReason':
              'Missing product IDs: ${response.notFoundIDs.join(', ')}',
        };
      }

      return {
        'available': true,
        'products_count': response.productDetails.length,
        'products': response.productDetails.map((p) => p.id).toList(),
      };
    } catch (e) {
      debugPrint('checkStoreStatus exception: $e');
      return {
        'available': false,
        'reason': _friendlyLoadError,
        'debugReason': e.toString(),
      };
    }
  }

  // Ürünleri yükle
  Future<void> _loadProducts() async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_productIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Bulunamayan ürünler: ${response.notFoundIDs}');
      _lastLoadError = _friendlyLoadError;
    }

    if (response.error != null) {
      debugPrint('Ürün yükleme hatası: ${response.error}');
      _lastLoadError = _friendlyLoadError;
      _publishProducts([]);
      return;
    }

    _publishProducts(response.productDetails);

    debugPrint('Yüklenen ürünler: ${_products.length}');
    for (final product in _products) {
      debugPrint('Ürün: ${product.id} - ${product.title} - ${product.price}');
    }
  }

  /// Geriye dönük uyumluluk.
  Future<Map<String, dynamic>> checkPlayStoreStatus() => checkStoreStatus();

  // Satın alma işlemini başlat
  Future<bool> purchaseProduct(String productId) async {
    // TEMPORARY: Payment system disabled
    if (_paymentSystemDisabled) {
      debugPrint('Payment system temporarily disabled - purchase ignored');
      return false;
    }

    try {
      // Debug modunda test satın alma
      if (kDebugMode) {
        debugPrint('Debug modunda test satın alma: $productId');
        return await _handleTestPurchase(productId);
      }

      final product = _products.firstWhere(
        (product) => product.id == productId,
        orElse: () => throw Exception('Ürün bulunamadı: $productId'),
      );

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      bool success = false;

      if (product.id == _monthlyPremiumId) {
        success =
            await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }

      return success;
    } catch (e) {
      debugPrint('Satın alma başlatılırken hata: $e');
      return false;
    }
  }

  /// Satın alma akışında kullanıcıya gösterilecek genel mesaj.
  static String get friendlyPurchaseError => _friendlyPurchaseError;

  Future<void> _activatePremiumLocally(
    String userId,
    String productId,
    String purchaseId,
  ) async {
    final premiumDays = productId == _monthlyPremiumId ? 30 : 365;
    final expiry = DateTime.now().add(Duration(days: premiumDays));

    await _firestore.collection('users').doc(userId).set({
      'isPremium': true,
      'premiumExpiryDate': Timestamp.fromDate(expiry),
      'premiumDays': premiumDays,
      'lastPurchaseDate': FieldValue.serverTimestamp(),
      'purchaseId': purchaseId,
      'productId': productId,
      'premiumRenewalCancelled': false,
      'premiumRenewalCancelledAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // Debug modunda test satın alma işle
  Future<bool> _handleTestPurchase(String productId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Test satın alma: kullanıcı giriş yapmamış');
        return false;
      }

      final purchaseId =
          'test_purchase_${DateTime.now().millisecondsSinceEpoch}';

      // Yerel test ürünleri: Cloud Function / StoreKit gerekmez (simülatör).
      if (_usingLocalTestProducts) {
        await _activatePremiumLocally(user.uid, productId, purchaseId);
        await PremiumService().markPremiumActiveLocally();
        debugPrint('Test premium aktifleştirildi (yerel debug)');
        return true;
      }

      // StoreKit ürünü yüklendiyse sunucu doğrulamasını dene.
      try {
        await user.getIdToken(true);
      } catch (e) {
        debugPrint('Auth token yenilenemedi: $e');
      }

      final verifyResult = await _functionsSafe.call(
        'verifyPremiumPurchase',
        data: {
          'purchaseId': purchaseId,
          'productId': productId,
          'platform': _purchasePlatform,
          if (_purchasePlatform == 'android')
            'purchaseToken':
                'test_token_${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      if (verifyResult != null &&
          verifyResult.data is Map &&
          (verifyResult.data as Map)['success'] == true) {
        debugPrint('Test premium doğrulandı (sunucu)');
        return true;
      }

      await _activatePremiumLocally(user.uid, productId, purchaseId);
      await PremiumService().markPremiumActiveLocally();
      debugPrint('Test premium aktifleştirildi (yerel yedek)');
      return true;
    } catch (e) {
      debugPrint('Test premium aktivasyon hatası: $e');
      return false;
    }
  }

  // Satın alma güncellemelerini işle
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Bekleyen satın alma
        debugPrint('Satın alma bekliyor: ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Başarılı satın alma
        _handleSuccessfulPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Hata
        debugPrint('Satın alma hatası: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // İptal edildi
        debugPrint('Satın alma iptal edildi: ${purchaseDetails.productID}');
      }

      // Satın alma tamamlandıysa kapat
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  // Başarılı satın almayı işle
  Future<void> _handleSuccessfulPurchase(
      PurchaseDetails purchaseDetails) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Kullanıcı giriş yapmamış');
        return;
      }

      final purchaseId = purchaseDetails.purchaseID ??
          'purchase_${DateTime.now().millisecondsSinceEpoch}';

      // Sunucu doğrulaması (mümkünse); iOS release'te genelde kapalı → yerel yedek.
      final verified = await _tryVerifyPurchaseOnServer(
        purchaseId: purchaseId,
        productId: purchaseDetails.productID,
        purchaseDetails: purchaseDetails,
      );

      if (!verified) {
        await _activatePremiumLocally(
          user.uid,
          purchaseDetails.productID,
          purchaseId,
        );
      } else {
        await _firestore.collection('users').doc(user.uid).set(
          {
            'premiumRenewalCancelled': false,
            'premiumRenewalCancelledAt': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
      }

      await PremiumService().markPremiumActiveLocally();
      debugPrint('Premium aktifleştirildi: ${purchaseDetails.productID}');
    } catch (e) {
      debugPrint('Premium aktivasyon hatası: $e');
    }
  }

  Future<bool> _tryVerifyPurchaseOnServer({
    required String purchaseId,
    required String productId,
    required PurchaseDetails purchaseDetails,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      try {
        await user.getIdToken(true);
      } catch (e) {
        debugPrint('Auth token yenilenemedi: $e');
      }

      final verifyResult = await _functionsSafe.call(
        'verifyPremiumPurchase',
        data: {
          'purchaseId': purchaseId,
          'productId': productId,
          'platform': _purchasePlatform,
          if (_purchasePlatform == 'android')
            'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        },
      );
      if (verifyResult != null &&
          verifyResult.data is Map &&
          (verifyResult.data as Map)['success'] == true) {
        debugPrint('Premium sunucuda doğrulandı');
        return true;
      }
    } catch (e) {
      debugPrint('Sunucu doğrulama hatası: $e');
    }
    return false;
  }

  // Satın alma geçmişini kontrol et
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('Satın alma geri yükleme hatası: $e');
    }
  }

  // Servisi temizle
  void dispose() {
    _productsController.close();
    _isAvailableController.close();
  }

  // Premium ürünlerini getir
  List<ProductDetails> getPremiumProducts() {
    return _products
        .where((product) => product.id == _monthlyPremiumId)
        .toList();
  }

  // Aylık premium ürününü getir
  ProductDetails? getMonthlyPremium() {
    try {
      return _products.firstWhere((product) => product.id == _monthlyPremiumId);
    } catch (e) {
      return null;
    }
  }

  // Yıllık premium ürününü getir (geçici olarak devre dışı)
  ProductDetails? getYearlyPremium() {
    return null; // Geçici olarak devre dışı
  }
}
