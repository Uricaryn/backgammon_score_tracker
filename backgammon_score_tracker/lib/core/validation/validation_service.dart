class ValidationService {
  static String? validateName(
    String? value, {
    required String fieldName,
    int minLength = 2,
    int maxLength = 15,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName boş olamaz';
    }
    if (value.length < minLength) {
      return '$fieldName en az $minLength karakter olmalıdır';
    }
    if (value.length > maxLength) {
      return '$fieldName en fazla $maxLength karakter olabilir';
    }
    if (!RegExp(r'^[a-zA-ZğüşıöçĞÜŞİÖÇ\s]+$').hasMatch(value)) {
      return '$fieldName sadece harflerden oluşmalıdır';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    return validateName(value,
        fieldName: 'Kullanıcı adı', minLength: 3, maxLength: 20);
  }

  static String? validatePlayerName(String? value) {
    return validateName(value,
        fieldName: 'Oyuncu adı', minLength: 2, maxLength: 15);
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'E-posta adresi boş olamaz';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Geçerli bir e-posta adresi giriniz';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre boş olamaz';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Şifre en az bir büyük harf içermelidir';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Şifre en az bir küçük harf içermelidir';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Şifre en az bir rakam içermelidir';
    }
    return null;
  }

  static String? validateScore(int? value) {
    if (value == null) {
      return 'Skor boş olamaz';
    }
    if (value < 0) {
      return 'Skor negatif olamaz';
    }
    if (value > 999) {
      return 'Skor 999\'dan büyük olamaz';
    }
    return null;
  }

  static String? validatePlayerSelection(String? value, String? otherPlayer) {
    if (value == null || value.isEmpty) {
      return 'Oyuncu seçimi boş olamaz';
    }
    if (value == otherPlayer) {
      return 'Aynı oyuncuyu seçemezsiniz';
    }
    return null;
  }

  static String? validateGameDate(DateTime? value) {
    if (value == null) {
      return 'Tarih seçimi boş olamaz';
    }
    if (value.isAfter(DateTime.now())) {
      return 'Gelecek bir tarih seçemezsiniz';
    }
    return null;
  }
}
