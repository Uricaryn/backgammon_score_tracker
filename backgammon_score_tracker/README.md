# Tavla Skor Takip Uygulaması

Bu uygulama, arkadaşlar arasında oynanan tavla oyunlarının skorlarını ve istatistiklerini takip etmek için geliştirilmiş bir Flutter uygulamasıdır.

## Özellikler

### Kullanıcı Yönetimi
- E-posta ve şifre ile kayıt ve giriş
- Şifremi unuttum özelliği
- Profil yönetimi
  - Kullanıcı adı düzenleme
  - Tema tercihleri (Aydınlık/Karanlık/Sistem)
  - E-posta görüntüleme

### Oyun Yönetimi
- Yeni oyun kaydetme
- Oyun düzenleme
- Oyun detaylarını görüntüleme
- Oyuncu yönetimi
  - Oyuncu ekleme
  - Oyuncu düzenleme
  - Oyuncu istatistikleri

### İstatistikler
- Toplam oyun sayısı
- Kazanma oranı
- En çok oynanan rakip
- En yüksek skor
- Oyuncu bazlı istatistikler
  - Maç sayısı
  - Kazanma oranı
  - Rakip analizi

### Arayüz
- Modern ve kullanıcı dostu tasarım
- Tavla temalı arka plan
- Responsive tasarım
- Animasyonlu geçişler
- Özelleştirilebilir tema

## Kurulum

1. Flutter SDK'yı yükleyin (en az 3.0.0 sürümü)
2. Projeyi klonlayın:
   ```bash
   git clone https://github.com/yourusername/backgammon_score_tracker.git
   ```
3. Proje dizinine gidin:
   ```bash
   cd backgammon_score_tracker
   ```
4. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
5. Firebase projenizi oluşturun ve yapılandırın:
   - Firebase Console'da yeni bir proje oluşturun
   - Authentication'ı etkinleştirin (E-posta/Şifre)
   - Firestore Database'i oluşturun
   - Firebase CLI ile projeyi yapılandırın:
     ```bash
     firebase init
     ```
6. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

## Teknolojiler

- **Flutter** - UI framework
- **Firebase**
  - Authentication - Kullanıcı yönetimi
  - Cloud Firestore - Veritabanı
- **State Management**
  - Provider - Durum yönetimi
  - GetIt - Dependency injection
- **UI/UX**
  - Material Design 3
  - Custom animations
  - Responsive design

## Proje Yapısı

```
lib/
├── core/
│   ├── error/         # Hata yönetimi
│   ├── routes/        # Rota yönetimi
│   ├── services/      # Servisler
│   ├── theme/         # Tema yapılandırması
│   ├── validation/    # Doğrulama servisleri
│   └── widgets/       # Ortak widget'lar
├── presentation/
│   ├── screens/       # Ekranlar
│   └── widgets/       # Ekran widget'ları
└── main.dart          # Uygulama giriş noktası
```

## Katmanlı Mimari

Uygulama, Clean Architecture prensiplerine uygun olarak aşağıdaki katmanlardan oluşmaktadır:

1. **Core (Çekirdek katman)**
   - Tema yönetimi
   - Firebase yapılandırması
   - Servisler
   - Hata yönetimi
   - Doğrulama servisleri

2. **Presentation (Sunum katmanı)**
   - Ekranlar
   - Widget'lar
   - State management
   - Kullanıcı etkileşimleri

## Güvenlik

- Firebase Authentication ile güvenli kullanıcı yönetimi
- Firestore güvenlik kuralları
- Veri doğrulama ve sanitizasyon
- Güvenli şifre yönetimi

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.
