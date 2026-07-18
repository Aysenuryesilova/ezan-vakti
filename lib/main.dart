import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ==================== ANA GİRİŞ NOKTASI ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  tz_data.initializeTimeZones();

  if (!kIsWeb) {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        debugPrint("📢 Bildirim izni sonucu: $result");
      } else if (status.isPermanentlyDenied) {
        debugPrint("📢 Bildirim izni kalıcı olarak reddedilmiş!");
      }

      final isGranted = await Permission.notification.isGranted;
      debugPrint("📢 Bildirim izni verildi mi? $isGranted");

      // 🔧 Vakit bildirimleri zonedSchedule + exactAllowWhileIdle kullanıyor,
      // bu da Android 12+'ta SCHEDULE_EXACT_ALARM izni gerektiriyor. İzin
      // yoksa _scheduleSingleNotification içinde inexact moda düşülüyor,
      // ama önce burada normal şekilde istemeyi deniyoruz.
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      if (exactAlarmStatus.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
      debugPrint(
          "⏰ Tam zamanlı alarm izni: ${await Permission.scheduleExactAlarm.status}");

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("📱 Bildirime tıklandı!");
        },
      );

      final androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const AndroidNotificationChannel channel1 = AndroidNotificationChannel(
          'namaz_vakitleri',
          'Namaz Vakitleri',
          description: 'Namaz vakitleri ve hatırlatıcı bildirimleri',
          importance: Importance.high,
        );
        await androidImplementation.createNotificationChannel(channel1);

        const AndroidNotificationChannel channel2 = AndroidNotificationChannel(
          'namaz_vakitleri_sabit',
          'Sabit Namaz Vakti',
          description: 'Namaz vaktine kalan süreyi gösterir',
          importance: Importance.low,
        );
        await androidImplementation.createNotificationChannel(channel2);

        debugPrint("✅ Bildirim kanalları oluşturuldu!");
      }
      // 🔧 KALDIRILDI: Uygulama her açıldığında çıkan "Bildirim sistemi
      // çalışıyor!" test bildirimi kullanıcı isteği üzerine silindi.
      // Kanal oluşturma ve izin kontrolü yeterli; ayrıca bir test
      // bildirimi göstermeye gerek yok.
    } catch (e) {
      debugPrint("❌ Başlangıç bildirim hatası: $e");
    }
  }

  runApp(const MyApp());
}

// ==================== MYAPP ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezan Vakti 🌸',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Schyler',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB5627A)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== SPLASH SCREEN ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const EzanVaktiApp()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5E6E8), Color(0xFFE8C4D0), Color(0xFFFDF8F5)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "🌸 HOŞ GELDİNİZ 🌸",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB5627A),
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 50),
              CircularProgressIndicator(color: Color(0xFFB5627A)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== BİLDİRİM FONKSİYONLARI ====================
Future<void> showNotification(
  String title,
  String body, {
  bool sesli = true,
  String? sound,
}) async {
  if (kIsWeb) return;

  try {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'namaz_vakitleri',
      'Namaz Vakitleri',
      importance: Importance.max,
      priority: Priority.max,
      playSound: sesli,
      fullScreenIntent: true,
      sound: sound != null && sound != "default" && sound != "silent"
          ? RawResourceAndroidNotificationSound(sound)
          : null,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
    );
    debugPrint("✅ Bildirim gönderildi: $title");
  } catch (e) {
    debugPrint("❌ Bildirim hatası: $e");
  }
}

// 🔧 YENİ: Artık sadece "sıradaki vakit" değil, günün TÜM vakitleri üstte,
// sıradaki vakit (kalan süreyle birlikte) en altta vurgulanmış olarak
// gösteriliyor. `vakitler` sırayla İmsak→Yatsı olmalı.
Future<void> updateNotification(
  String remainingTime,
  String nextPrayer,
  Map<String, String> vakitler,
) async {
  if (kIsWeb) return;

  try {
    // Günün tüm vakitlerini "İmsak 05:12 · Güneş 06:45 · ..." şeklinde,
    // sıradaki vakti en sona, kalan süreyle birlikte ekliyoruz.
    const sira = ["Imsak", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi"];
    const gosterimAdi = {
      "Imsak": "İmsak",
      "Gunes": "Güneş",
      "Ogle": "Öğle",
      "Ikindi": "İkindi",
      "Aksam": "Akşam",
      "Yatsi": "Yatsı",
    };
    final ustSatir = sira
        .where((v) => vakitler[v] != null && vakitler[v] != "--:--")
        .map((v) => "${gosterimAdi[v]} ${vakitler[v]}")
        .join("  •  ");

    final bigText = BigTextStyleInformation(
      "$ustSatir\n\n⏰ $nextPrayer vaktine $remainingTime kaldı",
      contentTitle: "🕌 Bugünün Namaz Vakitleri",
      summaryText: "Güncelleniyor",
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'namaz_vakitleri_sabit',
        'Sabit Namaz Vakti',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        showWhen: false,
        styleInformation: bigText,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      999,
      "🕌 Bugünün Namaz Vakitleri",
      "$ustSatir  —  $nextPrayer vaktine $remainingTime kaldı",
      details,
    );
    debugPrint("✅ Sabit bildirim güncellendi: $remainingTime");
  } catch (e) {
    debugPrint("❌ Sabit bildirim hatası: $e");
  }
}

Future<void> cancelNotification() async {
  try {
    await flutterLocalNotificationsPlugin.cancel(999);
    debugPrint("✅ Sabit bildirim kapatıldı");
  } catch (e) {
    debugPrint("❌ Bildirim kapatma hatası: $e");
  }
}

// ==================== ZAMANLANMIŞ BİLDİRİMLER ====================
Future<void> cancelAllScheduledNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
  debugPrint("✅ Tüm zamanlanmış bildirimler temizlendi");
}

Future<void> schedulePrayerNotifications(Map<String, String> vakitler) async {
  if (kIsWeb) return;

  await cancelAllScheduledNotifications();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Vakit anahtarlarını, API'den gelenler ile eşleşecek şekilde sabitledik
  final vakitList = [
    {"ad": "Imsak", "zaman": vakitler["Imsak"] ?? vakitler["İmsak"] ?? "--:--"},
    {"ad": "Gunes", "zaman": vakitler["Gunes"] ?? vakitler["Güneş"] ?? "--:--"},
    {"ad": "Ogle", "zaman": vakitler["Ogle"] ?? vakitler["Öğle"] ?? "--:--"},
    {
      "ad": "Ikindi",
      "zaman": vakitler["Ikindi"] ?? vakitler["İkindi"] ?? "--:--"
    },
    {"ad": "Aksam", "zaman": vakitler["Aksam"] ?? vakitler["Akşam"] ?? "--:--"},
    {"ad": "Yatsi", "zaman": vakitler["Yatsi"] ?? vakitler["Yatsı"] ?? "--:--"},
  ];

  for (var vakit in vakitList) {
    if (vakit["zaman"] == "--:--") continue;

    try {
      final zamanParcalari = vakit["zaman"]!.split(":");
      final saat = int.parse(zamanParcalari[0]);
      final dakika = int.parse(zamanParcalari[1]);

      DateTime vakitZamani =
          DateTime(today.year, today.month, today.day, saat, dakika);

      if (vakitZamani.isBefore(now)) {
        vakitZamani = vakitZamani.add(const Duration(days: 1));
      }

      await _scheduleSingleNotification(
          vakitZamani, vakit["ad"]!, vakit["zaman"]!);

      // 🔧 YENİ: "Bildirim çubuğu bir süre sonra duruyor, güncel değil"
      // sorunu için — sabit/ongoing bildirim SADECE uygulama açıkken
      // (Timer.periodic ile) güncelleniyordu. Artık her vakit sınırında
      // (OS'un kendi alarmıyla, uygulama kapalıyken bile) sabit bildirim
      // içeriği de tazeleniyor. Saniye saniye canlı geri sayım background'da
      // teknik olarak mümkün değil (bunun için native bir foreground
      // service gerekir), ama en azından bilgi asla saatlerce bayat kalmıyor.
      final vakitIndex = vakitList.indexOf(vakit);
      final sonrakiVakit =
          vakitIndex < vakitList.length - 1 ? vakitList[vakitIndex + 1] : null;
      if (sonrakiVakit != null && sonrakiVakit["zaman"] != "--:--") {
        await _scheduleSabitBarYenile(
            vakitZamani, sonrakiVakit["ad"]!, vakitler);
      }
    } catch (e) {
      debugPrint("❌ Vakit zamanlama hatası (${vakit["ad"]}): $e");
    }
  }
  debugPrint("✅ Tüm namaz vakitleri zamanlandı!");
}

// 🔧 YENİ: Sabit/ongoing bildirimi (id 999), uygulama kapalıyken bile her
// vakit değiştiğinde OS alarmıyla tazeler. Canlı saniye saymaz (bu
// arka planda mümkün değil) ama en fazla bir sonraki vakte kadar (birkaç
// saat) bayat kalır — önceden ise saatlerce/gün boyu bayat kalabiliyordu.
Future<void> _scheduleSabitBarYenile(
  DateTime zaman,
  String sonrakiVakitAdi,
  Map<String, String> vakitler,
) async {
  const gosterimAdi = {
    "Imsak": "İmsak",
    "Gunes": "Güneş",
    "Ogle": "Öğle",
    "Ikindi": "İkindi",
    "Aksam": "Akşam",
    "Yatsi": "Yatsı",
  };
  const sira = ["Imsak", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi"];
  final ustSatir = sira
      .where((v) => vakitler[v] != null && vakitler[v] != "--:--")
      .map((v) => "${gosterimAdi[v]} ${vakitler[v]}")
      .join("  •  ");
  final sonrakiSaat = vakitler[sonrakiVakitAdi] ?? "--:--";
  final sonrakiGosterim = gosterimAdi[sonrakiVakitAdi] ?? sonrakiVakitAdi;

  final tamZamanliIzinVar = await Permission.scheduleExactAlarm.isGranted;
  final scheduleMode = tamZamanliIzinVar
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  try {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      999,
      "🕌 Bugünün Namaz Vakitleri",
      "$ustSatir  —  Sıradaki: $sonrakiGosterim ($sonrakiSaat)",
      tz.TZDateTime.from(zaman, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'namaz_vakitleri_sabit',
          'Sabit Namaz Vakti',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            "$ustSatir\n\n⏰ Sıradaki: $sonrakiGosterim ($sonrakiSaat)",
            contentTitle: "🕌 Bugünün Namaz Vakitleri",
          ),
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: scheduleMode,
    );
  } catch (e) {
    debugPrint("❌ Sabit bildirim zamanlama hatası: $e");
  }
}

Future<void> _scheduleSingleNotification(
    DateTime time, String vakitAdi, String saatStr) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'namaz_vakitleri',
    'Namaz Vakitleri',
    channelDescription: 'Namaz vakitleri hatırlatıcıları',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );

  // 🔧 Android 14+'ta SCHEDULE_EXACT_ALARM izni yoksa exactAllowWhileIdle
  // platform hatası fırlatabiliyor. İzin durumuna göre güvenli moda düşüyoruz.
  final tamZamanliIzinVar = await Permission.scheduleExactAlarm.isGranted;
  final scheduleMode = tamZamanliIzinVar
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  await flutterLocalNotificationsPlugin.zonedSchedule(
    vakitAdi.hashCode,
    "🕌 $vakitAdi Vakti Geldi 🌸",
    "$vakitAdi ezanı okunuyor. ($saatStr)\nNamazınızı kılmayı unutmayın.",
    tz.TZDateTime.from(time, tz.local),
    details,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
    androidScheduleMode: scheduleMode,
  );

  debugPrint(
      "✅ Bildirim zamanlandı ($scheduleMode): $vakitAdi - ${DateFormat('HH:mm').format(time)}");
}

// ==================== EZAN VAKTİ APP ====================
class EzanVaktiApp extends StatefulWidget {
  const EzanVaktiApp({super.key});

  @override
  State<EzanVaktiApp> createState() => _EzanVaktiAppState();
}

class _EzanVaktiAppState extends State<EzanVaktiApp> {
  bool isDarkMode = false;
  bool _bildirimIzniKaliciRed = false;

  @override
  void initState() {
    super.initState();
    _temaAyariYukle();
    _izniKontrolEt();
  }

  Future<void> _izniKontrolEt() async {
    if (!kIsWeb) {
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) {
        setState(() {
          _bildirimIzniKaliciRed = true;
        });
      }
    }
  }

  Future<void> _temaAyariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('gece_modu') ?? false;
      _yaziBoyutuOlcegi = prefs.getDouble('yazi_boyutu_olcegi') ?? 1.0;
      _yaziTipi = prefs.getString('yazi_tipi') ?? 'Schyler';
    });
  }

  // 🔧 YENİ: Yazı boyutu ve yazı tipi artık uygulama genelinde,
  // MaterialApp'in `builder`ı üzerinden TEK bir yerden ayarlanıyor. Bu
  // sayede Ana Sayfa / Vakitler / Kur'an dahil hiçbir sayfanın kendi kodu
  // değişmeden, isteyen kullanıcı tüm arayüzü büyük yazıyla kullanabiliyor.
  double _yaziBoyutuOlcegi = 1.0;
  String _yaziTipi = 'Schyler';

  Future<void> _yaziBoyutunuKaydet(double deger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('yazi_boyutu_olcegi', deger);
    setState(() => _yaziBoyutuOlcegi = deger);
  }

  Future<void> _yaziTipiniKaydet(String deger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yazi_tipi', deger);
    setState(() => _yaziTipi = deger);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezan Vakti 🌸',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_yaziBoyutuOlcegi),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor:
            isDarkMode ? const Color(0xFF2D1B2E) : const Color(0xFFF5E6E8),
        scaffoldBackgroundColor:
            isDarkMode ? const Color(0xFF1A1118) : const Color(0xFFFDF8F5),
        fontFamily: _yaziTipi,
        appBarTheme: AppBarTheme(
          backgroundColor:
              isDarkMode ? const Color(0xFF2D1B2E) : const Color(0xFFFDF8F5),
          foregroundColor:
              isDarkMode ? const Color(0xFFF5B7B7) : const Color(0xFFB5627A),
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18, color: Color(0xFF4A2E3B)),
          bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF4A2E3B)),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB5627A),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDarkMode ? const Color(0xFFF5B7B7) : const Color(0xFFE8C4D0),
            foregroundColor:
                isDarkMode ? const Color(0xFF2D1B2E) : const Color(0xFF4A2E3B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? const Color(0xFFF5B7B7) : const Color(0xFFB5627A),
        ),
        cardTheme: CardThemeData(
          color: isDarkMode
              ? const Color(0xFF2D1B2E)
              : Colors.white.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 4,
          shadowColor: isDarkMode
              ? Colors.black54
              : const Color(0xFFE8C4D0).withValues(alpha: 0.3),
        ),
      ),
      home: AnaSayfaGezgini(
        isDarkMode: isDarkMode,
        onThemeChanged: (val) async {
          setState(() => isDarkMode = val);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('gece_modu', val);
        },
        bildirimIzniKaliciRed: _bildirimIzniKaliciRed,
        yaziBoyutuOlcegi: _yaziBoyutuOlcegi,
        onYaziBoyutuChanged: _yaziBoyutunuKaydet,
        yaziTipi: _yaziTipi,
        onYaziTipiChanged: _yaziTipiniKaydet,
      ),
    );
  }
}

// ==================== ARKA PLAN (PAPATYALI) ====================
class FlowerBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const FlowerBackground({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1118),
                  const Color(0xFF2D1B2E),
                  const Color(0xFF3D1F3A),
                ]
              : [
                  const Color(0xFFFDF8F5),
                  const Color(0xFFFDF0F2),
                  const Color(0xFFFFF5E6),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.06 : 0.12,
              child: Image.asset(
                'assets/images/papatya.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container();
                },
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ==================== ALT BİLGİ (FOOTER) ====================
// 🔧 YENİ: Tekrar eden footer metni artık tek bir yerden yönetiliyor.
// Ana Sayfa / Vakitler / Kur'an sayfaları kasıtlı olarak dokunulmadığı için
// bu widget SADECE Kıble, Zikirmatik ve Ayarlar gibi diğer sayfalarda
// kullanılıyor.
class AltBilgiMetni extends StatelessWidget {
  final bool isDark;
  const AltBilgiMetni({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        "🌸 Bu uygulamayı annem 🪷 için tasarladım. 🌸",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white38 : Colors.black45,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ==================== ÖZEL GÜNLER VE DOĞUM GÜNLERİ ====================
class OzelGunler {
  static final List<Map<String, dynamic>> _ozelGunler = [
    {
      'ad': '🌸 Ogretmenler Gunu',
      'tarih': '2026-11-24',
      'aciklama':
          'Basogretmen Mustafa Kemal Ataturk\'e ve tum ogretmenlere saygi ve sukran gunu.',
      'bildirim': true,
    },
    {
      'ad': '🌷 Anneler Gunu',
      'tarih': '2026-05-11',
      'aciklama':
          'Annelerimize sevgi, saygi ve sukran duygularimizi ifade ettigimiz ozel gun.',
      'bildirim': true,
    },
    {
      'ad': '🍒 Malatyalilar Gunu',
      'tarih': '2026-05-15',
      'aciklama':
          'Malatya\'nin dusman isgalinden kurtulusu, gurur ve dayanisma gunu.',
      'bildirim': true,
    },
    {
      'ad': '👩‍💻 Kadin Yazilimcilar Gunu',
      'tarih': '2026-10-13',
      'aciklama':
          'Kadin yazilimcilarin teknoloji dunyasindaki basarilarini kutladigimiz ozel gun.',
      'bildirim': true,
    },
    {
      'ad': '🎓 Akademisyenler Gunu',
      'tarih': '2026-05-19',
      'aciklama':
          'Genclik ve Spor Bayrami, Ataturk\'u Anma, tum akademisyenlerin gunu.',
      'bildirim': true,
    },
    {
      'ad': '💪 Fizyoterapistler Gunu',
      'tarih': '2026-09-08',
      'aciklama':
          'Fizyoterapistlerin saglik alanindaki onemli katkilarinin kutlandigi gun.',
      'bildirim': true,
    },
  ];

  static final List<Map<String, dynamic>> _diniGunler = [
    {
      'ad': '🕌 Mirac Kandili',
      'tarih': '2026-01-15',
      'aciklama': 'Hz. Muhammed (s.a.v.)\'in goge yukseldigi gece.',
      'bildirim': false
    },
    {
      'ad': '🕌 Berat Kandili',
      'tarih': '2026-02-02',
      'aciklama': 'Gunahlarin affedildigi, rahmet kapilarinin acildigi gece.',
      'bildirim': false
    },
    {
      'ad': '🕌 Ramazan Baslangici',
      'tarih': '2026-02-19',
      'aciklama': 'Oruc ibadetinin basladigi mubarek ay.',
      'bildirim': false
    },
    {
      'ad': '🕌 Kadir Gecesi',
      'tarih': '2026-03-16',
      'aciklama': 'Kur\'an\'in indirildigi, bin aydan hayirli gece.',
      'bildirim': false
    },
    {
      'ad': '🕌 Ramazan Bayrami',
      'tarih': '2026-03-20',
      'aciklama':
          'Ramazan ayinin sonunda oruc ibadetinin tamamlandigi, sukur ve kardeslik bayrami.',
      'bildirim': false
    },
    {
      'ad': '🕌 Kurban Bayrami',
      'tarih': '2026-05-27',
      'aciklama': 'Hac ibadetinin sembolu, fedakarlik ve paylasma bayrami.',
      'bildirim': false
    },
    {
      'ad': '🕌 Hicri Yilbasi',
      'tarih': '2026-06-16',
      'aciklama': 'Hicri takvimin baslangici, yeni bir yil.',
      'bildirim': false
    },
    {
      'ad': '🕌 Asure Gunu',
      'tarih': '2026-06-25',
      'aciklama': 'Bircok onemli olayin yasandigi, paylasma ve bereket gunu.',
      'bildirim': false
    },
    {
      'ad': '🕌 Mevlid Kandili',
      'tarih': '2026-08-24',
      'aciklama': 'Hz. Muhammed (s.a.v.)\'in dogdugu mubarek gece.',
      'bildirim': false
    },
    {
      'ad': '🕌 Regaib Kandili',
      'tarih': '2026-12-10',
      'aciklama': 'Uc aylarin baslangici, rahmet ve bereket gecesi.',
      'bildirim': false
    },
  ];

  static final List<Map<String, dynamic>> _milliGunler = [
    {
      'ad': '🇹🇷 Ulusal Egemenlik ve Cocuk Bayrami',
      'tarih': '2026-04-23',
      'aciklama':
          'Turkiye Buyuk Millet Meclisi\'nin acilisi ve cocuklara armagan edilen bayram.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Ataturk\'u Anma ve Genclik ve Spor Bayrami',
      'tarih': '2026-05-19',
      'aciklama':
          'Mustafa Kemal Ataturk\'un Samsun\'a cikisi ve genclige armagani.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Demokrasi ve Milli Birlik Gunu',
      'tarih': '2026-07-15',
      'aciklama':
          '15 Temmuz darbe girisimine karsi milletin demokrasi ve bagimsizlik mucadelesi.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Zafer Bayrami',
      'tarih': '2026-08-30',
      'aciklama':
          'Buyuk Taarruz\'un zaferle sonuclanmasi, Turk ordusunun kahramanligi.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Cumhuriyet Bayrami',
      'tarih': '2026-10-29',
      'aciklama':
          'Turkiye Cumhuriyeti\'nin ilani, bagimsizlik ve cagdaslasma bayrami.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Gaziler Gunu',
      'tarih': '2026-09-19',
      'aciklama': 'Gazilerimizi minnet ve sukranla aniyoruz.',
      'bildirim': false
    },
  ];

  static final List<Map<String, dynamic>> _digerOzelGunler = [
    {
      'ad': '🌍 Dunya Kadinlar Gunu',
      'tarih': '2026-03-08',
      'aciklama': 'Kadin haklari ve esitlik mucadelesinin simgesi.',
      'bildirim': false
    },
    {
      'ad': '💪 Dunya Engelliler Gunu',
      'tarih': '2026-12-03',
      'aciklama':
          'Engelli bireylerin haklarina dikkat cekmek icin birlesiyoruz.',
      'bildirim': false
    },
    {
      'ad': '🌍 Dunya Cocuk Haklari Gunu',
      'tarih': '2026-11-20',
      'aciklama':
          'Cocuk haklarinin korunmasi ve gelistirilmesi icin farkindalik gunu.',
      'bildirim': false
    },
    {
      'ad': '🌍 Dunya Baris Gunu',
      'tarih': '2026-09-21',
      'aciklama': 'Dunya barisi icin umut ve birlik mesaji.',
      'bildirim': false
    },
    {
      'ad': '🌍 Dunya Felsefe Gunu',
      'tarih': '2026-11-20',
      'aciklama': 'Dusunme ve sorgulama sanatini kutluyoruz.',
      'bildirim': false
    },
    {
      'ad': '🕯️ Insan Haklari Gunu',
      'tarih': '2026-12-10',
      'aciklama': 'Insan haklarinin evrenselligine vurgu yapiyoruz.',
      'bildirim': false
    },
  ];

  static List<Map<String, dynamic>> get _tumGunler {
    final List<Map<String, dynamic>> all = [];
    all.addAll(_ozelGunler);
    all.addAll(_diniGunler);
    all.addAll(_milliGunler);
    all.addAll(_digerOzelGunler);
    return all;
  }

  static Map<String, dynamic>? getYaklasanOzelGun() {
    DateTime simdi = DateTime.now();
    DateTime bugunYalin = DateTime(simdi.year, simdi.month, simdi.day);
    int currentYear = simdi.year;

    List<Map<String, dynamic>> tumGunler = [];

    for (var gun in _tumGunler) {
      String tarih = gun['tarih'];
      List<String> parts = tarih.split('-');

      DateTime hedefTarih =
          DateTime(currentYear, int.parse(parts[1]), int.parse(parts[2]));

      if (hedefTarih.isBefore(bugunYalin)) {
        hedefTarih =
            DateTime(currentYear + 1, int.parse(parts[1]), int.parse(parts[2]));
      }

      tumGunler.add({
        'ad': gun['ad'],
        'tarih': DateFormat('yyyy-MM-dd').format(hedefTarih),
        'aciklama': gun['aciklama'],
        'bildirim': gun['bildirim'] ?? false,
      });
    }

    tumGunler.sort(
      (a, b) =>
          DateTime.parse(a['tarih']).compareTo(DateTime.parse(b['tarih'])),
    );

    for (var gun in tumGunler) {
      DateTime gunTarih = DateTime.parse(gun['tarih']);
      int kalanGun = (gunTarih.difference(bugunYalin).inHours / 24).round();

      if (kalanGun == 0) {
        return {
          'ad': gun['ad'],
          'kalanGun': 0,
          'kalanGunText': '🌸 BUGUN 🌸',
          'aciklama': gun['aciklama'],
          'tarih': gun['tarih'],
          'bildirim': gun['bildirim'] ?? false,
        };
      } else if (kalanGun > 0) {
        return {
          'ad': gun['ad'],
          'kalanGun': kalanGun,
          'kalanGunText': '$kalanGun gun sonra 🌷',
          'aciklama': gun['aciklama'],
          'tarih': gun['tarih'],
          'bildirim': gun['bildirim'] ?? false,
        };
      }
    }
    return null;
  }

  static String? bugunOzelGunVarMi() {
    DateTime now = DateTime.now();
    String bugunAyGun = DateFormat('MM-dd').format(now);

    List<Map<String, dynamic>> bildirimGunleri = [];
    bildirimGunleri.addAll(_ozelGunler);

    for (var gun in bildirimGunleri) {
      String tarih = gun['tarih'];
      List<String> parts = tarih.split('-');
      String kontrolAyGun = '${parts[1]}-${parts[2]}';

      if (kontrolAyGun == bugunAyGun) {
        return gun['ad'];
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> getTumOzelGunler() {
    return _tumGunler;
  }
}

// ==================== GÜNLÜK İÇERİK ====================
class GunlukIcerikServisi {
  static int _getYilinGunu() {
    return int.parse(DateFormat("D").format(DateTime.now()));
  }

  static const List<List<int>> gununAyetiReferanslari = [
    [2, 153],
    [94, 5],
    [14, 7],
    [11, 56],
    [39, 36],
    [18, 10],
    [16, 90],
    [99, 7],
    [99, 8],
    [112, 1],
  ];

  static const List<String> ayetlerYedek = [
    "Allah sabredenlerle beraberdir. (Bakara, 153)",
    "Suphesiz guclukle beraber bir kolaylik vardir. (Insirah, 5)",
    "Eger sukrederseniz, elbette size nimetimi artiririm. (Ibrahim, 7)",
    "Ben Rabbime tevekkul ettim. (Hud, 56)",
    "Allah kuluna kafi degil midir? (Zumer, 36)",
    "Rabbimiz! Bize katindan bir rahmet ver. (Kehf, 10)",
    "Allah, adaleti, iyiligi ve akrabaya yardimi emreder. (Nahl, 90)",
    "Kim zerre kadar iyilik yaparsa onu gorur. (Zilzal, 7)",
    "Kim zerre kadar kotuluk yaparsa onu gorur. (Zilzal, 8)",
    "De ki: 'O Allah birdir.' (Ihlas, 1)",
  ];

  static const List<String> hadisler = [
    "Namaz, dinin diregidir. (Tirmizi)",
    "Kolaylastiriniz, zorlastirmayiniz; mujdeleyiniz, nefret ettirmeyiniz. (Buhari)",
    "Ameller niyetlere goredir. (Buhari)",
    "Musluman, Muslumanin kardesidir. (Muslim)",
    "Sizin en hayirliniz, ahlaki en guzel olaninizdir. (Buhari)",
    "Veren el, alan elden hayirlidir. (Buhari, Muslim)",
    "Sizden biriniz, kendisi icin istedigi kardesi icin de istemedikce gercek anlamda iman etmis olmaz. (Buhari, Muslim)",
    "Gulumseyen bile senin icin bir sadakadir. (Tirmizi)",
    "Allah guzeldir, guzelligi sever. (Muslim)",
    "Iyilik, guzel ahlaktir. (Muslim)",
  ];

  static const List<String> dualar = [
    "Rabbim! Bana ve aileme hayirli evlat ver.",
    "Allah'imi Kalbimi dinin uzere sabit kil.",
    "Rabbenâ atinâ fid-dunya haseneten ve fil ahirati haseneten ve kina azaben-nar. (Bakara, 201)",
    "Rabbi zidnî ilma. (Taha, 114)",
    "Allah'imi Beni senden uzaklastiracak her seyden koru.",
    "Rabbenağfirli ve li valideyye. (Ibrahim, 41)",
    "Hasbunallahu ve ni'mel vekil. (Al-i Imran, 173)",
  ];

  static const List<String> esmalar = [
    "Er-Rahman (Dunyada her canliya merhamet eden)",
    "Er-Rahim (Ahirette sadece muminlere merhamet eden)",
    "El-Melik (Mulkun, evrenin mutlak sahibi)",
    "El-Kuddus (Her turlu eksiklikten uzak olan)",
    "Es-Selam (Kullarini selamete cikaran)",
  ];

  static Future<String> gununAyetiGetir() async {
    final yilinGunu = _getYilinGunu();
    final ref =
        gununAyetiReferanslari[yilinGunu % gununAyetiReferanslari.length];
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gunun_ayeti_$yilinGunu';

    final cached = prefs.getString(cacheKey);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        'https://api.alquran.cloud/v1/ayah/${ref[0]}:${ref[1]}/editions/quran-uthmani,tr.diyanet',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        final arapca = data[0]['text'] as String;
        final meal = data[1]['text'] as String;
        final sonuc = "$arapca\n\"$meal\" (${_sureAdi(ref[0])}, ${ref[1]})";
        await prefs.setString(cacheKey, sonuc);
        return sonuc;
      }
    } catch (_) {}
    return ayetlerYedek[yilinGunu % ayetlerYedek.length];
  }

  static String _sureAdi(int sureNo) {
    if (sureNo >= 1 && sureNo <= 114) {
      return KuranApiServisi.resmiSureIsimleri[sureNo - 1];
    }
    return "Sure $sureNo";
  }

  static Map<String, String> getBugununIcerikleri() {
    int yilinGunu = _getYilinGunu();
    return {
      "ayet": ayetlerYedek[yilinGunu % ayetlerYedek.length],
      "hadis": hadisler[yilinGunu % hadisler.length],
      "dua": dualar[yilinGunu % dualar.length],
      "esma": esmalar[yilinGunu % esmalar.length],
    };
  }
}

// ==================== SURELER ====================
class Sureci {
  final String name;
  final String arabic;
  final String reading;
  final String meaning;
  final int number;
  Sureci({
    required this.name,
    required this.arabic,
    required this.reading,
    required this.meaning,
    required this.number,
  });
}

// ==================== KUR'AN API SERVİSİ ====================
class KuranApiServisi {
  static const String _cacheKey = 'kuran_tum_sureler_v1';
  static const String _cacheTarihKey = 'kuran_cache_tarih';
  static const String _apiUrl =
      'https://api.alquran.cloud/v1/quran/editions/quran-uthmani,en.transliteration,tr.diyanet';

  static const List<String> resmiSureIsimleri = [
    "Fatiha",
    "Bakara",
    "Al-i Imran",
    "Nisa",
    "Maide",
    "En'am",
    "A'raf",
    "Enfal",
    "Tevbe",
    "Yunus",
    "Hud",
    "Yusuf",
    "Ra'd",
    "Ibrahim",
    "Hicr",
    "Nahl",
    "Isra",
    "Kehf",
    "Meryem",
    "Taha",
    "Enbiya",
    "Hac",
    "Mu'minun",
    "Nur",
    "Furkan",
    "Suara",
    "Neml",
    "Kasas",
    "Ankebut",
    "Rum",
    "Lokman",
    "Secde",
    "Ahzab",
    "Sebe",
    "Fatir",
    "Yasin",
    "Saffat",
    "Sad",
    "Zumer",
    "Mu'min",
    "Fussilet",
    "Sura",
    "Zuhruf",
    "Duhan",
    "Casiye",
    "Ahkaf",
    "Muhammed",
    "Fetih",
    "Hucurat",
    "Kaf",
    "Zariyat",
    "Tur",
    "Necm",
    "Kamer",
    "Rahman",
    "Vakia",
    "Hadid",
    "Mucadele",
    "Hasr",
    "Mumtehine",
    "Saf",
    "Cuma",
    "Munafikun",
    "Tegabun",
    "Talak",
    "Tahrim",
    "Mulk",
    "Kalem",
    "Hakka",
    "Meâric",
    "Nuh",
    "Cin",
    "Muzzemmil",
    "Muddessir",
    "Kiâme",
    "Insan",
    "Murselat",
    "Nebe",
    "Naziat",
    "Abese",
    "Tekvir",
    "Infitâr",
    "Mutaffifin",
    "Insikak",
    "Buruc",
    "Tarik",
    "A'la",
    "Gasiye",
    "Fecr",
    "Beled",
    "Sems",
    "Leyl",
    "Duha",
    "Insirah",
    "Tin",
    "Alak",
    "Kadir",
    "Beyyine",
    "Zilzal",
    "Adiyat",
    "Karia",
    "Tekasur",
    "Asr",
    "Humeze",
    "Fil",
    "Kureys",
    "Maun",
    "Kevser",
    "Kafirun",
    "Nasr",
    "Tebbet",
    "Ihlas",
    "Felak",
    "Nas",
  ];

  static Future<List<Sureci>> tumSureleriGetir({
    bool zorlaYenile = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!zorlaYenile) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          return _cozumle(cached);
        } catch (_) {}
      }
    }

    final response =
        await http.get(Uri.parse(_apiUrl)).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception("Kur'an verisi alinamadi (kod: ${response.statusCode})");
    }

    final sureler = _apiYanitindanUret(response.body);

    await prefs.setString(
      _cacheKey,
      jsonEncode(
        sureler
            .map(
              (s) => {
                'n': s.number,
                'ad': s.name,
                'ar': s.arabic,
                'ok': s.reading,
                'me': s.meaning,
              },
            )
            .toList(),
      ),
    );
    await prefs.setString(_cacheTarihKey, DateTime.now().toIso8601String());

    return sureler;
  }

  static List<Sureci> _apiYanitindanUret(String body) {
    final data = jsonDecode(body);
    final editions = data['data'] as List;

    final arapca = editions[0]['surahs'] as List;
    final okunus = editions[1]['surahs'] as List;
    final meal = editions[2]['surahs'] as List;

    List<Sureci> sureler = [];
    for (int i = 0; i < arapca.length; i++) {
      final arAyetler = arapca[i]['ayahs'] as List;
      final okAyetler = okunus[i]['ayahs'] as List;
      final meAyetler = meal[i]['ayahs'] as List;

      final arabicMetin = arAyetler
          .map((a) => "${a['text']} ﴿${a['numberInSurah']}﴾")
          .join(' ');
      final okunusMetni = okAyetler
          .map((a) => "${a['numberInSurah']}. ${a['text']}")
          .join('  ');
      final mealMetni = meAyetler
          .map((a) => "${a['numberInSurah']}. ${a['text']}")
          .join('  ');

      final sureNo = arapca[i]['number'] as int;
      sureler.add(
        Sureci(
          name: (sureNo >= 1 && sureNo <= 114)
              ? "${resmiSureIsimleri[sureNo - 1]} Suresi"
              : "Sure $sureNo",
          number: sureNo,
          arabic: arabicMetin,
          reading: okunusMetni,
          meaning: mealMetni,
        ),
      );
    }
    return sureler;
  }

  static List<Sureci> _cozumle(String cachedJson) {
    final list = jsonDecode(cachedJson) as List;
    return list
        .map(
          (s) => Sureci(
            name: s['ad'],
            number: s['n'],
            arabic: s['ar'],
            reading: s['ok'],
            meaning: s['me'],
          ),
        )
        .toList();
  }
}

// ==================== KUR'AN WEB VIEW ====================
class KuranWebView extends StatefulWidget {
  final bool isDark;

  const KuranWebView({super.key, required this.isDark});

  @override
  State<KuranWebView> createState() => _KuranWebViewState();
}

class _KuranWebViewState extends State<KuranWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _kuranSayfasiniYukle();
  }

  void _kuranSayfasiniYukle() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(
            widget.isDark ? const Color(0xFF1A1118) : Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse('https://kuran.diyanet.gov.tr/mushaf'));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              "🌺 Kuran sayfasi yuklenirken hata olustu.\nInternet baglantinizi kontrol edin.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                  _kuranSayfasiniYukle();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5627A),
                foregroundColor: Colors.white,
              ),
              child: const Text("Yeniden Dene 🌸"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFB5627A)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "🌸 Bu uygulama AYSE NUR tarafindan annesi icin hazirlanmistir 🌸",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white38 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ==================== KIBLE WEB VIEW ====================
class KibleWebView extends StatefulWidget {
  final bool isDark;

  const KibleWebView({super.key, required this.isDark});

  @override
  State<KibleWebView> createState() => _KibleWebViewState();
}

class _KibleWebViewState extends State<KibleWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _konumIzniVerildi = false;

  @override
  void initState() {
    super.initState();
    _kibleSayfasiniYukle();
  }

  Future<void> _kibleSayfasiniYukle() async {
    if (!kIsWeb) {
      final konumStatus = await Permission.location.status;
      if (!konumStatus.isGranted) {
        await Permission.location.request();
      }
      _konumIzniVerildi = await Permission.location.isGranted;
      debugPrint("📍 Konum izni: $_konumIzniVerildi");
    }

    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(
            widget.isDark ? const Color(0xFF1A1118) : Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse('https://qiblafinder.withgoogle.com/intl/tr/'));

      if (!kIsWeb) {
        try {
          final androidController = _controller.platform;
          if (androidController is AndroidWebViewController) {
            androidController.setGeolocationEnabled(true);
          }
        } catch (e) {
          debugPrint("WebView Geolocation ayari hatasi: $e");
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              "🕋 Kible sayfasi yuklenirken hata olustu.\nInternet baglantinizi kontrol edin.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                  _kibleSayfasiniYukle();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5627A),
                foregroundColor: Colors.white,
              ),
              child: const Text("Yeniden Dene 🌸"),
            ),
          ],
        ),
      );
    }

    if (!_konumIzniVerildi && !kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 60,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              "📍 Konum izni verilmedi.\nKible bulucu icin konum izni gereklidir.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5627A),
                foregroundColor: Colors.white,
              ),
              child: const Text("Ayarlara Git 🌸"),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFB5627A)),
          ),
      ],
    );
  }
}

// ==================== ZİKİRMATİK (TESBİHAT SAYACI) ====================
class ZikirmatikSayfasi extends StatefulWidget {
  final bool isDark;

  const ZikirmatikSayfasi({super.key, required this.isDark});

  @override
  State<ZikirmatikSayfasi> createState() => _ZikirmatikSayfasiState();
}

class _ZikirmatikSayfasiState extends State<ZikirmatikSayfasi> {
  int _sayac = 0;
  int _hedef = 33;
  List<String> _zikirler = [
    "Subhanallah",
    "Elhamdulillah",
    "Allahu Ekber",
    "La ilahe illallah",
    "Estagfirullah",
  ];
  int _seciliZikirIndex = 0;
  String _yeniZikir = "";
  int _yeniZikirHedefi = 33;
  // 🔧 YENİ: Her zikrin kendi hedef sayısı olabiliyor artık (zikir metni ->
  // hedef). Önceden tek bir global hedef tüm zikirler için ortaktı.
  Map<String, int> _zikirHedefleri = {};

  @override
  void initState() {
    super.initState();
    _sayacYukle();
    _zikirleriYukle();
  }

  Future<void> _zikirleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('zikir_listesi');
    final savedIndex = prefs.getInt('secili_zikir_index');
    final savedHedefler = prefs.getString('zikir_hedefleri_map');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _zikirler = saved;
      });
    }
    if (savedHedefler != null) {
      try {
        final decoded = jsonDecode(savedHedefler) as Map<String, dynamic>;
        setState(() {
          _zikirHedefleri = decoded.map((k, v) => MapEntry(k, v as int));
        });
      } catch (_) {}
    }
    if (savedIndex != null && savedIndex < _zikirler.length) {
      setState(() {
        _seciliZikirIndex = savedIndex;
        _hedef = _zikirHedefleri[_zikirler[_seciliZikirIndex]] ?? _hedef;
      });
    }
  }

  Future<void> _zikirleriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('zikir_listesi', _zikirler);
    await prefs.setInt('secili_zikir_index', _seciliZikirIndex);
    await prefs.setString('zikir_hedefleri_map', jsonEncode(_zikirHedefleri));
  }

  Future<void> _sayacYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sayac = prefs.getInt('zikir_sayac') ?? 0;
      _hedef = prefs.getInt('zikir_hedef') ?? 33;
    });
  }

  Future<void> _sayacKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zikir_sayac', _sayac);
    await prefs.setInt('zikir_hedef', _hedef);
  }

  void _zikirEkle() {
    if (_yeniZikir.trim().isEmpty) return;
    final metin = _yeniZikir.trim();
    setState(() {
      _zikirler.add(metin);
      _zikirHedefleri[metin] = _yeniZikirHedefi;
      _yeniZikir = "";
      _yeniZikirHedefi = 33;
    });
    _zikirleriKaydet();
  }

  void _zikirSil(int index) {
    setState(() {
      _zikirler.removeAt(index);
      if (_seciliZikirIndex >= _zikirler.length) {
        _seciliZikirIndex = _zikirler.length - 1;
      }
    });
    _zikirleriKaydet();
  }

  void _arttir() {
    setState(() {
      _sayac++;
      if (_sayac >= _hedef) {
        _sayac = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("🌸 ${_zikirler[_seciliZikirIndex]} zikri tamamlandi!"),
            backgroundColor: const Color(0xFFB5627A),
            duration: const Duration(seconds: 2),
          ),
        );
        if (!kIsWeb) {
          HapticFeedback.lightImpact();
        }
      }
      _sayacKaydet();
    });
  }

  void _sifirla() {
    setState(() {
      _sayac = 0;
      _sayacKaydet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      // 🔧 DÜZELTME: Önceki sürümde klavye açılınca (yeni zikir eklerken)
      // sabit yükseklikli Column taşıyor, "Ekle" butonu diğer elemanlarla
      // üst üste biniyordu. Tüm içeriği kaydırılabilir yapıp `Expanded`ı
      // kaldırdık — artık klavye açıldığında sayfa kayıyor, hiçbir şey
      // üst üste binmiyor.
      resizeToAvoidBottomInset: true,
      body: FlowerBackground(
        isDark: widget.isDark,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color:
                              widget.isDark ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          "\"Ey iman edenler! Allah'ı çok çok zikredin.\"\nAhzab 41",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF4A2E3B),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color:
                              widget.isDark ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: _sifirla,
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF2D1B2E).withValues(alpha: 0.8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8C4D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Hedef:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, size: 28),
                            onPressed: () {
                              setState(() {
                                if (_hedef > 1) {
                                  _hedef--;
                                  _sayac = 0;
                                  if (_zikirler.isNotEmpty) {
                                    _zikirHedefleri[
                                        _zikirler[_seciliZikirIndex]] = _hedef;
                                  }
                                }
                              });
                              _sayacKaydet();
                              _zikirleriKaydet();
                            },
                          ),
                          Text(
                            "$_hedef",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB5627A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, size: 28),
                            onPressed: () {
                              setState(() {
                                if (_hedef < 999) {
                                  _hedef++;
                                  _sayac = 0;
                                  if (_zikirler.isNotEmpty) {
                                    _zikirHedefleri[
                                        _zikirler[_seciliZikirIndex]] = _hedef;
                                  }
                                }
                              });
                              _sayacKaydet();
                              _zikirleriKaydet();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _zikirler.isNotEmpty
                          ? _zikirler[_seciliZikirIndex]
                          : "Zikir ekleyin",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 22 : 28,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark
                            ? const Color(0xFFF5B7B7)
                            : const Color(0xFF4A2E3B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: isSmallScreen ? 160 : 200,
                          height: isSmallScreen ? 160 : 200,
                          child: CircularProgressIndicator(
                            value: _sayac / _hedef,
                            strokeWidth: isSmallScreen ? 10 : 12,
                            valueColor:
                                const AlwaysStoppedAnimation(Color(0xFFB5627A)),
                            backgroundColor: widget.isDark
                                ? Colors.white10
                                : const Color(0xFFE8C4D0)
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        Text(
                          "$_sayac",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 48 : 64,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFFB5627A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "/ $_hedef",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 18,
                        color: widget.isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _arttir,
                      child: Container(
                        width: isSmallScreen ? 120 : 160,
                        height: isSmallScreen ? 120 : 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: const [
                              Color(0xFFB5627A),
                              Color(0xFFE8C4D0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB5627A)
                                  .withValues(alpha: 0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "🌸",
                            style: TextStyle(
                              fontSize: 50,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _sifirla,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text("Sifirla"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                            foregroundColor:
                                widget.isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _sayac = _hedef;
                            });
                            _sayacKaydet();
                          },
                          icon: const Icon(Icons.check),
                          label: const Text("Tamamla"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8C4D0),
                            foregroundColor: const Color(0xFF4A2E3B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF2D1B2E).withValues(alpha: 0.8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8C4D0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Zikir:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: DropdownButton<int>(
                              value: _seciliZikirIndex,
                              dropdownColor: widget.isDark
                                  ? const Color(0xFF2D1B2E)
                                  : Colors.white,
                              style: TextStyle(
                                color:
                                    widget.isDark ? Colors.white : Colors.black,
                              ),
                              isExpanded: true,
                              items: _zikirler.asMap().entries.map((entry) {
                                return DropdownMenuItem(
                                  value: entry.key,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18, color: Colors.red),
                                        onPressed: () => _zikirSil(entry.key),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _seciliZikirIndex = value!;
                                  _sayac = 0;
                                  _hedef = _zikirHedefleri[
                                          _zikirler[_seciliZikirIndex]] ??
                                      33;
                                });
                                _sayacKaydet();
                                _zikirleriKaydet();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) => _yeniZikir = value,
                              decoration: InputDecoration(
                                hintText: "Yeni zikir ekle...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade50,
                              ),
                              style: TextStyle(
                                color:
                                    widget.isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _zikirEkle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB5627A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            child: const Text("Ekle"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 🔧 YENİ: Eklenecek zikrin hedef sayısı artık ayrı bir
                      // hücrede, ekleme kutusunun hemen altında belirleniyor.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Yeni zikrin hedefi:",
                                style: TextStyle(fontSize: 13)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      if (_yeniZikirHedefi > 1)
                                        _yeniZikirHedefi--;
                                    });
                                  },
                                ),
                                Text("$_yeniZikirHedefi",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB5627A))),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      if (_yeniZikirHedefi < 999)
                                        _yeniZikirHedefi++;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AltBilgiMetni(isDark: widget.isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== KIBLE PUSULASI (NATIVE) ====================
class KiblePusulasi extends StatefulWidget {
  final bool isDark;

  const KiblePusulasi({super.key, required this.isDark});

  @override
  State<KiblePusulasi> createState() => _KiblePusulasiState();
}

class _KiblePusulasiState extends State<KiblePusulasi> {
  double _heading = 0.0;
  bool _pusulaVar = true;

  // 🔧 YENİ: Önceki sürümde sadece 13 şehir için elle girilmiş, coğrafi
  // olarak hatalı bir açı tablosu vardı ve bilinmeyen şehirler sessizce
  // "Mus" açısına düşüyordu. Artık 81 ilin gerçek enlem/boylam'ı ile
  // büyük daire (great-circle bearing) formülü kullanılıyor — her il için
  // doğru sonuç verir.
  final Map<String, List<double>> _ilKoordinat = {
    "Adana": [37.0, 35.3213333],
    "Adiyaman": [37.7641667, 38.2761667],
    "Afyonkarahisar": [38.76376, 30.54034],
    "Agri": [39.7216667, 43.0566667],
    "Amasya": [40.65, 35.8333333],
    "Ankara": [39.92077, 32.85411],
    "Antalya": [36.88414, 30.70563],
    "Artvin": [41.1833333, 41.8166667],
    "Aydin": [37.8444, 27.8458],
    "Balikesir": [39.648369, 27.8826100],
    "Bilecik": [40.150131, 29.983061],
    "Bingol": [38.8853490, 40.4982910],
    "Bitlis": [38.4, 42.1166667],
    "Bolu": [40.7394790, 31.6115610],
    "Burdur": [37.7269090, 30.2888760],
    "Bursa": [40.18257, 29.06687],
    "Canakkale": [40.1553120, 26.4141600],
    "Cankiri": [40.6, 33.6166667],
    "Corum": [40.5505556, 34.9555556],
    "Denizli": [37.77652, 29.08639],
    "Diyarbakir": [37.91441, 40.2306290],
    "Edirne": [41.6666667, 26.5666667],
    "Elazig": [38.680969, 39.226398],
    "Erzincan": [39.75, 39.5],
    "Erzurum": [39.9043189, 41.2678853],
    "Eskisehir": [39.784302, 30.51922],
    "Gaziantep": [37.06622, 37.38332],
    "Giresun": [40.912811, 38.38953],
    "Gumushane": [40.4602778, 39.4813889],
    "Hakkari": [37.5833333, 43.7333333],
    "Hatay": [36.4018488, 36.3498097],
    "Isparta": [37.7666667, 30.55],
    "Mersin": [36.8, 34.6333333],
    "Istanbul": [41.00527, 28.97696],
    "Izmir": [38.41885, 27.12872],
    "Kars": [40.59267, 43.077831],
    "Kastamonu": [41.38871, 33.78273],
    "Kayseri": [38.7333333, 35.4833333],
    "Kirklareli": [41.7333333, 27.2166667],
    "Kirsehir": [39.15, 34.1666667],
    "Kocaeli": [40.8532704, 29.8815203],
    "Konya": [37.8666667, 32.4833333],
    "Kutahya": [39.4166667, 29.9833333],
    "Malatya": [38.35519, 38.30946],
    "Manisa": [38.619099, 27.428921],
    "Kahramanmaras": [37.5833333, 36.9333333],
    "Mardin": [37.3122361, 40.7351120],
    "Mugla": [37.2152778, 28.3636111],
    "Mus": [38.7432926, 41.5064823],
    "Nevsehir": [38.62442, 34.723969],
    "Nigde": [37.9666667, 34.6833333],
    "Ordu": [40.9833333, 37.8833333],
    "Rize": [41.02005, 40.523449],
    "Sakarya": [40.7568793, 30.378138],
    "Samsun": [41.292782, 36.33128],
    "Siirt": [37.94429, 41.93288],
    "Sinop": [42.0264222, 35.1550745],
    "Sivas": [39.747662, 37.017879],
    "Tekirdag": [40.9833333, 27.5166667],
    "Tokat": [40.3166667, 36.55],
    "Trabzon": [41.0, 39.7333333],
    "Tunceli": [39.1079868, 39.5401672],
    "Sanliurfa": [37.15, 38.8],
    "Usak": [38.682301, 29.40819],
    "Van": [38.4941667, 43.38],
    "Yozgat": [39.82, 34.8044444],
    "Zonguldak": [41.456409, 31.798731],
    "Aksaray": [38.36869, 34.03698],
    "Bayburt": [40.255169, 40.22488],
    "Karaman": [37.17593, 33.228748],
    "Kirikkale": [39.846821, 33.515251],
    "Batman": [37.881168, 41.13509],
    "Sirnak": [37.5163889, 42.4611111],
    "Bartin": [41.6344444, 32.3375],
    "Ardahan": [41.110481, 42.702171],
    "Igdir": [39.9166667, 44.0333333],
    "Yalova": [40.65, 29.2666667],
    "Karabuk": [41.2, 32.6333333],
    "Kilis": [36.718399, 37.12122],
    "Osmaniye": [37.06805, 36.261589],
    "Duzce": [40.843849, 31.15654],
  };

  // Kabe'nin koordinatları (sabit)
  static const double _kabeLat = 21.4225;
  static const double _kabeLon = 39.8262;

  double _kibleAcisi = 154.0;
  String? _manuelIl; // Kullanıcının bu sayfaya özel elle seçtiği il (varsa)
  String _kayitliSehir = "Mus"; // Uygulamanın genelinde seçili olan şehir

  // 🔧 YENİ: GPS ile bulunan gerçek konum + Aladhan'ın ücretsiz Kıble API'si
  // (https://api.aladhan.com/v1/qibla/{lat}/{lon}) — kendi hesaplamamız
  // yerine bilinen, güvenilir bir kaynağın sonucunu kullanıyoruz.
  String _konumKaynagi = "kayitli"; // "gps" | "kayitli" | "manuel"
  int? _gpsDogrulukYildizi; // GPS konum hassasiyetine göre 1-5 yıldız
  bool _gpsYukleniyor = false;
  String? _gpsHata;

  Stream<dynamic>? _compassStream;

  @override
  void initState() {
    super.initState();
    _pusulaKontrol();
    _konumBilgisiniYukle();
  }

  // 🔧 YENİ: Büyük daire (great-circle) formülüyle iki koordinat arasındaki
  // yön açısını (bearing) derece cinsinden hesaplar. SADECE GPS/API
  // ulaşılamadığında (internetsizken) yedek olarak kullanılıyor; asıl
  // kaynak Aladhan'ın kendi Kıble API'si.
  double _bearingHesapla(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (theta * 180 / math.pi + 360) % 360;
  }

  // GPS konum hassasiyeti (metre) → yıldız. Tek bir "API" kıbleyi başka
  // bir API'den daha "doğru" göstermez (ikisi de aynı matematiği kullanır);
  // gerçek fark GPS sinyalinin hassasiyetinden gelir, o yüzden yıldızı
  // buna göre veriyoruz.
  int _dogrulukYildizHesapla(double metreDogruluk) {
    if (metreDogruluk <= 10) return 5;
    if (metreDogruluk <= 25) return 4;
    if (metreDogruluk <= 50) return 3;
    if (metreDogruluk <= 100) return 2;
    return 1;
  }

  Future<void> _gpsIleKibleBul() async {
    setState(() {
      _gpsYukleniyor = true;
      _gpsHata = null;
    });
    try {
      // 1) Konum servisleri açık mı?
      final servisAcik = await Geolocator.isLocationServiceEnabled();
      if (!servisAcik) {
        setState(() {
          _gpsHata =
              "Konum servisleri kapalı. Lütfen telefon ayarlarından açın.";
          _gpsYukleniyor = false;
        });
        return;
      }

      // 2) Konum izni iste
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        setState(() {
          _gpsHata = "Konum izni verilmedi.";
          _gpsYukleniyor = false;
        });
        return;
      }

      // 3) Gerçek GPS konumunu al
      final konum = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      double aci;
      try {
        // 4) Aladhan'ın ücretsiz Kıble API'sinden yön açısını al (kendi
        // hesaplamamızı değil, bilinen bir servisi kullanıyoruz).
        final yanit = await http.get(Uri.parse(
            'https://api.aladhan.com/v1/qibla/${konum.latitude}/${konum.longitude}'));
        final veri = jsonDecode(yanit.body);
        aci = (veri['data']['direction'] as num).toDouble();
      } catch (_) {
        // İnternet yoksa yerel hesaplamaya düş (yine doğru, sadece
        // API'den doğrulanmamış).
        aci = _bearingHesapla(
            konum.latitude, konum.longitude, _kabeLat, _kabeLon);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kible_manuel_il');

      setState(() {
        _kibleAcisi = aci;
        _konumKaynagi = "gps";
        _manuelIl = null;
        _gpsDogrulukYildizi = _dogrulukYildizHesapla(konum.accuracy);
        _gpsYukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _gpsHata = "Konum alınamadı: $e";
        _gpsYukleniyor = false;
      });
    }
  }

  void _kibleAcisiniGuncelle(String il) {
    final koordinat = _ilKoordinat[il];
    if (koordinat == null) return;
    setState(() {
      _kibleAcisi =
          _bearingHesapla(koordinat[0], koordinat[1], _kabeLat, _kabeLon);
    });
  }

  Future<void> _konumBilgisiniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final kayitli = prefs.getString('secilen_sehir') ?? "Mus";
    final manuel = prefs.getString('kible_manuel_il');
    setState(() {
      _kayitliSehir = _ilKoordinat.containsKey(kayitli) ? kayitli : "Mus";
      _manuelIl =
          (manuel != null && _ilKoordinat.containsKey(manuel)) ? manuel : null;
    });
    _kibleAcisiniGuncelle(_manuelIl ?? _kayitliSehir);
  }

  // "Mevcut konumumu kullan": uygulamanın Vakitler sayfasında seçili olan
  // kayıtlı şehre döner (manuel/GPS geçersiz kılmayı sıfırlar/nulldurur).
  Future<void> _kayitliKonumuKullan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kible_manuel_il');
    setState(() {
      _manuelIl = null;
      _konumKaynagi = "kayitli";
      _gpsDogrulukYildizi = null;
      _gpsHata = null;
    });
    _kibleAcisiniGuncelle(_kayitliSehir);
  }

  Future<void> _manuelIlSec(String il) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kible_manuel_il', il);
    setState(() {
      _manuelIl = il;
      _konumKaynagi = "manuel";
      _gpsDogrulukYildizi = null;
      _gpsHata = null;
    });
    _kibleAcisiniGuncelle(il);
  }

  void _manuelIlSeciciyiGoster() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: widget.isDark ? const Color(0xFF2D1B2E) : Colors.white,
        title: const Text("🌸 Şehir Seç",
            style: TextStyle(
                color: Color(0xFFB5627A), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            children: (_ilKoordinat.keys.toList()..sort()).map((il) {
              return ListTile(
                title: Text(il),
                trailing: (il == (_manuelIl ?? _kayitliSehir))
                    ? const Icon(Icons.check, color: Color(0xFFB5627A))
                    : null,
                onTap: () {
                  _manuelIlSec(il);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Kapat", style: TextStyle(color: Color(0xFFB5627A))),
          ),
        ],
      ),
    );
  }

  void _pusulaKontrol() {
    try {
      _compassStream = FlutterCompass.events;
      _pusulaVar = true;
    } catch (e) {
      setState(() {
        _pusulaVar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlowerBackground(
        isDark: widget.isDark,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      "🕋 Kible Pusulasi",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF4A2E3B),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.help_outline,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: widget.isDark
                                ? const Color(0xFF2D1B2E)
                                : Colors.white,
                            title: const Text("🕋 Kible Pusulasi"),
                            content: const Text(
                              "Telefonu düz tutun ve etrafinda dönün.\n"
                              "🌷 Pembe ok Kible yönünü gösterir.\n"
                              "📍 Kirmizi ok Kuzey yönünü gösterir.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Tamam 🌸"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // 🔧 YENİ: Konum kaynağı seçimi — kayıtlı şehri kullan, elle
              // farklı bir şehir seç, ya da manuel seçimi sıfırla.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF2D1B2E).withValues(alpha: 0.8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8C4D0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 18,
                              color: widget.isDark
                                  ? const Color(0xFFF5B7B7)
                                  : const Color(0xFFB5627A)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _konumKaynagi == "gps"
                                  ? "Konum: GPS (canlı)"
                                  : "Konum: ${_manuelIl ?? _kayitliSehir}"
                                      "${_konumKaynagi == 'manuel' ? ' (manuel)' : ' (kayıtlı)'}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.white
                                    : const Color(0xFF4A2E3B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_gpsDogrulukYildizi != null)
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < _gpsDogrulukYildizi!
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 14,
                                  color: const Color(0xFFB5627A),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_gpsHata != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_gpsHata!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ),
                      const SizedBox(height: 8),
                      // 🔧 YENİ: GPS ile gerçek konumu bul (Aladhan Kıble
                      // API'si kullanılıyor) — birincil ve önerilen yöntem.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _gpsYukleniyor ? null : _gpsIleKibleBul,
                          icon: _gpsYukleniyor
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.gps_fixed, size: 18),
                          label: Text(_gpsYukleniyor
                              ? "Konum bulunuyor..."
                              : "📍 Konumumu Bul (GPS)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB5627A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _manuelIlSeciciyiGoster,
                              icon:
                                  const Icon(Icons.edit_location_alt, size: 18),
                              label: const Text("Şehir Seç"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB5627A),
                                side:
                                    const BorderSide(color: Color(0xFFB5627A)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _konumKaynagi == "kayitli"
                                  ? null
                                  : _kayitliKonumuKullan,
                              icon: const Icon(Icons.restart_alt, size: 18),
                              label: const Text("Sıfırla"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: widget.isDark
                                    ? Colors.white70
                                    : Colors.black54,
                                side: BorderSide(
                                    color: widget.isDark
                                        ? Colors.white24
                                        : Colors.black26),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sensor_occupied,
                        size: 60,
                        color: widget.isDark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Pusula sensörü bulunamadi.\nTelefonunuz pusula destegi sunmuyor olabilir.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              widget.isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _pusulaVar = true;
                          });
                          _pusulaKontrol();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB5627A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Yeniden Dene 🌸"),
                      ),
                    ],
                  ),
                ),
              ),
              if (_pusulaVar)
                Expanded(
                  child: StreamBuilder(
                    stream: _compassStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        _heading = snapshot.data!.heading ?? 0.0;
                      }
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isDark
                                        ? const Color(0xFF2D1B2E)
                                            .withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE8C4D0)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.rotate(
                                  angle: -_heading * 3.14159 / 180,
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFB5627A),
                                        width: 2,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 2,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                          alignment: Alignment.bottomCenter,
                                          child: const Text(
                                            "N",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 2,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.grey,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                          alignment: Alignment.topCenter,
                                          child: const Text(
                                            "S",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Transform.rotate(
                                          angle: _kibleAcisi * 3.14159 / 180,
                                          child: Container(
                                            width: 2,
                                            height: 90,
                                            color: const Color(0xFFB5627A),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Icon(
                                                  Icons.arrow_upward,
                                                  color:
                                                      const Color(0xFFB5627A),
                                                  size: 30,
                                                ),
                                                const Text(
                                                  "🕋",
                                                  style:
                                                      TextStyle(fontSize: 20),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.local_florist,
                                  size: 40,
                                  color: Color(0xFFB5627A),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Kible Acisi: ${_kibleAcisi.toStringAsFixed(1)}°",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.white70
                                    : const Color(0xFF4A2E3B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "🌸 Pembe ok Kible'yi gösterir",
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDark
                                    ? Colors.white54
                                    : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AltBilgiMetni(isDark: widget.isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ANA SAYFA GEZGİNİ ====================
class AnaSayfaGezgini extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool bildirimIzniKaliciRed;
  final double yaziBoyutuOlcegi;
  final ValueChanged<double> onYaziBoyutuChanged;
  final String yaziTipi;
  final ValueChanged<String> onYaziTipiChanged;

  const AnaSayfaGezgini({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.bildirimIzniKaliciRed,
    required this.yaziBoyutuOlcegi,
    required this.onYaziBoyutuChanged,
    required this.yaziTipi,
    required this.onYaziTipiChanged,
  });

  @override
  State<AnaSayfaGezgini> createState() => _AnaSayfaGezginiState();
}

class _AnaSayfaGezginiState extends State<AnaSayfaGezgini> {
  int _aktifSayfaIndex = 0;
  String secilenSehir = "Secilmedi";
  String secilenIlce = "Secilmedi";
  bool isLoading = false;
  List<dynamic> aylikVeriHavuzu = [];

  final Map<String, List<String>> _ilIlceMap = {
    "Adana": [
      "Aladag",
      "Ceyhan",
      "Cukurova",
      "Feke",
      "Imamoglu",
      "Karaisali",
      "Karatas",
      "Kozan",
      "Pozanti",
      "Saimbeyli",
      "Saricam",
      "Seyhan",
      "Tufanbeyli",
      "Yumurtalik",
      "Yuregir"
    ],
    "Adiyaman": [
      "Merkez",
      "Besni",
      "Celikhan",
      "Gerger",
      "Golbasi",
      "Kahta",
      "Samsat",
      "Sincik",
      "Tut"
    ],
    "Afyonkarahisar": [
      "Merkez",
      "Basmakci",
      "Bayat",
      "Bolvadin",
      "Cay",
      "Cobanlar",
      "Dazkiri",
      "Dinar",
      "Emirdag",
      "Evciler",
      "Hocalar",
      "Ihsaniye",
      "Iscehisar",
      "Kiziloren",
      "Sandikli",
      "Sinanpasa",
      "Suhut",
      "Sultandagi"
    ],
    "Agri": [
      "Merkez",
      "Diyadin",
      "Dogubayazit",
      "Eleskirt",
      "Hamur",
      "Patnos",
      "Taslicay",
      "Tutak"
    ],
    "Amasya": [
      "Merkez",
      "Goynucek",
      "Gumushacikoy",
      "Hamamozu",
      "Merzifon",
      "Suluova",
      "Tasova"
    ],
    "Ankara": [
      "Akyurt",
      "Altindag",
      "Ayas",
      "Bala",
      "Beypazari",
      "Camlidere",
      "Cankaya",
      "Cubuk",
      "Elmadag",
      "Etimesgut",
      "Evren",
      "Golbasi",
      "Gudul",
      "Haymana",
      "Kahramankazan",
      "Kalecik",
      "Kecioren",
      "Kizilcahamam",
      "Mamak",
      "Nallihan",
      "Polatli",
      "Pursaklar",
      "Sereflikochisar",
      "Sincan",
      "Yenimahalle"
    ],
    "Antalya": [
      "Akseki",
      "Aksu",
      "Alanya",
      "Demre",
      "Dosemealti",
      "Elmali",
      "Finike",
      "Gazipasa",
      "Gundogmus",
      "Ibradi",
      "Kas",
      "Kemer",
      "Kepez",
      "Konyaalti",
      "Korkuteli",
      "Kumluca",
      "Manavgat",
      "Muratpasa",
      "Serik"
    ],
    "Artvin": [
      "Merkez",
      "Ardanuc",
      "Arhavi",
      "Borcka",
      "Hopa",
      "Kemalpasa",
      "Murgul",
      "Savsat",
      "Yusufeli"
    ],
    "Aydin": [
      "Bozdogan",
      "Buharkent",
      "Cine",
      "Didim",
      "Efeler",
      "Germencik",
      "Incirliova",
      "Karacasu",
      "Karpuzlu",
      "Kocarli",
      "Kosk",
      "Kusadasi",
      "Kuyucak",
      "Nazilli",
      "Soke",
      "Sultanhisar",
      "Yenipazar"
    ],
    "Balikesir": [
      "Altieylul",
      "Ayvalik",
      "Balya",
      "Bandirma",
      "Bigadic",
      "Burhaniye",
      "Dursunbey",
      "Edremit",
      "Erdek",
      "Gomec",
      "Gonen",
      "Havran",
      "Ivrindi",
      "Karesi",
      "Kepsut",
      "Manyas",
      "Marmara",
      "Savastepe",
      "Sindirgi",
      "Susurluk"
    ],
    "Bilecik": [
      "Merkez",
      "Bozuyuk",
      "Golpazari",
      "Inhisar",
      "Osmaneli",
      "Pazaryeri",
      "Sogut",
      "Yenipazar"
    ],
    "Bingol": [
      "Merkez",
      "Adakli",
      "Genc",
      "Karliova",
      "Kigi",
      "Solhan",
      "Yayladere",
      "Yedisu"
    ],
    "Bitlis": [
      "Merkez",
      "Adilcevaz",
      "Ahlat",
      "Guroymak",
      "Hizan",
      "Mutki",
      "Tatvan"
    ],
    "Bolu": [
      "Merkez",
      "Dortdivan",
      "Gerede",
      "Goynuk",
      "Kibriscik",
      "Mengen",
      "Mudurnu",
      "Seben",
      "Yenicaga"
    ],
    "Burdur": [
      "Merkez",
      "Aglasun",
      "Altinyayla",
      "Bucak",
      "Cavdir",
      "Celtikci",
      "Golhisar",
      "Karamanli",
      "Kemer",
      "Tefenni",
      "Yesilova"
    ],
    "Bursa": [
      "Buyukorhan",
      "Gemlik",
      "Gursu",
      "Harmancik",
      "Inegol",
      "Iznik",
      "Karacabey",
      "Keles",
      "Kestel",
      "Mudanya",
      "Mustafakemalpasa",
      "Nilufer",
      "Orhaneli",
      "Orhangazi",
      "Osmangazi",
      "Yenisehir",
      "Yildirim"
    ],
    "Canakkale": [
      "Merkez",
      "Ayvacik",
      "Bayramic",
      "Biga",
      "Bozcaada",
      "Can",
      "Eceabat",
      "Ezine",
      "Gelibolu",
      "Gokceada",
      "Lapseki",
      "Yenice"
    ],
    "Cankiri": [
      "Merkez",
      "Atkaracalar",
      "Bayramoren",
      "Cerkes",
      "Eldivan",
      "Ilgaz",
      "Kizilirmak",
      "Korgun",
      "Kursunlu",
      "Orta",
      "Sabanozu",
      "Yaprakli"
    ],
    "Corum": [
      "Merkez",
      "Alaca",
      "Bayat",
      "Bogazkale",
      "Dodurga",
      "Iskilip",
      "Kargi",
      "Lacin",
      "Mecitozu",
      "Oguzlar",
      "Ortakoy",
      "Osmancik",
      "Sungurlu",
      "Ugurludag"
    ],
    "Denizli": [
      "Acipayam",
      "Babadag",
      "Baklan",
      "Bekilli",
      "Beyagac",
      "Bozkurt",
      "Buldan",
      "Cal",
      "Cameli",
      "Cardak",
      "Civril",
      "Guney",
      "Honaz",
      "Kale",
      "Merkezefendi",
      "Pamukkale",
      "Saraykoy",
      "Serinhisar",
      "Tavas"
    ],
    "Diyarbakir": [
      "Baglar",
      "Bismil",
      "Cermik",
      "Cinar",
      "Cungus",
      "Dicle",
      "Egil",
      "Ergani",
      "Hani",
      "Hazro",
      "Kayapinar",
      "Kocakoy",
      "Kulp",
      "Lice",
      "Silvan",
      "Sur",
      "Yenisehir"
    ],
    "Edirne": [
      "Merkez",
      "Enez",
      "Havsa",
      "Ipsala",
      "Kesan",
      "Lalapasa",
      "Meric",
      "Suloglu",
      "Uzunkopru"
    ],
    "Elazig": [
      "Merkez",
      "Agin",
      "Alacakaya",
      "Aricak",
      "Baskil",
      "Karakocan",
      "Keban",
      "Kovancilar",
      "Maden",
      "Palu",
      "Sivrice"
    ],
    "Erzincan": [
      "Merkez",
      "Cayirli",
      "Ilic",
      "Kemah",
      "Kemaliye",
      "Otlukbeli",
      "Refahiye",
      "Tercan",
      "Uzumlu"
    ],
    "Erzurum": [
      "Askale",
      "Aziziye",
      "Cat",
      "Hinis",
      "Horasan",
      "Ispir",
      "Karacoban",
      "Karayazi",
      "Koprukoy",
      "Narman",
      "Oltu",
      "Olur",
      "Palandoken",
      "Pasinler",
      "Pazaryolu",
      "Senkaya",
      "Tekman",
      "Tortum",
      "Uzundere",
      "Yakutiye"
    ],
    "Eskisehir": [
      "Alpu",
      "Beylikova",
      "Cifteler",
      "Gunyuzu",
      "Han",
      "Inonu",
      "Mahmudiye",
      "Mihalgazi",
      "Mihaliccik",
      "Odunpazari",
      "Saricakaya",
      "Seyitgazi",
      "Sivrihisar",
      "Tepebasi"
    ],
    "Gaziantep": [
      "Araban",
      "Islahiye",
      "Karkamis",
      "Nizip",
      "Nurdagi",
      "Oguzeli",
      "Sahinbey",
      "Sehitkamil",
      "Yavuzeli"
    ],
    "Giresun": [
      "Merkez",
      "Alucra",
      "Bulancak",
      "Camoluk",
      "Canakci",
      "Dereli",
      "Dogankent",
      "Espiye",
      "Eynesil",
      "Gorele",
      "Guce",
      "Kesap",
      "Piraziz",
      "Sebinkarahisar",
      "Tirebolu",
      "Yaglidere"
    ],
    "Gumushane": ["Merkez", "Kelkit", "Kose", "Kurtun", "Siran", "Torul"],
    "Hakkari": ["Merkez", "Cukurca", "Derecik", "Semdinli", "Yuksekova"],
    "Hatay": [
      "Altinozu",
      "Antakya",
      "Arsuz",
      "Belen",
      "Defne",
      "Dortyol",
      "Erzin",
      "Hassa",
      "Iskenderun",
      "Kirikhan",
      "Kumlu",
      "Payas",
      "Reyhanli",
      "Samandag",
      "Yayladagi"
    ],
    "Isparta": [
      "Merkez",
      "Aksu",
      "Atabey",
      "Egirdir",
      "Gelendost",
      "Gonen",
      "Keciborlu",
      "Sarkikaraagac",
      "Senirkent",
      "Sutculer",
      "Uluborlu",
      "Yalvac",
      "Yenisarbademli"
    ],
    "Mersin": [
      "Akdeniz",
      "Anamur",
      "Aydincik",
      "Bozyazi",
      "Camliyayla",
      "Erdemli",
      "Gulnar",
      "Mezitli",
      "Mut",
      "Silifke",
      "Tarsus",
      "Toroslar",
      "Yenisehir"
    ],
    "Istanbul": [
      "Adalar",
      "Arnavutkoy",
      "Atasehir",
      "Avcilar",
      "Bagcilar",
      "Bahcelievler",
      "Bakirkoy",
      "Basaksehir",
      "Bayrampasa",
      "Besiktas",
      "Beykoz",
      "Beylikduzu",
      "Beyoglu",
      "Buyukcekmece",
      "Catalca",
      "Cekmekoy",
      "Esenler",
      "Esenyurt",
      "Eyupsultan",
      "Fatih",
      "Gaziosmanpasa",
      "Gungoren",
      "Kadikoy",
      "Kagithane",
      "Kartal",
      "Kucukcekmece",
      "Maltepe",
      "Pendik",
      "Sancaktepe",
      "Sariyer",
      "Sile",
      "Silivri",
      "Sisli",
      "Sultanbeyli",
      "Sultangazi",
      "Tuzla",
      "Umraniye",
      "Uskudar",
      "Zeytinburnu"
    ],
    "Izmir": [
      "Aliaga",
      "Balcova",
      "Bayindir",
      "Bayrakli",
      "Bergama",
      "Beydag",
      "Bornova",
      "Buca",
      "Cesme",
      "Cigli",
      "Dikili",
      "Foca",
      "Gaziemir",
      "Guzelbahce",
      "Karabaglar",
      "Karaburun",
      "Karsiyaka",
      "Kemalpasa",
      "Kinik",
      "Kiraz",
      "Konak",
      "Menderes",
      "Menemen",
      "Narlidere",
      "Odemis",
      "Seferihisar",
      "Selcuk",
      "Tire",
      "Torbali",
      "Urla"
    ],
    "Kars": [
      "Merkez",
      "Akyaka",
      "Arpacay",
      "Digor",
      "Kagizman",
      "Sarikamis",
      "Selim",
      "Susuz"
    ],
    "Kastamonu": [
      "Merkez",
      "Abana",
      "Agli",
      "Arac",
      "Azdavay",
      "Bozkurt",
      "Catalzeytin",
      "Cide",
      "Daday",
      "Devrekani",
      "Doganyurt",
      "Hanonu",
      "Ihsangazi",
      "Inebolu",
      "Kure",
      "Pinarbasi",
      "Senpazar",
      "Seydiler",
      "Taskopru",
      "Tosya"
    ],
    "Kayseri": [
      "Akkisla",
      "Bunyan",
      "Develi",
      "Felahiye",
      "Hacilar",
      "Incesu",
      "Kocasinan",
      "Melikgazi",
      "Ozvatan",
      "Pinarbasi",
      "Sarioglan",
      "Sariz",
      "Talas",
      "Tomarza",
      "Yahyali",
      "Yesilhisar"
    ],
    "Kirklareli": [
      "Merkez",
      "Babaeski",
      "Demirkoy",
      "Kofcaz",
      "Luleburgaz",
      "Pehlivankoy",
      "Pinarhisar",
      "Vize"
    ],
    "Kirsehir": [
      "Merkez",
      "Akcakent",
      "Akpinar",
      "Boztepe",
      "Cicekdagi",
      "Kaman",
      "Mucur"
    ],
    "Kocaeli": [
      "Basiskele",
      "Cayirova",
      "Darica",
      "Derince",
      "Dilovasi",
      "Gebze",
      "Golcuk",
      "Izmit",
      "Kandira",
      "Karamursel",
      "Kartepe",
      "Korfez"
    ],
    "Konya": [
      "Ahirli",
      "Akoren",
      "Aksehir",
      "Altinekin",
      "Beysehir",
      "Bozkir",
      "Celtik",
      "Cihanbeyli",
      "Cumra",
      "Derbent",
      "Derebucak",
      "Doganhisar",
      "Emirgazi",
      "Eregli",
      "Guneysinir",
      "Hadim",
      "Halkapinar",
      "Huyuk",
      "Ilgin",
      "Kadinhani",
      "Karapinar",
      "Karatay",
      "Kulu",
      "Meram",
      "Sarayonu",
      "Selcuklu",
      "Seydisehir",
      "Taskent",
      "Tuzlukcu",
      "Yalihuyuk",
      "Yunak"
    ],
    "Kutahya": [
      "Merkez",
      "Altintas",
      "Aslanapa",
      "Cavdarhisar",
      "Domanic",
      "Dumlupinar",
      "Emet",
      "Gediz",
      "Hisarcik",
      "Pazarlar",
      "Saphane",
      "Simav",
      "Tavsanli"
    ],
    "Malatya": [
      "Akcadag",
      "Arapgir",
      "Arguvan",
      "Battalgazi",
      "Darende",
      "Dogansehir",
      "Doganyol",
      "Hekimhan",
      "Kale",
      "Kuluncak",
      "Puturge",
      "Yazihan",
      "Yesilyurt"
    ],
    "Manisa": [
      "Ahmetli",
      "Akhisar",
      "Alasehir",
      "Demirci",
      "Golmarmara",
      "Gordes",
      "Kirkagac",
      "Koprubasi",
      "Kula",
      "Salihli",
      "Sarigol",
      "Saruhanli",
      "Sehzadeler",
      "Selendi",
      "Soma",
      "Turgutlu",
      "Yunusemre"
    ],
    "Kahramanmaras": [
      "Afsin",
      "Andirin",
      "Caglayancerit",
      "Dulkadiroglu",
      "Ekinozu",
      "Elbistan",
      "Goksun",
      "Nurhak",
      "Onikisubat",
      "Pazarcik",
      "Turkoglu"
    ],
    "Mardin": [
      "Artuklu",
      "Dargecit",
      "Derik",
      "Kiziltepe",
      "Mazidagi",
      "Midyat",
      "Nusaybin",
      "Omerli",
      "Savur",
      "Yesilli"
    ],
    "Mugla": [
      "Bodrum",
      "Dalaman",
      "Datca",
      "Fethiye",
      "Kavaklidere",
      "Koycegiz",
      "Marmaris",
      "Mentese",
      "Milas",
      "Ortaca",
      "Seydikemer",
      "Ula",
      "Yatagan"
    ],
    "Mus": ["Merkez", "Bulanik", "Haskoy", "Korkut", "Malazgirt", "Varto"],
    "Nevsehir": [
      "Merkez",
      "Acigol",
      "Avanos",
      "Derinkuyu",
      "Gulsehir",
      "Hacibektas",
      "Kozakli",
      "Urgup"
    ],
    "Nigde": ["Merkez", "Altunhisar", "Bor", "Camardi", "Ciftlik", "Ulukisla"],
    "Ordu": [
      "Akkus",
      "Altinordu",
      "Aybasti",
      "Camas",
      "Catalpinar",
      "Caybasi",
      "Fatsa",
      "Golkoy",
      "Gulyali",
      "Gurgentepe",
      "Ikizce",
      "Kabaduz",
      "Kabatas",
      "Korgan",
      "Kumru",
      "Mesudiye",
      "Persembe",
      "Ulubey",
      "Unye"
    ],
    "Rize": [
      "Merkez",
      "Ardesen",
      "Camlihemsin",
      "Cayeli",
      "Derepazari",
      "Findikli",
      "Guneysu",
      "Hemsin",
      "Ikizdere",
      "Iyidere",
      "Kalkandere",
      "Pazar"
    ],
    "Sakarya": [
      "Adapazari",
      "Akyazi",
      "Arifiye",
      "Erenler",
      "Ferizli",
      "Geyve",
      "Hendek",
      "Karapurcek",
      "Karasu",
      "Kaynarca",
      "Kocaali",
      "Pamukova",
      "Sapanca",
      "Serdivan",
      "Sogutlu",
      "Tarakli"
    ],
    "Samsun": [
      "19 Mayis",
      "Alacam",
      "Asarcik",
      "Atakum",
      "Ayvacik",
      "Bafra",
      "Canik",
      "Carsamba",
      "Havza",
      "Ilkadim",
      "Kavak",
      "Ladik",
      "Salipazari",
      "Tekkekoy",
      "Terme",
      "Vezirkopru",
      "Yakakent"
    ],
    "Siirt": [
      "Merkez",
      "Baykan",
      "Eruh",
      "Kurtalan",
      "Pervari",
      "Sirvan",
      "Tillo"
    ],
    "Sinop": [
      "Merkez",
      "Ayancik",
      "Boyabat",
      "Dikmen",
      "Duragan",
      "Erfelek",
      "Gerze",
      "Sarayduzu",
      "Turkeli"
    ],
    "Sivas": [
      "Merkez",
      "Akincilar",
      "Altinyayla",
      "Divrigi",
      "Dogansar",
      "Gemerek",
      "Golova",
      "Gurun",
      "Hafik",
      "Imranli",
      "Kangal",
      "Koyulhisar",
      "Sarkisla",
      "Susehri",
      "Ulas",
      "Yildizeli",
      "Zara"
    ],
    "Tekirdag": [
      "Cerkezkoy",
      "Corlu",
      "Ergene",
      "Hayrabolu",
      "Kapakli",
      "Malkara",
      "Marmaraereglisi",
      "Muratli",
      "Saray",
      "Sarkoy",
      "Suleymanpasa"
    ],
    "Tokat": [
      "Merkez",
      "Almus",
      "Artova",
      "Basciftlik",
      "Erbaa",
      "Niksar",
      "Pazar",
      "Resadiye",
      "Sulusaray",
      "Turhal",
      "Yesilyurt",
      "Zile"
    ],
    "Trabzon": [
      "Akcaabat",
      "Arakli",
      "Arsin",
      "Besikduzu",
      "Carsibasi",
      "Caykara",
      "Dernekpazari",
      "Duzkoy",
      "Hayrat",
      "Koprubasi",
      "Macka",
      "Of",
      "Ortahisar",
      "Salpazari",
      "Surmene",
      "Tonya",
      "Vakfikebir",
      "Yomra"
    ],
    "Tunceli": [
      "Merkez",
      "Cemisgezek",
      "Hozat",
      "Mazgirt",
      "Nazimiye",
      "Ovacik",
      "Pertek",
      "Pulumur"
    ],
    "Sanliurfa": [
      "Akcakale",
      "Birecik",
      "Bozova",
      "Ceylanpinar",
      "Eyyubiye",
      "Halfeti",
      "Haliliye",
      "Harran",
      "Hilvan",
      "Karakopru",
      "Siverek",
      "Suruc",
      "Viransehir"
    ],
    "Usak": ["Merkez", "Banaz", "Esme", "Karahalli", "Sivasli", "Ulubey"],
    "Van": [
      "Bahcesaray",
      "Baskale",
      "Caldiran",
      "Catak",
      "Edremit",
      "Ercis",
      "Gevas",
      "Gurpinar",
      "Ipekyolu",
      "Muradiye",
      "Ozalp",
      "Saray",
      "Tusba"
    ],
    "Yozgat": [
      "Merkez",
      "Akdagmadeni",
      "Aydincik",
      "Bogazliyan",
      "Candir",
      "Cayiralan",
      "Cekerek",
      "Kadisehri",
      "Saraykent",
      "Sarikaya",
      "Sefaatli",
      "Sorgun",
      "Yenifakili",
      "Yerkoy"
    ],
    "Zonguldak": [
      "Merkez",
      "Alapli",
      "Caycuma",
      "Devrek",
      "Eregli",
      "Gokcebey",
      "Kilimli",
      "Kozlu"
    ],
    "Aksaray": [
      "Merkez",
      "Agacoren",
      "Eskil",
      "Gulagac",
      "Guzelyurt",
      "Ortakoy",
      "Sariyahsi",
      "Sultanhani"
    ],
    "Bayburt": ["Merkez", "Aydintepe", "Demirozu"],
    "Karaman": [
      "Merkez",
      "Ayranci",
      "Basyayla",
      "Ermenek",
      "Kazimkarabekir",
      "Sariveliler"
    ],
    "Kirikkale": [
      "Merkez",
      "Bahsili",
      "Baliseyh",
      "Celebi",
      "Delice",
      "Karakecili",
      "Keskin",
      "Sulakyurt",
      "Yahsihan"
    ],
    "Batman": ["Merkez", "Besiri", "Gercus", "Hasankeyf", "Kozluk", "Sason"],
    "Sirnak": [
      "Merkez",
      "Beytussebap",
      "Cizre",
      "Guclukonak",
      "Idil",
      "Silopi",
      "Uludere"
    ],
    "Bartin": ["Merkez", "Amasra", "Kurucasile", "Ulus"],
    "Ardahan": ["Merkez", "Cildir", "Damal", "Gole", "Hanak", "Posof"],
    "Igdir": ["Merkez", "Aralik", "Karakoyunlu", "Tuzluca"],
    "Yalova": [
      "Merkez",
      "Altinova",
      "Armutlu",
      "Ciftlikkoy",
      "Cinarcik",
      "Termal"
    ],
    "Karabuk": [
      "Merkez",
      "Eflani",
      "Eskipazar",
      "Ovacik",
      "Safranbolu",
      "Yenice"
    ],
    "Kilis": ["Merkez", "Elbeyli", "Musabeyli", "Polateli"],
    "Osmaniye": [
      "Merkez",
      "Bahce",
      "Duzici",
      "Hasanbeyli",
      "Kadirli",
      "Sumbas",
      "Toprakkale"
    ],
    "Duzce": [
      "Merkez",
      "Akcakoca",
      "Cilimli",
      "Cumayeri",
      "Golyaka",
      "Gumusova",
      "Kaynasli",
      "Yigilca"
    ],
  };

  List<Map<String, String>> _kullaniciSehirler = [];

  Map<String, String> bugununVakitleri = {
    "Imsak": "--:--",
    "Gunes": "--:--",
    "Ogle": "--:--",
    "Ikindi": "--:--",
    "Aksam": "--:--",
    "Yatsi": "--:--",
  };

  String kalanSure = "00:00:00";
  String siradakiVakit = "Yukleniyor...";
  double ilerlemeOrani = 1.0;
  Timer? _saniyeSayaci;

  String _sonBildirimGonderilenVakit = "";
  int _sonBildirimGuncellemeSaniyesi = -1;

  bool _vakitOncesiUyari = true;
  double _kacDakikaOnceSlider = 15.0;
  String _bildirimSesTipi = "default";
  bool _tamEkranUyari = false;
  bool _bildirimCubugu = false;
  Map<String, bool> _seciliVakitler = {
    "Imsak": true,
    "Gunes": true,
    "Ogle": true,
    "Ikindi": true,
    "Aksam": true,
    "Yatsi": true,
  };

  final List<String> turkiyeIlleri = [
    "Adana",
    "Adiyaman",
    "Afyonkarahisar",
    "Agri",
    "Amasya",
    "Ankara",
    "Antalya",
    "Artvin",
    "Aydin",
    "Balikesir",
    "Bilecik",
    "Bingol",
    "Bitlis",
    "Bolu",
    "Burdur",
    "Bursa",
    "Canakkale",
    "Cankiri",
    "Corum",
    "Denizli",
    "Diyarbakir",
    "Edirne",
    "Elazig",
    "Erzincan",
    "Erzurum",
    "Eskisehir",
    "Gaziantep",
    "Giresun",
    "Gumushane",
    "Hakkari",
    "Hatay",
    "Isparta",
    "Mersin",
    "Istanbul",
    "Izmir",
    "Kars",
    "Kastamonu",
    "Kayseri",
    "Kirklareli",
    "Kirsehir",
    "Kocaeli",
    "Konya",
    "Kutahya",
    "Malatya",
    "Manisa",
    "Kahramanmaras",
    "Mardin",
    "Mugla",
    "Mus",
    "Nevsehir",
    "Nigde",
    "Ordu",
    "Rize",
    "Sakarya",
    "Samsun",
    "Siirt",
    "Sinop",
    "Sivas",
    "Tekirdag",
    "Tokat",
    "Trabzon",
    "Tunceli",
    "Sanliurfa",
    "Usak",
    "Van",
    "Yozgat",
    "Zonguldak",
    "Aksaray",
    "Bayburt",
    "Karaman",
    "Kirikkale",
    "Batman",
    "Sirnak",
    "Bartin",
    "Ardahan",
    "Igdir",
    "Yalova",
    "Karabuk",
    "Kilis",
    "Osmaniye",
    "Duzce"
  ];

  String? _ozelGunMesaji;

  @override
  void initState() {
    super.initState();
    _yukleTumAyarlar().then((_) {
      if (secilenSehir != "Secilmedi") {
        ezanVakitleriniGetir();
      }
    });

    _saniyeSayaci = Timer.periodic(const Duration(seconds: 1), (timer) {
      sayaciGuncelle();
      _kaydetKalanSure();
      _ozelGunKontrol();
    });

    if (widget.bildirimIzniKaliciRed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bildirimIzniDialogGoster();
      });
    }
  }

  @override
  void dispose() {
    _saniyeSayaci?.cancel();
    super.dispose();
  }

  void _bildirimIzniDialogGoster() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF2D1B2E) : Colors.white,
        title: const Text(
          "🔔 Bildirim Izni Gerekli",
          style: TextStyle(color: Color(0xFFB5627A)),
        ),
        content: const Text(
          "Uygulamanin namaz vakitlerini hatirlatabilmesi icin bildirim izni gereklidir.\n\nLutfen Ayarlar > Uygulamalar > Ezan Vakti > Bildirimler yolunu izleyerek izni acin.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Daha Sonra",
              style: TextStyle(color: Color(0xFFB5627A)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8C4D0),
              foregroundColor: const Color(0xFF4A2E3B),
            ),
            child: const Text("Ayarlara Git 🌸"),
          ),
        ],
      ),
    );
  }

  void _ozelGunKontrol() {
    String? bugun = OzelGunler.bugunOzelGunVarMi();
    if (bugun != null && _ozelGunMesaji != bugun) {
      setState(() {
        _ozelGunMesaji = bugun;
      });
      if (_bildirimCubugu) {
        showNotification("🌸 Ozel Gun!", "$bugun kutlu olsun! 🎉", sesli: true);
      }
    }
  }

  Future<void> _kaydetKalanSure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kalan_sure', kalanSure);
    await prefs.setString('siradaki_vakit', siradakiVakit);
  }

  void _sehirEkleDiyalogunuGoster() {
    String? yerelSecilenIl;
    String? yerelSecilenIlce;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor:
                widget.isDarkMode ? const Color(0xFF2D1B2E) : Colors.white,
            title: const Text(
              "🌸 Konum Ekle",
              style: TextStyle(
                  color: Color(0xFFB5627A), fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Il Secin",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  initialValue: yerelSecilenIl,
                  items: turkiyeIlleri.map((il) {
                    return DropdownMenuItem(value: il, child: Text(il));
                  }).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      yerelSecilenIl = value;
                      yerelSecilenIlce = null;
                    });
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Ilce Secin",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                    enabled: yerelSecilenIl != null,
                  ),
                  initialValue: yerelSecilenIlce,
                  items: yerelSecilenIl != null &&
                          _ilIlceMap.containsKey(yerelSecilenIl)
                      ? _ilIlceMap[yerelSecilenIl]!.map((ilce) {
                          return DropdownMenuItem(
                              value: ilce, child: Text(ilce));
                        }).toList()
                      : [],
                  onChanged: (value) {
                    setStateDialog(() {
                      yerelSecilenIlce = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Iptal",
                    style: TextStyle(color: Color(0xFFB5627A))),
              ),
              ElevatedButton(
                onPressed: (yerelSecilenIl != null && yerelSecilenIlce != null)
                    ? () {
                        setState(() {
                          _kullaniciSehirler.add({
                            "display": "🌸 $yerelSecilenIl ($yerelSecilenIlce)",
                            "il": yerelSecilenIl!,
                            "ilce": yerelSecilenIlce!,
                          });
                          secilenSehir = yerelSecilenIl!;
                          secilenIlce = yerelSecilenIlce!;
                        });
                        _kaydetTumAyarlar();
                        ezanVakitleriniGetir();
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8C4D0),
                  foregroundColor: const Color(0xFF4A2E3B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Ekle 🌸"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> ezanVakitleriniGetir() async {
    if (secilenSehir == "Secilmedi") return;
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      String city = secilenIlce != "Merkez" ? secilenIlce : secilenSehir;
      final response = await http
          .get(
            Uri.parse(
              'https://api.aladhan.com/v1/calendarByCity?city=$city&country=Turkey&method=13',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['data'] != null && decodedData['data'].isNotEmpty) {
          aylikVeriHavuzu = decodedData['data'];
          bugununVerileriniAyristir();
        }
      }
    } catch (e) {
      debugPrint("Baglanti hatasi: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void bugununVerileriniAyristir() {
    if (aylikVeriHavuzu.isEmpty) return;
    int bugunIndex = DateTime.now().day - 1;
    if (bugunIndex >= aylikVeriHavuzu.length || bugunIndex < 0) bugunIndex = 0;
    final timings = aylikVeriHavuzu[bugunIndex]['timings'];
    if (mounted) {
      setState(() {
        bugununVakitleri = {
          "Imsak": temizleZaman(timings['Fajr']),
          "Gunes": temizleZaman(timings['Sunrise']),
          "Ogle": temizleZaman(timings['Dhuhr']),
          "Ikindi": temizleZaman(timings['Asr']),
          "Aksam": temizleZaman(timings['Maghrib']),
          "Yatsi": temizleZaman(timings['Isha']),
        };
      });
    }
    _schedulePrayerNotificationsIfReady();
    sayaciGuncelle();
  }

  void _schedulePrayerNotificationsIfReady() {
    if (bugununVakitleri.values.any((v) => v == "--:--")) return;
    schedulePrayerNotifications(bugununVakitleri);
  }

  String temizleZaman(String? v) {
    if (v == null) return "--:--";
    final match = RegExp(r'(\d{2}:\d{2})').firstMatch(v);
    return match != null ? match.group(0)! : "--:--";
  }

  void sayaciGuncelle() {
    if (bugununVakitleri.values.any((v) => v == "--:--")) return;
    final simdi = DateTime.now();
    final imsakTime = parseTime(bugununVakitleri["Imsak"]!);
    final gunesTime = parseTime(bugununVakitleri["Gunes"]!);
    final ogleTime = parseTime(bugununVakitleri["Ogle"]!);
    final ikindiTime = parseTime(bugununVakitleri["Ikindi"]!);
    final aksamTime = parseTime(bugununVakitleri["Aksam"]!);
    final yatsiTime = parseTime(bugununVakitleri["Yatsi"]!);

    DateTime hedeflenenVakit;
    DateTime baslangicTime;
    String vakitIsmi;

    if (simdi.isBefore(imsakTime)) {
      hedeflenenVakit = imsakTime;
      baslangicTime = yatsiTime.subtract(const Duration(days: 1));
      vakitIsmi = "Imsak";
    } else if (simdi.isBefore(gunesTime)) {
      hedeflenenVakit = gunesTime;
      baslangicTime = imsakTime;
      vakitIsmi = "Gunes";
    } else if (simdi.isBefore(ogleTime)) {
      hedeflenenVakit = ogleTime;
      baslangicTime = gunesTime;
      vakitIsmi = "Ogle";
    } else if (simdi.isBefore(ikindiTime)) {
      hedeflenenVakit = ikindiTime;
      baslangicTime = ogleTime;
      vakitIsmi = "Ikindi";
    } else if (simdi.isBefore(aksamTime)) {
      hedeflenenVakit = aksamTime;
      baslangicTime = ikindiTime;
      vakitIsmi = "Aksam";
    } else if (simdi.isBefore(yatsiTime)) {
      hedeflenenVakit = yatsiTime;
      baslangicTime = aksamTime;
      vakitIsmi = "Yatsi";
    } else {
      hedeflenenVakit = imsakTime.add(const Duration(days: 1));
      baslangicTime = yatsiTime;
      vakitIsmi = "Imsak";
    }

    final toplamSure = hedeflenenVakit.difference(baslangicTime);
    final kalanSureDuration = hedeflenenVakit.difference(simdi);

    if (_vakitOncesiUyari) {
      int erkenUyariDakikasi = _kacDakikaOnceSlider.toInt();
      if (kalanSureDuration.inMinutes == erkenUyariDakikasi &&
          kalanSureDuration.inSeconds % 60 == 0) {
        String uyariKey = "${vakitIsmi}_uyari_${simdi.day}";
        if (_sonBildirimGonderilenVakit != uyariKey) {
          _sonBildirimGonderilenVakit = uyariKey;
          showNotification(
            "⏰ Vakit Yaklasiyor 🌸",
            "$vakitIsmi vaktine $erkenUyariDakikasi dakika kaldi.",
          );
        }
      }
    }

    if (kalanSureDuration.inSeconds <= 0) {
      String vakitGeldiKey = "${vakitIsmi}_geldi_${simdi.day}";
      if (_seciliVakitler[vakitIsmi] == true &&
          _sonBildirimGonderilenVakit != vakitGeldiKey) {
        _sonBildirimGonderilenVakit = vakitGeldiKey;
        bool sesli = _bildirimSesTipi != "silent";
        showNotification(
          "🕌 $vakitIsmi Vakti Geldi 🌸",
          "$vakitIsmi ezani okunuyor.",
          sesli: sesli,
        );
        if (_tamEkranUyari && mounted) {
          _tamEkranUyariGoster(vakitIsmi);
        }
      }
    }

    if (mounted) {
      setState(() {
        siradakiVakit = vakitIsmi;
        ilerlemeOrani = (kalanSureDuration.inSeconds / toplamSure.inSeconds)
            .clamp(0.0, 1.0);
        kalanSure =
            "${kalanSureDuration.inHours.toString().padLeft(2, '0')}:${(kalanSureDuration.inMinutes % 60).toString().padLeft(2, '0')}:${(kalanSureDuration.inSeconds % 60).toString().padLeft(2, '0')}";
      });

      if (simdi.second != _sonBildirimGuncellemeSaniyesi) {
        _sonBildirimGuncellemeSaniyesi = simdi.second;
        _bildirimCubuguGuncelle();
      }
      _kaydetKalanSure();
    }
  }

  void _bildirimCubuguGuncelle() async {
    if (_bildirimCubugu) {
      final gosterilecekSure = kalanSure == "00:00:00" ? "--:--:--" : kalanSure;
      final gosterilecekVakit =
          siradakiVakit == "Yukleniyor..." ? "Namaz" : siradakiVakit;
      await updateNotification(
          gosterilecekSure, gosterilecekVakit, bugununVakitleri);
    } else {
      await cancelNotification();
    }
  }

  void _tamEkranUyariGoster(String vakitAdi) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF2D1B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alarm, size: 80, color: Color(0xFFE8C4D0)),
            const SizedBox(height: 16),
            Text(
              "$vakitAdi Vakti Geldi! 🌸",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB5627A),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Namazinizi kilmayi unutmayin.",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8C4D0),
                foregroundColor: const Color(0xFF4A2E3B),
              ),
              child: const Text("Tamam 🌷"),
            ),
          ],
        ),
      ),
    );
  }

  DateTime parseTime(String timeStr) {
    List<String> parcalar = timeStr.split(":");
    final simdi = DateTime.now();
    return DateTime(
      simdi.year,
      simdi.month,
      simdi.day,
      int.parse(parcalar[0]),
      int.parse(parcalar[1]),
    );
  }

  Future<void> _kaydetTumAyarlar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vakit_oncesi_uyari', _vakitOncesiUyari);
    await prefs.setDouble('kac_dakika_once_slider', _kacDakikaOnceSlider);
    await prefs.setString('bildirim_ses_tipi', _bildirimSesTipi);
    await prefs.setBool('tam_ekran_uyari', _tamEkranUyari);
    await prefs.setBool('bildirim_cubugu', _bildirimCubugu);
    await prefs.setString('secilen_sehir', secilenSehir);
    await prefs.setString('secilen_ilce', secilenIlce);
    await prefs.setString('secili_vakitler', jsonEncode(_seciliVakitler));
    await prefs.setString('kullanici_sehirler', jsonEncode(_kullaniciSehirler));
  }

  Future<void> _yukleTumAyarlar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vakitOncesiUyari = prefs.getBool('vakit_oncesi_uyari') ?? true;
      _kacDakikaOnceSlider = prefs.getDouble('kac_dakika_once_slider') ?? 15.0;
      _bildirimSesTipi = prefs.getString('bildirim_ses_tipi') ?? "default";
      _tamEkranUyari = prefs.getBool('tam_ekran_uyari') ?? false;
      _bildirimCubugu = prefs.getBool('bildirim_cubugu') ?? false;
      secilenSehir = prefs.getString('secilen_sehir') ?? "Secilmedi";
      secilenIlce = prefs.getString('secilen_ilce') ?? "Secilmedi";

      String? seciliVakitlerJson = prefs.getString('secili_vakitler');
      if (seciliVakitlerJson != null) {
        Map<String, dynamic> json = jsonDecode(seciliVakitlerJson);
        _seciliVakitler = json.map((k, v) => MapEntry(k, v as bool));
      }
      String? kullaniciSehirlerJson = prefs.getString('kullanici_sehirler');
      if (kullaniciSehirlerJson != null) {
        List<dynamic> json = jsonDecode(kullaniciSehirlerJson);
        _kullaniciSehirler =
            json.map((e) => Map<String, String>.from(e)).toList();
      }
    });
  }

  void _ayarlarMenusunuAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF2D1B2E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🌸 Uygulama Ayarlari",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB5627A)),
                        ),
                        const Divider(color: Color(0xFFE8C4D0)),
                        // 🔧 YENİ: Yazı boyutu — isteyen kullanıcı tüm
                        // arayüzü büyük yazıyla kullanabilir, hiçbir sayfa
                        // koda dokunulmadan MediaQuery üzerinden ölçekleniyor.
                        // 🔧 DÜZELTME: Üst sınır 1.6'dan 1.3'e düşürüldü.
                        // Ana Sayfa/Vakitler/Kur'an sayfalarına dokunulmadığı
                        // için (senin isteğin üzerine) bu sayfalardaki sabit
                        // genişlikli satırlar çok yüksek ölçeklerde taşabiliyordu
                        // (o sarı-siyah çizgili "overflow" uyarısı SADECE debug
                        // modda görünür, gerçek/yayınlanan APK'da görünmez —
                        // ama metin yine de kırpılabilir). Daha dar bir aralık
                        // bu riski pratikte ortadan kaldırıyor.
                        Text(
                            "🔤 Yazı Boyutu: %${(widget.yaziBoyutuOlcegi * 100).round()}",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Slider(
                          value: widget.yaziBoyutuOlcegi,
                          min: 0.9,
                          max: 1.3,
                          divisions: 8,
                          activeColor: const Color(0xFFB5627A),
                          label: "%${(widget.yaziBoyutuOlcegi * 100).round()}",
                          onChanged: (val) {
                            widget.onYaziBoyutuChanged(val);
                            setModalState(() {});
                          },
                        ),
                        const Divider(color: Color(0xFFE8C4D0)),
                        SwitchListTile(
                          title: const Text(
                              "🌷 Vaktinden once uyarilmak istiyor musun?"),
                          value: _vakitOncesiUyari,
                          onChanged: (val) {
                            setModalState(() => _vakitOncesiUyari = val);
                            setState(() => _vakitOncesiUyari = val);
                            _kaydetTumAyarlar();
                          },
                          activeThumbColor: const Color(0xFFB5627A),
                        ),
                        if (_vakitOncesiUyari) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Hatirlatma Suresi:",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  "${_kacDakikaOnceSlider.toInt()} dakika once",
                                  style: const TextStyle(
                                      color: Color(0xFFB5627A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          Slider(
                            value: _kacDakikaOnceSlider,
                            min: 1.0,
                            max: 60.0,
                            divisions: 59,
                            activeColor: const Color(0xFFB5627A),
                            inactiveColor: const Color(0xFFE8C4D0),
                            label: "${_kacDakikaOnceSlider.toInt()} dk",
                            onChanged: (double value) {
                              setModalState(() => _kacDakikaOnceSlider = value);
                              setState(() => _kacDakikaOnceSlider = value);
                              _kaydetTumAyarlar();
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text("Bildirim kurulacak vakitleri secin:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB5627A))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _seciliVakitler.keys.map((vakit) {
                            return FilterChip(
                              label: Text(vakit),
                              selected: _seciliVakitler[vakit]!,
                              onSelected: (val) {
                                setModalState(
                                    () => _seciliVakitler[vakit] = val);
                                setState(() => _seciliVakitler[vakit] = val);
                                _kaydetTumAyarlar();
                              },
                              selectedColor: const Color(0xFFE8C4D0),
                              checkmarkColor: const Color(0xFFB5627A),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text("🦋 Tam Ekran Uyari"),
                          subtitle: const Text(
                              "Ekran kapali/acik olsa da tam uyari metni kaplasin"),
                          value: _tamEkranUyari,
                          onChanged: (val) {
                            setModalState(() => _tamEkranUyari = val);
                            setState(() => _tamEkranUyari = val);
                            _kaydetTumAyarlar();
                          },
                          activeThumbColor: const Color(0xFFB5627A),
                        ),
                        if (_tamEkranUyari)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text("Uyanisi Test Et 🌸"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8C4D0),
                                foregroundColor: const Color(0xFF4A2E3B),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () => _tamEkranUyariGoster("Test"),
                            ),
                          ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text("🌼 Bildirim Cubugu"),
                          subtitle: const Text(
                              "Namaz vaktine kalan sure bildirim cubugunda sabit dursun"),
                          value: _bildirimCubugu,
                          onChanged: (val) async {
                            setModalState(() => _bildirimCubugu = val);
                            setState(() => _bildirimCubugu = val);
                            _kaydetTumAyarlar();

                            if (val) {
                              _bildirimCubuguGuncelle();
                            } else {
                              await cancelNotification();
                            }
                          },
                          activeThumbColor: const Color(0xFFB5627A),
                        ),
                        SwitchListTile(
                          title: const Text("🌙 Gece Modu"),
                          subtitle: const Text("Koyu tema kullan"),
                          value: widget.isDarkMode,
                          onChanged: (val) {
                            setModalState(() => widget.onThemeChanged(val));
                            _kaydetTumAyarlar();
                          },
                          activeThumbColor: const Color(0xFFB5627A),
                        ),
                        const SizedBox(height: 10),
                        const Text("🏙️ Sehir / Ilce Listem",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB5627A))),
                        const SizedBox(height: 5),
                        _kullaniciSehirler.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                    "Henuz hic sehir eklemediniz. Lutfen 'Yeni Ekle' butonunu kullanin. 🌷",
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                              )
                            : Column(
                                children: _kullaniciSehirler.map((sehir) {
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(sehir["display"]!),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 22),
                                      onPressed: () {
                                        setModalState(() {
                                          _kullaniciSehirler.remove(sehir);
                                        });
                                        setState(() {
                                          _kullaniciSehirler.remove(sehir);
                                        });
                                        _kaydetTumAyarlar();
                                        if (_kullaniciSehirler.isNotEmpty) {
                                          final son = _kullaniciSehirler.last;
                                          secilenSehir = son["il"]!;
                                          secilenIlce = son["ilce"]!;
                                          ezanVakitleriniGetir();
                                        } else {
                                          secilenSehir = "Secilmedi";
                                          secilenIlce = "Secilmedi";
                                          setState(() {
                                            bugununVakitleri = {
                                              "Imsak": "--:--",
                                              "Gunes": "--:--",
                                              "Ogle": "--:--",
                                              "Ikindi": "--:--",
                                              "Aksam": "--:--",
                                              "Yatsi": "--:--",
                                            };
                                          });
                                        }
                                      },
                                    ),
                                    onTap: () {
                                      setState(() {
                                        secilenSehir = sehir["il"]!;
                                        secilenIlce = sehir["ilce"]!;
                                      });
                                      ezanVakitleriniGetir();
                                      _kaydetTumAyarlar();
                                      Navigator.pop(context);
                                    },
                                  );
                                }).toList(),
                              ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Aktif Konum: $secilenSehir ($secilenIlce)",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDarkMode
                                        ? Colors.white70
                                        : Colors.black87),
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_circle,
                                  color: Color(0xFFB5627A)),
                              label: const Text("Yeni Ekle"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8C4D0),
                                foregroundColor: const Color(0xFF4A2E3B),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _sehirEkleDiyalogunuGoster();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      body: FlowerBackground(
        isDark: widget.isDarkMode,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isDarkMode
                        ? [
                            const Color(0xFF2D1B2E).withValues(alpha: 0.7),
                            const Color(0xFF1A1118).withValues(alpha: 0.5)
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.6),
                            const Color(0xFFFDF0F2).withValues(alpha: 0.3)
                          ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.local_florist,
                              color: Color(0xFFB5627A), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "$secilenSehir ($secilenIlce)",
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 15,
                                fontWeight: FontWeight.w600,
                                color: widget.isDarkMode
                                    ? const Color(0xFFF5B7B7)
                                    : const Color(0xFFB5627A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                              width: 1,
                              height: 18,
                              color: widget.isDarkMode
                                  ? Colors.white24
                                  : Colors.grey.shade300),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('d MMMM yyyy', 'tr_TR')
                                .format(DateTime.now()),
                            style: TextStyle(
                                fontSize: isDesktop ? 16 : 13,
                                color: widget.isDarkMode
                                    ? Colors.white54
                                    : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? const Color(0xFF3D1F3A).withValues(alpha: 0.8)
                            : const Color(0xFFE8C4D0).withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: widget.isDarkMode
                                ? const Color(0xFFF5B7B7).withValues(alpha: 0.3)
                                : const Color(0xFFB5627A)
                                    .withValues(alpha: 0.3),
                            width: 2),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.settings,
                            color: widget.isDarkMode
                                ? const Color(0xFFF5B7B7)
                                : const Color(0xFFB5627A),
                            size: 28),
                        onPressed: _ayarlarMenusunuAc,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFFB5627A)))
                    : IndexedStack(
                        index: _aktifSayfaIndex,
                        children: [
                          AnaDashboardSayfasi(
                            kalanSure: kalanSure,
                            siradakiVakit: siradakiVakit,
                            ilerlemeOrani: ilerlemeOrani,
                            isDark: widget.isDarkMode,
                            ozelGunMesaji: _ozelGunMesaji,
                          ),
                          VakitlerListeSayfasi(
                            bugununVakitleri: bugununVakitleri,
                            aktifVakit: siradakiVakit,
                            isDark: widget.isDarkMode,
                            ozelGunMesaji: _ozelGunMesaji,
                          ),
                          KuranWebView(isDark: widget.isDarkMode),
                          KiblePusulasi(isDark: widget.isDarkMode),
                          ZikirmatikSayfasi(isDark: widget.isDarkMode),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _aktifSayfaIndex,
        onTap: (index) => setState(() => _aktifSayfaIndex = index),
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF2D1B2E) : Colors.white,
        selectedItemColor: const Color(0xFFB5627A),
        unselectedItemColor:
            widget.isDarkMode ? Colors.white54 : Colors.black45,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.timer, size: 28), label: '🌸 Ana Sayfa'),
          BottomNavigationBarItem(
              icon: Icon(Icons.access_time_filled, size: 28),
              label: '🌷 Vakitler'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book, size: 28), label: '🌺 Kuran'),
          BottomNavigationBarItem(
              icon: Icon(Icons.compass_calibration, size: 28),
              label: '🕋 Kible'),
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome, size: 28), label: '🌸 Zikir'),
        ],
      ),
    );
  }
}

// ==================== ANA DASHBOARD ====================
class AnaDashboardSayfasi extends StatefulWidget {
  final String kalanSure, siradakiVakit;
  final double ilerlemeOrani;
  final bool isDark;
  final String? ozelGunMesaji;

  const AnaDashboardSayfasi({
    super.key,
    required this.kalanSure,
    required this.siradakiVakit,
    required this.ilerlemeOrani,
    required this.isDark,
    this.ozelGunMesaji,
  });

  @override
  State<AnaDashboardSayfasi> createState() => _AnaDashboardSayfasiState();
}

class _AnaDashboardSayfasiState extends State<AnaDashboardSayfasi> {
  late Map<String, String> bugununIcerikleri;

  @override
  void initState() {
    super.initState();
    bugununIcerikleri = GunlukIcerikServisi.getBugununIcerikleri();
    _gununAyetiniCanliCek();
  }

  Future<void> _gununAyetiniCanliCek() async {
    final canliAyet = await GunlukIcerikServisi.gununAyetiGetir();
    if (!mounted) return;
    setState(() {
      bugununIcerikleri = {...bugununIcerikleri, "ayet": canliAyet};
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final kalanSure = widget.kalanSure;
    final siradakiVakit = widget.siradakiVakit;
    final ilerlemeOrani = widget.ilerlemeOrani;
    var yaklasanOzelGun = OzelGunler.getYaklasanOzelGun();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return SingleChildScrollView(
      padding:
          EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: isDesktop ? 280 : 220,
                  height: isDesktop ? 280 : 220,
                  child: CircularProgressIndicator(
                    value: ilerlemeOrani,
                    strokeWidth: isDesktop ? 16 : 12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFB5627A)),
                    backgroundColor: isDark
                        ? Colors.white10
                        : const Color(0xFFE8C4D0).withValues(alpha: 0.3),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kalanSure,
                      style: TextStyle(
                          fontSize: isDesktop ? 42 : 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color:
                              isDark ? Colors.white : const Color(0xFFB5627A)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "🌸 Sıradaki: $siradakiVakit",
                      style: TextStyle(
                          color: const Color(0xFFB5627A),
                          fontSize: isDesktop ? 18 : 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (widget.ozelGunMesaji != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D1B2E).withValues(alpha: 0.8)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB5627A), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFE8C4D0).withValues(alpha: 0.3),
                      blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration,
                      color: Color(0xFFB5627A), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.ozelGunMesaji!,
                      style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF4A2E3B)),
                    ),
                  ),
                ],
              ),
            ),
          if (yaklasanOzelGun != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D1B2E).withValues(alpha: 0.8)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8C4D0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFE8C4D0).withValues(alpha: 0.2),
                      blurRadius: 10)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Color(0xFFB5627A)),
                      const SizedBox(width: 8),
                      Text("🌸 Yaklasan Ozel Gun",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFFB5627A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(yaklasanOzelGun['ad'],
                      style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF4A2E3B))),
                  const SizedBox(height: 4),
                  Text(
                      yaklasanOzelGun['kalanGunText'] ??
                          "${yaklasanOzelGun['kalanGun']} gun sonra 🌷",
                      style: const TextStyle(
                          color: Color(0xFFB5627A),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(yaklasanOzelGun['aciklama'],
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 13,
                          height: 1.3)),
                ],
              ),
            ),
          _buyukKarti(
              "🌷 Gunun Ayeti", bugununIcerikleri["ayet"]!, isDesktop, isDark),
          const SizedBox(height: 12),
          _buyukKarti("🌺 Gunun Hadisi", bugununIcerikleri["hadis"]!, isDesktop,
              isDark),
          const SizedBox(height: 12),
          _buyukKarti(
              "🦋 Gunun Duasi", bugununIcerikleri["dua"]!, isDesktop, isDark),
          const SizedBox(height: 12),
          _buyukKarti(
              "🌸 Gunun Esmasi", bugununIcerikleri["esma"]!, isDesktop, isDark),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "🌸 Bu uygulama AYSE NUR tarafindan annesi icin hazirlanmistir 🌸",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black45),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buyukKarti(
      String baslik, String icerik, bool isDesktop, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 20 : 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D1B2E).withValues(alpha: 0.8)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8C4D0), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFE8C4D0).withValues(alpha: 0.2),
              blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik,
              style: const TextStyle(
                  color: Color(0xFFB5627A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(icerik,
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: isDesktop ? 16 : 14,
                  height: 1.4)),
        ],
      ),
    );
  }
}

// ==================== VAKİTLER LİSTESİ ====================
class VakitlerListeSayfasi extends StatelessWidget {
  final Map<String, String> bugununVakitleri;
  final String aktifVakit;
  final bool isDark;
  final String? ozelGunMesaji;

  const VakitlerListeSayfasi({
    super.key,
    required this.bugununVakitleri,
    required this.aktifVakit,
    required this.isDark,
    this.ozelGunMesaji,
  });

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, String>> vakitler = bugununVakitleri.entries.toList();

    final Map<String, int> sirala = {
      "Imsak": 0,
      "Gunes": 1,
      "Ogle": 2,
      "Ikindi": 3,
      "Aksam": 4,
      "Yatsi": 5
    };
    vakitler.sort((a, b) {
      int indexA = sirala[a.key] ?? 99;
      int indexB = sirala[b.key] ?? 99;
      return indexA.compareTo(indexB);
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Column(
      children: [
        if (ozelGunMesaji != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D1B2E).withValues(alpha: 0.8)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB5627A), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFE8C4D0).withValues(alpha: 0.3),
                      blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration,
                      color: Color(0xFFB5627A), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(ozelGunMesaji!,
                        style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF4A2E3B))),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(isDesktop ? 40 : 20),
            itemCount: vakitler.length,
            itemBuilder: (context, index) {
              final entry = vakitler[index];
              bool isCurrent = aktifVakit.startsWith(entry.key);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 24,
                    vertical: isDesktop ? 24 : 18),
                decoration: BoxDecoration(
                  gradient: isCurrent
                      ? LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF3D1F3A),
                                  const Color(0xFF2D1B2E)
                                ]
                              : const [Color(0xFFF5E6E8), Color(0xFFE8C4D0)])
                      : null,
                  color: isCurrent
                      ? null
                      : (isDark
                          ? const Color(0xFF2D1B2E).withValues(alpha: 0.6)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isCurrent
                          ? const Color(0xFFB5627A)
                          : (isDark ? Colors.white30 : Colors.grey.shade200),
                      width: isCurrent ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFE8C4D0).withValues(alpha: 0.2),
                        blurRadius: 8)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isCurrent ? Icons.circle : Icons.circle_outlined,
                            color: isCurrent
                                ? const Color(0xFFB5627A)
                                : (isDark ? Colors.white54 : Colors.grey),
                            size: isDesktop ? 16 : 12),
                        const SizedBox(width: 12),
                        Text(entry.key,
                            style: TextStyle(
                                fontSize: isDesktop ? 24 : 20,
                                fontWeight: FontWeight.bold,
                                color: isCurrent
                                    ? const Color(0xFFB5627A)
                                    : (isDark
                                        ? Colors.white
                                        : Colors.black87))),
                      ],
                    ),
                    Text(entry.value,
                        style: TextStyle(
                            fontSize: isDesktop ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? const Color(0xFFB5627A)
                                : (isDark ? Colors.white70 : Colors.black87))),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "🌸 Bu uygulama AYSE NUR tarafindan annesi icin hazirlanmistir 🌸",
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black45),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
