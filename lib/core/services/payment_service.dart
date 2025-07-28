import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  static const String _monthlyPremiumId = 'premium_monthly';
  // static const String _yearlyPremiumId = 'premium_yearly'; // Geçici olarak devre dışı

  // Payment system enabled for production
  static const bool _paymentSystemDisabled = false;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Premium ürün ID'leri
  static const Set<String> _productIds = {
    _monthlyPremiumId,
    // _yearlyPremiumId, // Geçici olarak devre dışı
  };

  // Mevcut ürünler
  List<ProductDetails> _products = [];

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

  // Servisi başlat
  Future<void> initialize() async {
    // TEMPORARY: Payment system disabled
    if (_paymentSystemDisabled) {
      debugPrint('Payment system temporarily disabled for deployment');
      _isAvailableController.add(false);
      return;
    }

    try {
      // Debug modunda test ürünleri ekle
      if (kDebugMode) {
        debugPrint('Debug modunda test ürünleri yükleniyor...');
        _addTestProducts();
        return;
      }

      // In-app purchase'ın kullanılabilir olup olmadığını kontrol et
      final available = await _inAppPurchase.isAvailable();
      _isAvailableController.add(available);

      if (!available) {
        debugPrint('In-app purchase kullanılamıyor');
        // Debug modunda test ürünleri ekle
        _addTestProducts();
        return;
      }

      // Ürünleri yükle
      await _loadProducts();

      // Eğer ürünler yüklenemezse test ürünleri ekle
      if (_products.isEmpty) {
        debugPrint(
            'Play Store ürünleri yüklenemedi, test ürünleri ekleniyor...');
        _addTestProducts();
      }

      // Satın alma stream'ini dinle
      _inAppPurchase.purchaseStream.listen(_handlePurchaseUpdates);
    } catch (e) {
      debugPrint('Payment service başlatılırken hata: $e');

      // Hata durumunda test ürünleri ekle
      debugPrint('Hata nedeniyle test ürünleri yükleniyor...');
      _addTestProducts();
    }
  }

  // Debug modunda test ürünleri ekle
  void _addTestProducts() {
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
    _productsController.add(_products);
    _isAvailableController.add(true);

    debugPrint(
        'Test ürünleri yüklendi. Production için Play Store kurulumu gerekli.');
  }

  // Test ürünlerini zorla ekle (public metod)
  void addTestProducts() {
    _addTestProducts();
  }

  // Play Store durumunu kontrol et
  Future<Map<String, dynamic>> checkPlayStoreStatus() async {
    // TEMPORARY: Payment system disabled
    if (_paymentSystemDisabled) {
      return {
        'available': false,
        'reason': 'Ödeme sistemi geçici olarak devre dışı',
        'solution': 'Sistem yakında aktif olacak'
      };
    }

    try {
      final available = await _inAppPurchase.isAvailable();

      if (!available) {
        return {
          'available': false,
          'reason': 'In-app purchase kullanılamıyor',
          'solution': 'Uygulamanın Play Store\'dan indirildiğinden emin olun'
        };
      }

      // Ürünleri yüklemeyi dene
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);

      if (response.error != null) {
        return {
          'available': false,
          'reason': 'Ürün yükleme hatası: ${response.error}',
          'solution': 'Play Store\'da ürünlerin aktif olduğunu kontrol edin'
        };
      }

      if (response.productDetails.isEmpty) {
        return {
          'available': false,
          'reason': 'Ürünler bulunamadı',
          'solution':
              'Play Store Console\'da ürünleri oluşturun ve aktifleştirin'
        };
      }

      return {
        'available': true,
        'products_count': response.productDetails.length,
        'products': response.productDetails.map((p) => p.id).toList()
      };
    } catch (e) {
      return {
        'available': false,
        'reason': 'Hata: $e',
        'solution': 'Teknik destek ile iletişime geçin'
      };
    }
  }

  // Ürünleri yükle
  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Bulunamayan ürünler: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        debugPrint('Ürün yükleme hatası: ${response.error}');
        return;
      }

      _products = response.productDetails;
      _productsController.add(_products);

      debugPrint('Yüklenen ürünler: ${_products.length}');
      for (final product in _products) {
        debugPrint('Ürün: ${product.id} - ${product.title} - ${product.price}');
      }
    } catch (e) {
      debugPrint('Ürün yükleme hatası: $e');
    }
  }

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
        await _handleTestPurchase(productId);
        return true;
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

  // Debug modunda test satın alma işle
  Future<void> _handleTestPurchase(String productId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Kullanıcı giriş yapmamış');
        return;
      }

      // Server-side doğrulama çağır
      final functions = FirebaseFunctions.instance;

      // Sahte satın alma tespiti
      final fakeCheck =
          await functions.httpsCallable('detectFakePurchase').call({
        'purchaseId': 'test_purchase_${DateTime.now().millisecondsSinceEpoch}',
        'productId': productId,
        'platform': 'android'
      });

      if (fakeCheck.data['isFake']) {
        debugPrint(
            'Sahte satın alma tespit edildi: ${fakeCheck.data['reason']}');
        return;
      }

      // Premium doğrulama
      final result =
          await functions.httpsCallable('verifyPremiumPurchase').call({
        'purchaseId': 'test_purchase_${DateTime.now().millisecondsSinceEpoch}',
        'productId': productId,
        'platform': 'android',
        'purchaseToken': 'test_token_${DateTime.now().millisecondsSinceEpoch}'
      });

      if (result.data['success']) {
        debugPrint('Test premium başarıyla aktifleştirildi');
      } else {
        debugPrint('Test premium aktivasyon hatası');
      }
    } catch (e) {
      debugPrint('Test premium aktivasyon hatası: $e');
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

      // Premium süresini hesapla
      int premiumDays = 0;
      if (purchaseDetails.productID == _monthlyPremiumId) {
        premiumDays = 30;
      }

      // Firestore'da premium durumunu güncelle
      await _firestore.collection('users').doc(user.uid).update({
        'isPremium': true,
        'premiumExpiryDate': FieldValue.serverTimestamp(),
        'premiumDays': premiumDays,
        'lastPurchaseDate': FieldValue.serverTimestamp(),
        'purchaseId': purchaseDetails.purchaseID,
        'productId': purchaseDetails.productID,
      });

      debugPrint('Premium başarıyla aktifleştirildi: $premiumDays gün');
    } catch (e) {
      debugPrint('Premium aktivasyon hatası: $e');
    }
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
