# 🌸 Ezan Vakti - Prayer Times & Islamic Companion App

A beautifully designed, open-source Flutter application for tracking Islamic prayer times, reading Quranic verses, and staying connected with spiritual content. Developed with love for family and the wider Muslim community.

---

## 📱 Overview

**Ezan Vakti** is a modern, user-friendly mobile application that helps Muslims stay on top of their daily prayers and spiritual practices. It features a **floral, feminine-inspired design** with a calming aesthetic, making it perfect for daily use on both phones and tablets.

Whether you're at home, traveling, or simply need a quick reminder for the next prayer, Ezan Vakti provides accurate prayer times, beautiful Quranic content, and customizable notifications—all in one place.

---

## ✨ Features

### 🕌 **Prayer Times**
- Accurate prayer times based on your selected city and district
- Real-time countdown to the next prayer
- Sunrise time included for complete daily planning
- Support for multiple cities (Muş, Balıkesir, Malatya, Sivas) with custom city addition.

### 🌸 **Beautiful & Intuitive UI**
- Floral, pastel-themed design with animated flower backgrounds
- Light and Dark mode support
- Responsive layout optimized for both phones and tablets
- Elegant typography and soft color palette

### 📖 **Spiritual Content**
- Daily verses (Ayat) from the Holy Quran
- Daily Hadiths (Prophetic sayings)
- Daily supplications (Duas)
- Daily Divine Names (Esma-ül Hüsna)
- A collection of frequently recited Surahs with Arabic, transliteration, and meaning

### 📅 **Special Days Tracker**
- Islamic holy nights (Kandils)
- Ramadan, Eid al-Fitr, and Eid al-Adha
- Turkish national holidays
- International observances (Women's Day, Teachers' Day, etc.)
- Automatic calculation of Mother's Day (second Sunday of May)

### 🔔 **Smart Notifications**
- **Pre-prayer reminders** – Get notified before each prayer time
- **Customizable reminder intervals** – Choose how early you want to be reminded
- **Full-screen alerts** – For important prayer times
- **Ongoing notification** – Shows remaining time in the notification bar
- **Sound options** – Default system sound or silent mode

### 📍 **Flexible Location Settings**
- 4 pre-defined cities with districts (Muş, Balıkesir, Malatya, Sivas)
- Add custom cities and districts manually
- Saved preferences persist between sessions

### 🌙 **Night Mode**
- Full dark theme for comfortable nighttime use
- Automatically saves your preference

### 📱 **Responsive Design**
- Optimized for mobile phones
- Tablet-friendly layout with a persistent top bar showing time, date, and remaining prayer time

---

## 🛠️ **Tech Stack**

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.44+ (Dart 3.12+) |
| **State Management** | StatefulWidget + SharedPreferences |
| **API** | AlAdhan Prayer Times API |
| **Notifications** | flutter_local_notifications |
| **Permissions** | permission_handler |
| **Internationalization** | intl (Turkish localization) |
| **Networking** | http |
| **Platform Support** | Android, iOS, Web |

---

## 🚧 **Development Status & Known Challenges**

As this project is in an active development phase, I am committed to transparency regarding the technical challenges encountered:

- **Geolocated Automation:** Automatic GPS-based location detection is currently being tested for stability.
- **Background Notifications:** Refining the logic for background notification triggers across different Android API versions is an ongoing task.
- **Asset Optimization:** The high-resolution floral UI assets are being optimized to ensure a smooth performance and lower memory usage.
- **API Synchronization:** Efforts are underway to implement a robust local caching mechanism to address occasional latencies with the AlAdhan service.

*Note: These issues are currently being addressed and are not yet fully resolved.*

---

## 📸 **Screenshots**

| Home Screen | Prayer Times | Surah Detail |
|-------------|--------------|--------------|
| *<img width="1080" height="1920" alt="Adsız tasarım (1)" src="https://github.com/user-attachments/assets/5fc24ac7-5837-4c54-94e1-cdf1cbb4f8e8" />
* | *<img width="1080" height="1920" alt="Adsız tasarım (2)" src="https://github.com/user-attachments/assets/b7748704-1992-4f1f-b7d4-d475a89e8323" />* *<img width="1080" height="1920" alt="Adsız tasarım (3)" src="https://github.com/user-attachments/assets/9d40509d-d18f-46a4-a3fc-444d0760f2ca" />* |

---

## 🚀 **Getting Started**

### Prerequisites

- Flutter SDK (3.44 or higher)
- Android Studio / VS Code
- Android SDK (API 36)
- Java 17

### Installation

1. **Clone the repository**
```bash
git clone [https://github.com/Aysenuryesilova/ezan-vakti.git](https://github.com/Aysenuryesilova/ezan-vakti.git)
cd ezan-vakti
