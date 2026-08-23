# 🕌 Ezan Vakti & İslami Yardımcı (Prayer Times & Qibla Finder)

<p align="center">
  <img src="assets/images/app_icon.png" width="120" height="120" alt="Ezan Vakti Icon" style="border-radius: 24px;" />
</p>

<p align="center">
  <b>Modern, Hassas ve Kapsamlı Mobil Ezan Vakti, Kıble Pusulası ve İslami İçerik Uygulaması</b><br />
  <i>A Modern, Precise & Feature-Rich Mobile Islamic Companion App built with Flutter.</i>
</p>

<p align="center">
  <a href="#-türkçe"><img src="https://img.shields.io/badge/Language-Türkçe-green.svg" alt="Türkçe" /></a>
  <a href="#-english"><img src="https://img.shields.io/badge/Language-English-blue.svg" alt="English" /></a>
  <img src="https://img.shields.io/badge/Flutter-v3.22+-blue.svg" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange.svg" alt="Platform" />
  <img src="https://img.shields.io/badge/Version-v3.5.4-teal.svg" alt="Version" />
</p>

---

## 📌 İçindekiler / Table of Contents
- [🇹🇷 Türkçe](#-türkçe)
  - [Öne Çıkan Özellikler](#-öne-çıkan-özellikler)
  - [Teknik Mimari & Teknolojiler](#-teknik-mimari--teknolojiler)
  - [Güvenlik ve İzinler](#-güvenlik-ve-izinler)
- [🇬🇧 English](#-english)
  - [Key Features](#-key-features)
  - [Technical Architecture](#-technical-architecture)
  - [Permissions & Security](#-permissions--security)
- [🚀 Kurulum & Geliştirme / Setup](#-kurulum--geliştirme--setup)

---

## 🇹🇷 Türkçe

### 🌟 Öne Çıkan Özellikler

#### 📍 1. Akıllı Konum Yönetimi (Otomatik GPS + Canlı Arama Çubuğu)
- **GPS ile Otomatik Algılama**: Cihazınızın GPS donanımıyla saniyesinde bulunduğunuz il ve ilçeyi otomatik tespit eder.
- **Canlı Arama Çubuğu**: Harf girdiğiniz an (Örn: *Malatya*, *Kadıköy*, *Lüleburgaz*) 81 il ve 900+ ilçe arasında anında filtreleme yapar.

#### 🧭 2. Çifte Modlu Kıble Bulucu (Dual-Mode Qibla Finder)
- **🧭 Sade GPS Pusulası**: Telefonun dahili Manyetik Pusula ve GPS sensörleriyle internete ihtiyaç duymadan Kıble yönünü gösterir. Tam Kıbleye hizalandığında **titreşim uyarısı (Haptic Feedback)** verir.
- **🗺️ Canlı Harita Görünümü**: Google Canlı Uydu Haritası üzerinden bina/ev seviyesinde Kıble çizgisini görüntüler.

#### 🔔 3. Her Vakit İçin Özel Bildirimler & Vakit Öncesi Hatırlatıcılar
- İmsak, Güneş, Öğle, İkindi, Akşam ve Yatsı vakitlerinin her biri için ayrı ayrı bildirim açıp kapatabilme.
- Her vakit için özel **vakit öncesi hatırlatma süresi** belirleme (5 ile 60 dakika arası).
- Cihaz kapalıyken veya arka plandayken bile zamanında çalışan `flutter_local_notifications` entegrasyonu.

#### 📲 4. Ana Ekran Masaüstü Widget'ı (Home Screen Widget)
- Telefonun ana ekranına canlı vakit bilgilerini ve sıradaki vakte kalan süreyi gösteren masaüstü widget'ı yerleştirme imkânı.

#### 📖 5. Kapsamlı İslami İçerik ve Araçlar
- **Kur'an-ı Kerim**: Sure takibi ve okuma rehberi.
- **Günün İçerikleri**: Her gün yenilenen Ayet, Hadis ve Dua kartları.
- **Zikirmatik**: Hedef sayaçlı, sesli ve titreşimli dijital tesbih.
- **Dini Günler & Geceler**: Hicri takvim entegrasyonlu Kandil ve Bayram takvimi.

#### 🎨 6. Özelleştirilebilir Temalar & Arka Planlar
- Koyu (Dark Mode) ve Aydınlık (Light Mode) tema seçeneği.
- Özel Ebru Sanatı, Cami ve Papatya arka plan görselleri.

---

### 🛠️ Teknik Mimari & Teknolojiler

- **Framework**: Flutter (Dart)
- **Konum & Sensörler**: `geolocator`, `geocoding`, `flutter_compass`
- **Bildirimler**: `flutter_local_notifications`, `timezone`
- **Masaüstü Widget**: `home_widget`
- **Veri Kaynakları & Çevrimdışı Çalışma**:
  - Birincil Kaynak: AlAdhan REST API (Diyanet Metodu).
  - Çevrimdışı Kaynak: `adhan_dart` kütüphanesi ile cihaz üzerinde yerel astronomik hesaplama.
- **Yerel Depolama**: `shared_preferences`

---

### 🔒 Güvenlik ve İzinler

- **Bildirim İzni**: Vakit ezanı ve vakit öncesi hatırlatıcılar için.
- **Konum İzni (GPS)**: Bulunduğunuz şehri/ilçeyi ve Kıble açısını anında tespit edebilmek için.
- **Tam Zamanlı Alarm İzni**: Android'in uygulama kapalıyken zamanında bildirim gönderebilmesi için.
- **Gizlilik**: Cihaz imzalama dosyaları (`.jks`, `key.properties`) repoya eklenmez ve `.gitignore` kapsamındadır.

---

## 🇬🇧 English

### 🌟 Key Features

#### 📍 1. Smart Location Management (GPS Auto-Detect + Live Search Bar)
- **Automatic GPS Detection**: Instantly detects your current province and district using the device's native GPS hardware.
- **Live Search Bar**: Real-time filtering across 81 provinces and 900+ districts with instant autocomplete.

#### 🧭 2. Dual-Mode Qibla Finder
- **🧭 Pure GPS Compass**: Native offline compass utilizing device magnetometer & GPS. Provides **Haptic Vibration Feedback** when accurately aligned toward Mecca.
- **🗺️ Live Satellite Map**: Overlay Qibla line over Google Satellite Maps for building-level precision.

#### 🔔 3. Per-Prayer Customizable Notifications & Pre-Alarms
- Individual toggles for each prayer time (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha).
- Custom pre-alarm reminders adjustable from 5 to 60 minutes prior to adhan.
- Reliable delivery even when the app is closed using `flutter_local_notifications`.

#### 📲 4. Home Screen Desktop Widget
- Real-time home screen widget displaying the next prayer time and countdown timer.

#### 📖 5. Rich Islamic Tools & Content
- **Holy Quran**: Surah reading list and tracker.
- **Daily Inspiration**: Curated Verses, Hadiths, and Prayers updated daily.
- **Digital Dhikr Counter**: Haptic & sound-supported Tasbeeh counter.
- **Islamic Calendar**: Important Islamic days, Laylat al-Qadr, and Eid tracker.

#### 🎨 6. Customizable Themes & Backgrounds
- Dark Mode & Light Mode support.
- Artistic Ebru, Mosque, and Daisy background patterns.

---

### 🛠️ Technical Architecture

- **Framework**: Flutter (Dart)
- **Location & Sensors**: `geolocator`, `geocoding`, `flutter_compass`
- **Notifications**: `flutter_local_notifications`, `timezone`
- **Home Widget**: `home_widget`
- **Data Provider & Offline Mode**:
  - Primary Provider: AlAdhan REST API (Diyanet Method).
  - Offline Fallback: `adhan_dart` library for local astronomical calculation.
- **Local Storage**: `shared_preferences`

---

### 🔒 Permissions & Security

- **Notification Permission**: For Adhan and pre-prayer alarms.
- **Location Permission (GPS)**: To detect your city and calculate precise Qibla bearing.
- **Exact Alarm Permission**: Ensures reliable Android background notifications.
- **Security**: Keystore files (`.jks`, `key.properties`) are strictly kept out of version control via `.gitignore`.

---

## 🚀 Kurulum & Geliştirme / Setup

Projeyi kendi bilgisayarınızda çalıştırmak için aşağıdaki adımları izleyebilirsiniz:

```bash
# 1. Repoyu klonlayın / Clone the repository
git clone https://github.com/Aysenuryesilova/ezan-vakti.git

# 2. Proje dizinine gidin / Navigate to directory
cd ezan-vakti

# 3. Bağımlılıkları yükleyin / Get dependencies
flutter pub get

# 4. Statik kod analizini çalıştırın / Run analysis
flutter analyze

# 5. Uygulamayı başlatın / Launch app
flutter run
```

---

<p align="center">
  Geliştirici / Developer: <a href="https://github.com/Aysenuryesilova"><b>Ayşenur Yeşilova</b></a><br />
  <i>Made with ❤️ using Flutter</i>
</p>