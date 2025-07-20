import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:backgammon_score_tracker/core/constants/api_keys.dart';

class DailyTipService {
  static final DailyTipService _instance = DailyTipService._internal();
  factory DailyTipService() => _instance;
  DailyTipService._internal();

  static const String _cacheKey = 'daily_backgammon_tip';
  static const String _cacheDateKey = 'daily_tip_date';

  // Hugging Face API endpoint - daha uygun model kullanıyoruz
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium';

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
    'Tavla oyununda "crawford rule", oyun sonunda bir oyuncu bir puan kala uygulanan özel kuraldır.',
    'Tavla oyununda "jacoby rule", gammon ve backgammon puanlarının sadece oyun sonunda sayılması kuralıdır.',
    'Tavla oyununda "beaver", çifte atıldığında rakibin tekrar çifte atma hakkıdır.',
    'Tavla oyununda "raccoon", beaver\'dan sonra tekrar çifte atma hakkıdır.',
    'Tavla oyununda "holland rule", oyun sonunda kazananın tüm pullarını çıkarması gerekir.',
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
      // API key kontrolü
      if (!ApiKeys.isHuggingFaceApiKeyValid) {
        return _getRandomFallbackTip();
      }

      // Tavla ile ilgili prompt'lar
      final List<String> prompts = [
        'Tavla oyunu hakkında ilginç bir strateji ipucu:',
        'Tavla oyununda başarılı olmak için önemli bir kural:',
        'Tavla oyunu tarihi hakkında ilginç bir bilgi:',
        'Tavla oyununda kullanılan önemli bir terim ve açıklaması:',
        'Tavla oyunu taktikleri hakkında bir ipucu:',
      ];

      // Rastgele bir prompt seç
      final randomPrompt = prompts[DateTime.now().millisecond % prompts.length];

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer ${ApiKeys.huggingFaceApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': randomPrompt,
              'parameters': {
                'max_length': 100,
                'temperature': 0.7,
                'top_p': 0.9,
                'do_sample': true,
                'num_return_sequences': 1,
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // API response formatını kontrol et
        String generatedText = '';
        if (data is List && data.isNotEmpty) {
          if (data[0] is Map && data[0].containsKey('generated_text')) {
            generatedText = data[0]['generated_text'] as String;
          } else if (data[0] is String) {
            generatedText = data[0] as String;
          }
        } else if (data is Map && data.containsKey('generated_text')) {
          generatedText = data['generated_text'] as String;
        }

        if (generatedText.isNotEmpty) {
          // Metni temizle ve tavla ile ilgili hale getir
          final cleanedTip = _cleanAndFormatTip(generatedText);

          // Eğer temizlenmiş metin çok kısaysa veya anlamsızsa fallback kullan
          if (cleanedTip.length < 20 || !_isRelevantToBackgammon(cleanedTip)) {
            return _getRandomFallbackTip();
          }

          return cleanedTip;
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

    // Prompt'u temizle
    cleaned = cleaned.replaceAll(RegExp(r'^.*?[:]\s*'), '');

    // Maksimum uzunluk kontrolü
    if (cleaned.length > 200) {
      cleaned = cleaned.substring(0, 200) + '...';
    }

    // Minimum uzunluk kontrolü
    if (cleaned.length < 20) {
      return _getRandomFallbackTip();
    }

    return cleaned;
  }

  /// Metnin tavla ile ilgili olup olmadığını kontrol et
  bool _isRelevantToBackgammon(String text) {
    final lowerText = text.toLowerCase();
    final backgammonKeywords = [
      'tavla',
      'backgammon',
      'zar',
      'pul',
      'oyun',
      'strateji',
      'taktik',
      'kapı',
      'bar',
      'hit',
      'blot',
      'anchor',
      'prime',
      'bearing',
      'gammon',
      'jacoby',
      'crawford',
      'beaver',
      'raccoon'
    ];

    return backgammonKeywords.any((keyword) => lowerText.contains(keyword));
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
    return ApiKeys.isHuggingFaceApiKeyValid;
  }

  /// API'yi test et
  Future<bool> testAPI() async {
    try {
      if (!ApiKeys.isHuggingFaceApiKeyValid) return false;

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer ${ApiKeys.huggingFaceApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': 'Test',
              'parameters': {
                'max_length': 10,
                'temperature': 0.7,
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// API durumunu detaylı kontrol et
  Future<Map<String, dynamic>> getAPIStatus() async {
    try {
      if (!ApiKeys.isHuggingFaceApiKeyValid) {
        return {
          'available': false,
          'error': 'API key is empty',
          'fallback_used': true,
        };
      }

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer ${ApiKeys.huggingFaceApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': 'Tavla',
              'parameters': {
                'max_length': 20,
                'temperature': 0.7,
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'available': true,
          'status_code': response.statusCode,
          'response_data': data,
          'fallback_used': false,
        };
      } else {
        return {
          'available': false,
          'status_code': response.statusCode,
          'error': 'HTTP ${response.statusCode}',
          'fallback_used': true,
        };
      }
    } catch (e) {
      return {
        'available': false,
        'error': e.toString(),
        'fallback_used': true,
      };
    }
  }
}
