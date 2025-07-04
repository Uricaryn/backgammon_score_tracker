RR# 📱 Beta Güncelleme Bildirimi Sistemi Kurulum Rehberi

## 🎯 **Özellikler**
- ✅ **Otomatik Güncelleme Bildirimi**: Kapalı beta kullanıcılarına push notification
- ✅ **Admin Panel**: Kolay bildirim gönderimi
- ✅ **Zorunlu Güncelleme**: Kritik güncellemeler için
- ✅ **Firebase Cloud Functions**: Sunucu tarafı güvenilirlik
- ✅ **Topic Subscription**: Otomatik beta kullanıcı yönetimi
- ✅ **Yerel Bildirim**: Çift güvenlik sistemi

---

## 🔧 **1. Firebase Cloud Functions Kurulumu**

### **Gereksinimler:**
```bash
# Node.js ve npm kurulu olmalı
npm install -g firebase-tools

# Firebase CLI'da oturum açın
firebase login
```

### **Cloud Functions Kurulumu:**

1. **Proje dizininde functions klasörü oluşturun:**
```bash
mkdir functions
cd functions
```

2. **Firebase Functions başlatın:**
```bash
firebase init functions
```

3. **Gerekli paketleri yükleyin:**
```bash
# functions/package.json
{
  "name": "functions",
  "scripts": {
    "build": "tsc",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "dependencies": {
    "firebase-admin": "^11.0.0",
    "firebase-functions": "^4.0.0"
  },
  "devDependencies": {
    "typescript": "^4.9.0"
  }
}
```

4. **`firebase_functions_index.js` dosyasını `functions/index.js` olarak kopyalayın**

5. **Deploy edin:**
```bash
firebase deploy --only functions
```

---

## 🏗️ **2. Firestore Güvenlik Kuralları**

### **firestore.rules dosyasına ekleyin:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Admin notifications - sadece admin kullanıcıları
    match /admin_notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    // Users collection - güncelleme için
    match /users/{userId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == userId || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true);
    }
    
    // Notifications collection - kullanıcı bildirimleri
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true);
    }
  }
}
```

---

## 👤 **3. Admin Kullanıcı Kurulumu**

### **Admin kullanıcıları Firestore'da işaretleyin:**

1. **Firebase Console > Firestore**
2. **`users` collection'ına gidin**
3. **Admin kullanıcısının dokümanına `isAdmin: true` field'ını ekleyin**

**Örnek:**
```json
{
  "email": "admin@uricaryn.com",
  "username": "Admin",
  "isAdmin": true,
  "isBetaUser": true,
  "subscribedToUpdates": true,
  "fcmToken": "...",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

---

## 📲 **4. Android Manifest Ayarları**

### **android/app/src/main/AndroidManifest.xml:**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- ... existing permissions ... -->
    
    <!-- Notification permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    
    <!-- Android 13+ notification permission -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <application
        android:name="${applicationName}"
        android:exported="false"
        android:icon="@mipmap/ic_launcher"
        android:label="backgammon_score_tracker">
        
        <!-- ... existing activities ... -->
        
        <!-- Notification icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        
        <!-- Notification color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color" />
        
        <!-- Notification channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="update_notifications" />
    </application>
</manifest>
```

---

## 🎨 **5. Bildirim İkonları**

### **android/app/src/main/res/drawable/ic_notification.xml:**

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="?attr/colorOnPrimary">
    <path
        android:fillColor="@android:color/white"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM13,17h-2v-6h2v6zM13,9h-2L11,7h2v2z"/>
</vector>
```

### **android/app/src/main/res/values/colors.xml:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="notification_color">#FF6B35</color>
</resources>
```

---

## 🚀 **6. Kullanım Rehberi**

### **🔶 Admin Olarak Güncelleme Bildirimi Gönderme:**

1. **Uygulamayı açın**
2. **Profil sekmesine gidin**
3. **"Admin Panel" kartını görüyorsanız, tıklayın**
4. **Güncelleme bilgilerini doldurun:**
   - **Sürüm Numarası**: `1.2.0`
   - **Güncelleme Mesajı**: `Yeni özellikler ve hata düzeltmeleri`
   - **İndirme Linki**: APK dosyasının URL'i
   - **Zorunlu Güncelleme**: Kritik güncellemeler için aktif edin

5. **"Beta Kullanıcılarına Gönder" butonuna tıklayın**

### **🔶 Kullanıcı Deneyimi:**

1. **Güncelleme bildirimi alınır**
2. **Bildirime tıklandığında indirme başlar**
3. **Uygulama açıldığında güncelleme dialog'u gösterilir**
4. **Zorunlu güncelleme varsa, iptal butonu gizlenir**

---

## 🛡️ **7. Güvenlik Özellikleri**

### **🔒 Çok Katmanlı Güvenlik:**

#### **1. Admin Panel Erişim Güvenliği:**
- **Loading State**: Admin kontrolü tamamlanana kadar panel gizli
- **Firestore Doğrulama**: Sadece `isAdmin: true` field'ı olan kullanıcılar
- **Çift Kontrol**: Panel açılmadan önce ikinci kez admin kontrolü
- **Email Bypass Kaldırıldı**: Güvenlik açığı önlendi

#### **2. Admin Update Screen Güvenliği:**
- **InitState Kontrolü**: Sayfa açılır açılmaz admin doğrulama
- **Send Button Kontrolü**: Bildirim gönderilmeden önce son kontrol
- **Auto-Exit**: Admin olmayan kullanıcılar otomatik geri gönderilir

#### **3. Firebase Güvenliği:**
- **Firestore Rules**: Sadece admin kullanıcılar admin_notifications yazabilir
- **Cloud Functions**: Server-side admin doğrulama
- **Token Cleanup**: Geçersiz FCM token'ları otomatik temizlenir

#### **4. Uygulama Güvenliği:**
- **State Management**: Güvenli state güncellemeleri
- **Error Handling**: Hata durumunda güvenli fallback
- **URL Validation**: İndirme linklerinin geçerliliği kontrol edilir

### **✅ Güvenlik Katmanları:**
```
1. UI Level      → Admin panel sadece admin'lere görünür
2. Navigation    → Admin panel'e gitmeden önce kontrol
3. Screen Entry  → Admin screen açılırken kontrol
4. Action Level  → Bildirim göndermeden önce kontrol
5. Server Level  → Cloud Functions'da admin kontrol
6. Database      → Firestore rules ile kontrol
```

### **✅ Hata Yönetimi:**
- **Graceful Degradation**: Hata durumunda uygulama çalışmaya devam eder
- **Secure Defaults**: Hata durumunda admin erişimi kapatılır
- **Logging**: Detaylı güvenlik log kaydı
- **User Feedback**: Güvenli hata mesajları

---

## 📊 **8. Monitoring ve İstatistikler**

### **Firebase Console'da İzleme:**

1. **Firestore > admin_notifications**: Gönderilen bildirimleri görün
2. **Cloud Functions > Logs**: Fonksiyon çalışma logları
3. **Cloud Messaging > Analytics**: Bildirim delivery istatistikleri

### **Beta Kullanıcı İstatistikleri:**

Admin panel'de gelecek bir güncellemede beta kullanıcı sayısı gösterilecek.

---

## 🔧 **9. Troubleshooting**

### **❌ Bildirim Gelmiyor:**
1. **FCM Token kontrol edin**: Firebase Console > Users collection
2. **Admin yetkilerini kontrol edin**: `isAdmin: true` field'ı var mı?
3. **Cloud Functions çalışıyor mu**: Firebase Console > Functions
4. **Firestore rules**: Güvenlik kuralları doğru mu?

### **❌ Admin Panel Görünmüyor:**
1. **Firestore kontrolü**: `users/{userId}` dokümanında `isAdmin: true` field'ı var mı?
2. **Network bağlantısı**: Admin kontrolü için internet gerekli
3. **Loading state**: Admin kontrolü tamamlanana kadar panel gizli
4. **Cache temizleme**: Uygulamayı tamamen kapatıp açın
5. **Log kontrolü**: `debugPrint('Admin check error: $e')` mesajlarını kontrol edin

**Önemli**: Email bazlı admin kontrolü güvenlik nedeniyle kaldırıldı!

### **❌ Cloud Functions Hatası:**
```bash
# Logs kontrol edin
firebase functions:log

# Yeniden deploy edin
firebase deploy --only functions
```

---

## 🔄 **10. Güncellemeler ve Bakım**

### **Düzenli Bakım:**
- **Token Cleanup**: Geçersiz FCM token'ları otomatik temizlenir
- **Log Monitoring**: Cloud Functions loglarını düzenli kontrol edin
- **Database Indexing**: Firestore query'leri için index'leri optimize edin

### **Güncelleme Stratejisi:**
1. **Test Environment**: Önce test ortamında deneyin
2. **Staged Rollout**: Küçük kullanıcı gruplarıyla başlayın
3. **Monitoring**: Güncelleme sonrası metrikleri takip edin

---

## 📚 **11. Ek Kaynaklar**

### **Firebase Documentation:**
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

### **Flutter Packages:**
- [firebase_messaging](https://pub.dev/packages/firebase_messaging)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [cloud_firestore](https://pub.dev/packages/cloud_firestore)

---

## 🎉 **Sistem Başarıyla Kuruldu!**

Beta kullanıcılarınız artık yeni sürümlerden otomatik olarak haberdar olacak. Admin panel'den kolayca güncelleme bildirimleri gönderebilirsiniz.

**Sorularınız için:** [GitHub Issues](https://github.com/your-repo/issues)

---

*Son güncelleme: {{ current_date }}*
*Versiyon: 1.0.0* 