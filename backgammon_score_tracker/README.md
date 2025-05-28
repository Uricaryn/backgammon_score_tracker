# Tavla Skor Takip Uygulaması

Bu uygulama, arkadaşlar arasında oynanan tavla oyunlarının skorlarını ve istatistiklerini takip etmek için geliştirilmiş bir Flutter uygulamasıdır.

## Özellikler

- Kullanıcı kaydı ve girişi
- Oyun skorlarını kaydetme
- Detaylı istatistikler
  - Toplam oyun sayısı
  - Kazanma oranı
  - En çok oynanan rakip
  - En yüksek skor
  - Ortalama oyun süresi
- Tavla temalı modern arayüz

## Kurulum

1. Flutter SDK'yı yükleyin
2. Projeyi klonlayın
3. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
4. Firebase projenizi oluşturun ve yapılandırın
5. `lib/core/firebase/firebase_options.dart` dosyasını Firebase Console'dan aldığınız bilgilerle güncelleyin
6. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

## Teknolojiler

- Flutter
- Firebase Authentication
- Cloud Firestore
- Provider
- GetIt
- Flutter Bloc
- Equatable

## Katmanlı Mimari

Uygulama, Clean Architecture prensiplerine uygun olarak aşağıdaki katmanlardan oluşmaktadır:

1. Core (Çekirdek katman)
   - Tema
   - Firebase yapılandırması
   - Servisler

2. Data (Veri katmanı)
   - Repository'ler
   - Veri modelleri

3. Domain (İş mantığı katmanı)
   - Use case'ler
   - Entity'ler

4. Presentation (Sunum katmanı)
   - Ekranlar
   - Widget'lar
   - State management

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır.
