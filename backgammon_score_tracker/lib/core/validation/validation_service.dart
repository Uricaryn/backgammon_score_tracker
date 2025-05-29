import 'package:flutter/material.dart';

class ValidationService {
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kullanıcı adı boş olamaz';
    }
    if (value.length < 3) {
      return 'Kullanıcı adı en az 3 karakter olmalıdır';
    }
    if (value.length > 20) {
      return 'Kullanıcı adı en fazla 20 karakter olabilir';
    }
    if (!RegExp(r'^[a-zA-ZğüşıöçĞÜŞİÖÇ\s]+$').hasMatch(value)) {
      return 'Kullanıcı adı sadece harflerden oluşmalıdır';
    }
    return null;
  }

  static String? validatePlayerName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Oyuncu adı boş olamaz';
    }
    if (value.length < 2) {
      return 'Oyuncu adı en az 2 karakter olmalıdır';
    }
    if (value.length > 15) {
      return 'Oyuncu adı en fazla 15 karakter olabilir';
    }
    if (!RegExp(r'^[a-zA-ZğüşıöçĞÜŞİÖÇ\s]+$').hasMatch(value)) {
      return 'Oyuncu adı sadece harflerden oluşmalıdır';
    }
    return null;
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
