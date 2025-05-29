# Tavla Skor Takip

Tavla Skor Takip, oyuncuların tavla maçlarını kaydetmelerine, skorlarını takip etmelerine ve istatistiklerini görüntülemelerine olanak sağlayan bir Flutter uygulamasıdır.

## Özellikler

- 🔐 Güvenli kullanıcı kimlik doğrulama
- 👥 Oyuncu yönetimi
- 🎲 Maç kayıtları
- 📊 Detaylı istatistikler
- 🎨 Modern ve kullanıcı dostu arayüz
- 🌓 Açık/Koyu tema desteği
- 🔄 Otomatik oturum yönetimi
- 📱 Responsive tasarım

## Oturum Yönetimi

Uygulama, güvenli bir oturum yönetimi sistemi içerir:

- 30 dakika hareketsizlik sonrası otomatik oturum kapatma
- Uygulama arka plana alındığında oturum takibi
- Kullanıcı etkileşimlerinde oturum süresinin yenilenmesi
- Oturum sona erdiğinde kullanıcıya bildirim

## Güvenlik Özellikleri

- Firebase Authentication ile güvenli kimlik doğrulama
- Şifre sıfırlama desteği
- Oturum güvenliği
- Veri şifreleme

## Kurulum

1. Flutter SDK'yı yükleyin
2. Projeyi klonlayın:
   ```bash
   git clone https://github.com/Uricaryn/backgammon_score_tracker.git
   ```
3. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
4. Firebase projenizi yapılandırın:
   - Firebase Console'da yeni bir proje oluşturun
   - Flutter uygulamanızı Firebase'e ekleyin
   - `google-services.json` dosyasını `android/app` dizinine ekleyin
   - Firebase Authentication ve Cloud Firestore'u etkinleştirin

5. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

## Kullanılan Teknolojiler

- Flutter
- Firebase Authentication
- Cloud Firestore
- Provider (State Management)
- Material Design 3

## Katkıda Bulunma

1. Bu depoyu fork edin
2. Yeni bir özellik dalı oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add some amazing feature'`)
4. Dalınıza push yapın (`git push origin feature/amazing-feature`)
5. Bir Pull Request oluşturun

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Daha fazla bilgi için `LICENSE` dosyasına bakın.

## İletişim

Proje Sahibi - [@Uricaryn](https://github.com/Uricaryn)

Proje Linki: [https://github.com/Uricaryn/backgammon_score_tracker](https://github.com/Uricaryn/backgammon_score_tracker)
