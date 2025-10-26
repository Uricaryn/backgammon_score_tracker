# Changelog

## [1.7.0] - 2025-01-XX

### 🎉 Yeni Özellikler
- **Turnuva Oyuncu İstatistikleri**: Turnuva içinde oyunculara tıklandığında o turnuvaya özel istatistikler görüntüleme
  - Toplam maç, kazanma/kaybetme sayıları
  - Kazanma oranı ve ortalama puan
  - En çok yenilen rakip bilgisi
  - Detaylı maç geçmişi
- **Maç Düzenleme**: Turnuva geçmişindeki tamamlanmış maçları düzenleme ve silme
  - Maç sonuçlarını güncelleme
  - Yanlış girilen maçları silme
  - Turnuva yaratıcısı için tam kontrol
- **Tüm Katılımcılar Görünür**: Turnuva scoreboard'ında henüz maçı olmayan oyuncular da artık görünüyor
  - Sonradan eklenen katılımcılar listeleniyor
  - 0 maç ile başlayan oyuncular gösteriliyor

### 🔧 İyileştirmeler
- **Performans Optimizasyonları**: 
  - Turnuva listesi yükleme hızı 10x daha hızlı
  - N+1 query sorunları çözüldü
  - Batch veri çekme ile optimize edildi
- **Firestore İndeksleri**: Yeni composite indexler eklendi
  - Tournament sorguları için 5 yeni index
  - Player statistics için 2 yeni index
  - Notification sorguları optimize edildi
- **Query Limitleri**: Veri yükleme limitleri eklendi
  - Turnuva listesi: son 50 turnuva
  - Scoreboard: son 200 maç
  - Match history: son 100 maç
  - Tournament invitations: son 30 davet

### 🐛 Düzeltmeler
- Turnuva scoreboard ve maç geçmişi yavaş yükleme sorunu
- Player statistics indeks hatası çözüldü
- Notifications indeks hatası düzeltildi
- Turnuvaya sonradan eklenen oyuncuların görünmeme sorunu
- Null safety linter uyarıları temizlendi

### 🎨 Kullanıcı Arayüzü
- Turnuva maç kartlarına düzenleme ve silme butonları
- Oyuncu istatistikleri için modern dialog tasarımı
- Uyarı mesajları ve bilgilendirmeler iyileştirildi
- Daha iyi loading state'leri

### 🔒 Güvenlik
- Maç düzenleme/silme sadece turnuva yaratıcısı için
- İptal edilmiş turnuvalarda düzenleme yapılamıyor
- Tüm işlemler backend'de kontrol ediliyor

---

## [1.3.0-beta] - 2024-12-XX

### 🎉 Yeni Özellikler
- **Misafir Kullanıcı Desteği**: Giriş yapmadan oyun oynayabilme
- **Sosyal Bildirimler**: Günlük tavla hatırlatıcıları (10:00, 15:00, 20:00)
- **Yerel Veri Saklama**: Misafir kullanıcılar için yerel oyun ve oyuncu kaydetme

### 🔧 İyileştirmeler
- **Bildirim Sistemi**: Firebase Messaging entegrasyonu
- **Kullanıcı Deneyimi**: Daha tutarlı dialog'lar ve bildirim uyarıları
- **Giriş/Kayıt Akışı**: Google ile kayıt ol butonu sadece kayıt modunda görünür
- **Bildirim Ayarları**: Sadeleştirilmiş ayarlar (sosyal bildirimler ve genel)
- **Veri Saklama**: Anonymous kullanıcı verileri tamamen lokalde tutuluyor

### 🐛 Düzeltmeler
- Misafir kullanıcılarda oyuncu ekleme sorunları
- Bildirim servisi hataları
- Firebase Messaging entegrasyon sorunları
- Giriş yapma butonlarının çalışmaması
- Google ile giriş yapıldıktan sonra misafir girişi sorunu
- Oyuncu silindiğinde ilişkili maçların da silinmesi
- Keystore bilgilerinin terminalde görünmesi güvenlik sorunu
- Anonymous kullanıcıdan kayıtlı kullanıcıya geçişte veri aktarımı sorunu
- Anonymous kullanıcı verilerinin kayıt sonrası Firestore'a aktarılması

### 🔒 Güvenlik
- Misafir kullanıcılar için istatistik sayfalarına erişim kısıtlaması
- Maç geçmişi görüntüleme kısıtlaması

### 📱 Platform Desteği
- Android API 35 desteği
- iOS 17+ desteği
- Modern Flutter SDK (3.2.3+)

---

## [1.2.0] - 2024-XX-XX

### Önceki sürüm özellikleri
- Temel tavla skor takip özellikleri
- Firebase entegrasyonu
- Kullanıcı kimlik doğrulama
- İstatistik görüntüleme 