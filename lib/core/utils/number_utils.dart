/// Güvenli sayı parsing utility'leri
class NumberUtils {
  /// Güvenli int parsing - hem int hem double değerleri handle eder
  static int safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Güvenli double parsing - hem int hem double değerleri handle eder
  static double safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Güvenli num parsing - her türlü sayısal değeri handle eder
  static num safeParseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  /// Yüzde hesaplama helper'ı
  static double calculatePercentage(int part, int total) {
    if (total == 0) return 0.0;
    return (part / total) * 100;
  }

  /// Ortalama hesaplama helper'ı
  static double calculateAverage(int sum, int count) {
    if (count == 0) return 0.0;
    return sum / count;
  }
}
