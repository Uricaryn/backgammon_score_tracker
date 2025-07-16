import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';

class DailyTipService {
  static final DailyTipService _instance = DailyTipService._internal();
  factory DailyTipService() => _instance;
  DailyTipService._internal();

  static const String _cacheKey = 'daily_backgammon_tip';
  static const String _cacheDateKey = 'daily_tip_date';

  // Hugging Face API endpoint (ücretsiz tier)
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/gpt2';
  static const String _apiKey = ''; // Hugging Face API key buraya gelecek

  // Önceden hazırlanmış tavla bilgileri (API çalışmazsa fallback)
  static const List<String> _fallbackTips = [
    'Tavla, dünyanın en eski masa oyunlarından biridir. M.Ö. 3000 yıllarında Mezopotamya\'da oynanmaya başlanmıştır.',
    'Tavla oyununda "kapı" terimi, oyuncunun tüm pullarını topladığı bölgeyi ifade eder. Kapıyı kapatmak stratejik bir hamledir.',
    'Tavla oyununda "çifte" atmak, aynı sayıları iki kez atma şansınızı artırır. Bu durumda pullarınızı 4 kez hareket ettirebilirsiniz.',
    'Tavla oyununda "kırık" pullarınızı toplarken, rakibinizin kapısını kapatmaya çalışın. Bu, onların hamle yapmasını zorlaştırır.',
    'Tavla oyununda "blot" (tek pul), rakibin saldırısına açık olan pullardır. Blotlarınızı korumaya özen gösterin.',
    'Tavla oyununda "anchor" (çapa), rakibin kapısında güvenli bir şekilde duran pullarınızdır. Bu, gelecekteki hamleler için önemlidir.',
    'Tavla oyununda "prime" (sıra), 6 ardışık noktayı kontrol etmektir. Bu, rakibin geçişini engeller.',
    'Tavla oyununda "backgammon" terimi, tüm pullarınızı topladıktan sonra rakibin hala pulları varsa kazanılan bonus puanı ifade eder.',
    'Tavla oyununda "bearing off" (çıkarma), tüm pullarınızı topladıktan sonra onları oyun tahtasından çıkarma işlemidir.',
    'Tavla oyununda "hit" (vurma), rakibin tek pulunu vurup onu bar\'a gönderme hamlesidir.',
    'Tavla oyununda "bar" (bar), vurulan pulların geçici olarak bekletildiği yerdir. Bar\'daki pullar tekrar oyuna girmek zorundadır.',
    'Tavla oyununda "home board" (ev tahtası), oyuncunun kendi yarısındaki son 6 noktadır.',
    'Tavla oyununda "outer board" (dış tahta), oyuncunun kendi yarısındaki ilk 6 noktadır.',
    'Tavla oyununda "midpoint" (orta nokta), oyun tahtasının ortasındaki 13. noktadır.',
    'Tavla oyununda "pip count" (nokta sayısı), bir oyuncunun tüm pullarının toplam mesafesidir.',
  ];

  /// Günlük tavla bilgisini al
  Future<String> getDailyTip() async {
    try {
      // Cache kontrolü
      final cachedTip = await _getCachedTip();
      if (cachedTip != null) {
        return cachedTip;
      }

      // API'den yeni bilgi al
      final tip = await _getTipFromAPI();

      // Cache'e kaydet
      await _cacheTip(tip);

      return tip;
    } catch (e) {
      // Hata durumunda fallback kullan
      return _getRandomFallbackTip();
    }
  }

  /// Cache'den günlük bilgiyi al
  Future<String?> _getCachedTip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_cacheDateKey);
      final cachedTip = prefs.getString(_cacheKey);

      if (cachedDate != null && cachedTip != null) {
        final cacheDate = DateTime.parse(cachedDate);
        final now = DateTime.now();

        // Aynı günse cache'i kullan
        if (cacheDate.year == now.year &&
            cacheDate.month == now.month &&
            cacheDate.day == now.day) {
          return cachedTip;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cache'e bilgiyi kaydet
  Future<void> _cacheTip(String tip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, tip);
      await prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
    } catch (e) {
      // Cache hatası kritik değil, sessizce geç
    }
  }

  /// Hugging Face API'den bilgi al
  Future<String> _getTipFromAPI() async {
    try {
      // API key yoksa fallback kullan
      if (_apiKey.isEmpty) {
        return _getRandomFallbackTip();
      }

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': 'Tavla oyunu hakkında ilginç bir bilgi ver:',
              'parameters': {
                'max_length': 150,
                'temperature': 0.8,
                'top_p': 0.9,
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data[0]['generated_text'] as String?;

        if (generatedText != null && generatedText.isNotEmpty) {
          // Metni temizle ve tavla ile ilgili hale getir
          return _cleanAndFormatTip(generatedText);
        }
      }

      // API başarısız olursa fallback kullan
      return _getRandomFallbackTip();
    } catch (e) {
      // Hata durumunda fallback kullan
      return _getRandomFallbackTip();
    }
  }

  /// Rastgele fallback bilgi al
  String _getRandomFallbackTip() {
    final random = DateTime.now().millisecond % _fallbackTips.length;
    return _fallbackTips[random];
  }

  /// API'den gelen metni temizle ve formatla
  String _cleanAndFormatTip(String text) {
    // Metni temizle
    String cleaned = text
        .replaceAll(
            RegExp(r'[^\w\s\.\,\!\?\-]'), '') // Özel karakterleri temizle
        .replaceAll(RegExp(r'\s+'), ' ') // Fazla boşlukları temizle
        .trim();

    // Tavla ile ilgili değilse fallback kullan
    if (!cleaned.toLowerCase().contains('tavla') &&
        !cleaned.toLowerCase().contains('backgammon')) {
      return _getRandomFallbackTip();
    }

    // Maksimum uzunluk kontrolü
    if (cleaned.length > 200) {
      cleaned = cleaned.substring(0, 200) + '...';
    }

    return cleaned;
  }

  /// Cache'i temizle (test için)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheDateKey);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  /// API durumunu kontrol et
  Future<bool> isAPIAvailable() async {
    return _apiKey.isNotEmpty;
  }
}
