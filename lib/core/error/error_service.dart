class ErrorService {
  // Auth Errors
  static const String authUserNotFound = 'Kullanıcı bulunamadı';
  static const String authInvalidEmail = 'Geçersiz e-posta adresi';
  static const String authWrongPassword = 'Hatalı şifre';
  static const String authEmailAlreadyInUse =
      'Bu e-posta adresi zaten kullanımda';
  static const String authWeakPassword = 'Şifre çok zayıf';
  static const String authOperationNotAllowed =
      'Bu işlem şu anda kullanılamıyor';
  static const String authUserDisabled = 'Bu hesap devre dışı bırakılmış';
  static const String authTooManyRequests =
      'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin';
  static const String authNetworkRequestFailed = 'Ağ bağlantısı hatası';
  static const String authFailed = 'Kimlik doğrulama başarısız';
  static const String authEmailRequired = 'E-posta adresi gerekli';
  static const String authPasswordRequired = 'Şifre gerekli';
  static const String authPasswordResetEmailSent =
      'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi';

  // Firestore Errors
  static const String firestorePermissionDenied = 'Bu işlem için yetkiniz yok';
  static const String firestoreDocumentNotFound = 'Belge bulunamadı';
  static const String firestoreAlreadyExists = 'Bu belge zaten mevcut';
  static const String firestoreResourceExhausted = 'Kaynak limiti aşıldı';
  static const String firestoreFailedPrecondition =
      'İşlem ön koşulları sağlanamadı';
  static const String firestoreAborted = 'İşlem iptal edildi';
  static const String firestoreOutOfRange = 'İşlem aralık dışında';
  static const String firestoreUnimplemented = 'Bu işlem henüz uygulanmadı';
  static const String firestoreInternal = 'Sunucu hatası';
  static const String firestoreUnavailable = 'Servis şu anda kullanılamıyor';
  static const String firestoreDataLoss = 'Veri kaybı oluştu';

  // Game Errors
  static const String gameInvalidScore = 'Geçersiz skor';
  static const String gamePlayerNotFound = 'Oyuncu bulunamadı';
  static const String gameDuplicatePlayers = 'Aynı oyuncuyu seçemezsiniz';
  static const String gameInvalidDate = 'Geçersiz tarih';
  static const String gameSaveFailed = 'Maç kaydedilemedi';
  static const String gameUpdateFailed = 'Maç güncellenemedi';
  static const String gameDeleteFailed = 'Maç silinemedi';
  static const String gameLoadFailed = 'Maçlar yüklenemedi';

  // Player Errors
  static const String playerNameExists = 'Bu isimde bir oyuncu zaten var';
  static const String playerSaveFailed = 'Oyuncu kaydedilemedi';
  static const String playerUpdateFailed = 'Oyuncu güncellenemedi';
  static const String playerDeleteFailed = 'Oyuncu silinemedi';
  static const String playerLoadFailed = 'Oyuncular yüklenemedi';

  // Profile Errors
  static const String profileSaveFailed = 'Profil kaydedilemedi';
  static const String profileUpdateFailed = 'Profil güncellenemedi';
  static const String profileLoadFailed = 'Profil yüklenemedi';
  static const String profileInvalidTheme = 'Geçersiz tema ayarı';

  // Network Errors
  static const String networkNoConnection = 'İnternet bağlantısı yok';
  static const String networkTimeout = 'Bağlantı zaman aşımına uğradı';
  static const String networkServerError = 'Sunucu hatası';
  static const String networkUnknownError = 'Bilinmeyen ağ hatası';

  // General Errors
  static const String generalError = 'Bir hata oluştu. Lütfen tekrar deneyin';
  static const String generalUnknownError = 'Bilinmeyen bir hata oluştu';
  static const String generalTryAgain = 'Lütfen tekrar deneyin';
  static const String generalInvalidOperation = 'Geçersiz işlem';
  static const String generalInvalidData = 'Geçersiz veri';
  static const String generalOperationFailed = 'İşlem başarısız oldu';

  // Success Messages
  static const String successGameSaved = 'Maç başarıyla kaydedildi';
  static const String successGameUpdated = 'Maç başarıyla güncellendi';
  static const String successGameDeleted = 'Maç başarıyla silindi';
  static const String successPlayerSaved = 'Oyuncu başarıyla kaydedildi';
  static const String successPlayerUpdated = 'Oyuncu başarıyla güncellendi';
  static const String successPlayerDeleted = 'Oyuncu başarıyla silindi';
  static const String successProfileSaved = 'Profil başarıyla kaydedildi';
  static const String successProfileUpdated = 'Profil başarıyla güncellendi';

  // Notification Errors
  static const String notificationPermissionDenied = 'Bildirim izni reddedildi';
  static const String notificationPermissionPermanentlyDenied =
      'Bildirim izni kalıcı olarak reddedildi';
  static const String notificationServiceUnavailable =
      'Bildirim servisi kullanılamıyor';
  static const String notificationTokenFailed = 'Bildirim token\'ı alınamadı';
  static const String notificationSendFailed = 'Bildirim gönderilemedi';
  static const String notificationSaveFailed = 'Bildirim kaydedilemedi';
  static const String notificationLoadFailed = 'Bildirimler yüklenemedi';
  static const String notificationDeleteFailed = 'Bildirim silinemedi';
  static const String notificationPreferencesSaveFailed =
      'Bildirim tercihleri kaydedilemedi';
  static const String notificationPreferencesLoadFailed =
      'Bildirim tercihleri yüklenemedi';

  // Notification Success Messages
  static const String successNotificationSent = 'Bildirim başarıyla gönderildi';
  static const String successNotificationSaved =
      'Bildirim başarıyla kaydedildi';
  static const String successNotificationDeleted = 'Bildirim başarıyla silindi';
  static const String successNotificationPreferencesSaved =
      'Bildirim tercihleri kaydedildi';
  static const String successNotificationPermissionGranted =
      'Bildirim izni verildi';
}
