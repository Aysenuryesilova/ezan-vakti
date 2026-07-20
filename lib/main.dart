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

Future<void> updateNotification(
  String remainingTime,
  String nextPrayer,
  Map<String, String> vakitler,
) async {
  if (kIsWeb) return;

  try {
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

Future<void> cancelAllScheduledNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
  debugPrint("✅ Tüm zamanlanmış bildirimler temizlendi");
}

Future<void> schedulePrayerNotifications(Map<String, String> vakitler) async {
  if (kIsWeb) return;

  await cancelAllScheduledNotifications();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

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
    });
  }

  double _yaziBoyutuOlcegi = 1.0;

  Future<void> _yaziBoyutunuKaydet(double deger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('yazi_boyutu_olcegi', deger);
    setState(() => _yaziBoyutuOlcegi = deger);
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
        fontFamily: 'Schyler',
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

// ==================== ÖZEL GÜNLER ====================
class OzelGunler {
  static final List<Map<String, dynamic>> _ozelGunler = [
    {
      'ad': '🌸 Öğretmenler Günü',
      'tarih': '2026-11-24',
      'aciklama':
          'Başöğretmen Mustafa Kemal Atatürk\'e ve tüm öğretmenlere saygı ve şükran günü.',
      'bildirim': true,
    },
    {
      'ad': '🌷 Anneler Günü',
      'tarih': '2026-05-11',
      'aciklama':
          'Annelerimize sevgi, saygı ve şükran duygularımızı ifade ettiğimiz özel gün.',
      'bildirim': true,
    },
    {
      'ad': '🍒 Malatyalılar Günü',
      'tarih': '2026-05-15',
      'aciklama':
          'Malatya\'nın düşman işgalinden kurtuluşu, gurur ve dayanışma günü.',
      'bildirim': true,
    },
    {
      'ad': '👩‍💻 Kadın Yazılımcılar Günü',
      'tarih': '2026-10-13',
      'aciklama':
          'Kadın yazılımcıların teknoloji dünyasındaki başarılarını kutladığımız özel gün.',
      'bildirim': true,
    },
    {
      'ad': '🎓 Akademisyenler Günü',
      'tarih': '2026-05-19',
      'aciklama':
          'Gençlik ve Spor Bayramı, Atatürk\'ü Anma, tüm akademisyenlerin günü.',
      'bildirim': true,
    },
    {
      'ad': '💪 Fizyoterapistler Günü',
      'tarih': '2026-09-08',
      'aciklama':
          'Fizyoterapistlerin sağlık alanındaki önemli katkılarının kutlandığı gün.',
      'bildirim': true,
    },
  ];

  static final List<Map<String, dynamic>> _diniGunlerHicri = [
    {
      'ad': '🕌 Regaib Kandili',
      'hicriGun': -1,
      'hicriAy': 7,
      'aciklama': 'Üç ayların başlangıcı, rahmet ve bereket gecesi.'
    },
    {
      'ad': '🕌 Miraç Kandili',
      'hicriGun': 27,
      'hicriAy': 7,
      'aciklama': 'Hz. Muhammed (s.a.v.)\'in göğe yükseldiği gece.'
    },
    {
      'ad': '🕌 Berat Kandili',
      'hicriGun': 15,
      'hicriAy': 8,
      'aciklama': 'Günahların affedildiği, rahmet kapılarının açıldığı gece.'
    },
    {
      'ad': '🕌 Ramazan Başlangıcı',
      'hicriGun': 1,
      'hicriAy': 9,
      'aciklama': 'Oruç ibadetinin başladığı mübarek ay.'
    },
    {
      'ad': '🕌 Kadir Gecesi',
      'hicriGun': 27,
      'hicriAy': 9,
      'aciklama': 'Kur\'an\'ın indirildiği, bin aydan hayırlı gece.'
    },
    {
      'ad': '🕌 Ramazan Bayramı',
      'hicriGun': 1,
      'hicriAy': 10,
      'aciklama':
          'Ramazan ayının sonunda oruç ibadetinin tamamlandığı, şükür ve kardeşlik bayramı.'
    },
    {
      'ad': '🕌 Kurban Bayramı',
      'hicriGun': 10,
      'hicriAy': 12,
      'aciklama': 'Hac ibadetinin sembolü, fedakarlık ve paylaşma bayramı.'
    },
    {
      'ad': '🕌 Hicri Yılbaşı',
      'hicriGun': 1,
      'hicriAy': 1,
      'aciklama': 'Hicri takvimin başlangıcı, yeni bir yıl.'
    },
    {
      'ad': '🕌 Aşure Günü',
      'hicriGun': 10,
      'hicriAy': 1,
      'aciklama': 'Birçok önemli olayın yaşandığı, paylaşma ve bereket günü.'
    },
    {
      'ad': '🕌 Mevlid Kandili',
      'hicriGun': 12,
      'hicriAy': 3,
      'aciklama': 'Hz. Muhammed (s.a.v.)\'in doğduğu mübarek gece.'
    },
  ];

  static List<Map<String, dynamic>>? _diniGunlerCache;

  static Future<void> diniGunleriHazirla() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final bugun = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final gToHYanit = await http
          .get(Uri.parse('https://api.aladhan.com/v1/gToH/$bugun'))
          .timeout(const Duration(seconds: 10));
      final hicriYilBugun =
          int.parse(jsonDecode(gToHYanit.body)['data']['hijri']['year']);

      final cacheliYil = prefs.getInt('dini_gun_cache_hicri_yil');
      final cacheliJson = prefs.getString('dini_gun_cache_json');
      if (cacheliYil == hicriYilBugun && cacheliJson != null) {
        _diniGunlerCache =
            (jsonDecode(cacheliJson) as List).cast<Map<String, dynamic>>();
        return;
      }

      final List<Map<String, dynamic>> hesaplanan = [];
      final simdi = DateTime.now();
      final bugunYalin = DateTime(simdi.year, simdi.month, simdi.day);

      for (var gun in _diniGunlerHicri) {
        try {
          DateTime? secilenTarih;
          for (final yil in [hicriYilBugun, hicriYilBugun + 1]) {
            DateTime? aday;
            if (gun['hicriGun'] == -1) {
              final birRecep = await _hToGCevir(1, gun['hicriAy'], yil);
              if (birRecep != null) {
                aday = birRecep;
                while (aday!.weekday != DateTime.friday) {
                  aday = aday.add(const Duration(days: 1));
                }
              }
            } else {
              aday = await _hToGCevir(gun['hicriGun'], gun['hicriAy'], yil);
            }
            if (aday != null &&
                !aday.isBefore(bugunYalin) &&
                (secilenTarih == null || aday.isBefore(secilenTarih))) {
              secilenTarih = aday;
            }
          }
          if (secilenTarih != null) {
            hesaplanan.add({
              'ad': gun['ad'],
              'tarih': DateFormat('yyyy-MM-dd').format(secilenTarih),
              'aciklama': gun['aciklama'],
              'bildirim': false,
            });
          }
        } catch (e) {
          debugPrint("❌ ${gun['ad']} hesaplanamadı: $e");
        }
      }

      _diniGunlerCache = hesaplanan;
      await prefs.setInt('dini_gun_cache_hicri_yil', hicriYilBugun);
      await prefs.setString('dini_gun_cache_json', jsonEncode(hesaplanan));
      debugPrint(
          "✅ Dini günler Hicri ${hicriYilBugun}/${hicriYilBugun + 1} için hesaplandı");
    } catch (e) {
      debugPrint("❌ Dini günler hazırlanamadı (internet yok olabilir): $e");
      final cacheliJson = prefs.getString('dini_gun_cache_json');
      if (cacheliJson != null) {
        _diniGunlerCache =
            (jsonDecode(cacheliJson) as List).cast<Map<String, dynamic>>();
      } else {
        _diniGunlerCache = [];
      }
    }
  }

  static Future<DateTime?> _hToGCevir(int gun, int ay, int yil) async {
    final hicriTarih =
        '${gun.toString().padLeft(2, '0')}-${ay.toString().padLeft(2, '0')}-$yil';
    final yanit = await http
        .get(Uri.parse('https://api.aladhan.com/v1/hToG/$hicriTarih'))
        .timeout(const Duration(seconds: 10));
    if (yanit.statusCode != 200) return null;
    final g = jsonDecode(yanit.body)['data']['gregorian'];
    return DateTime(
      int.parse(g['year']),
      int.parse(g['month']['number'].toString()),
      int.parse(g['day']),
    );
  }

  static List<Map<String, dynamic>> get _diniGunler => _diniGunlerCache ?? [];

  static final List<Map<String, dynamic>> _milliGunler = [
    {
      'ad': '🇹🇷 İstiklal Marşı\'nın Kabulü ve Mehmet Akif Ersoy\'u Anma Günü',
      'tarih': '2026-03-12',
      'aciklama':
          'İstiklal Marşı\'nın TBMM tarafından kabul edildiği gün ve şairi Mehmet Akif Ersoy\'u anma günü.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Çanakkale Zaferi ve Şehitleri Anma Günü',
      'tarih': '2026-03-18',
      'aciklama':
          'Çanakkale deniz zaferi ve bu uğurda şehit düşenleri anma günü.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Ulusal Egemenlik ve Çocuk Bayramı',
      'tarih': '2026-04-23',
      'aciklama':
          'Türkiye Büyük Millet Meclisi\'nin açılışı ve çocuklara armağan edilen bayram.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Emek ve Dayanışma Günü',
      'tarih': '2026-05-01',
      'aciklama': 'İşçi hakları ve emeğin değerine dikkat çekilen gün.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Atatürk\'ü Anma ve Gençlik ve Spor Bayramı',
      'tarih': '2026-05-19',
      'aciklama':
          'Mustafa Kemal Atatürk\'ün Samsun\'a çıkışı ve gençliğe armağanı.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Demokrasi ve Milli Birlik Günü',
      'tarih': '2026-07-15',
      'aciklama':
          '15 Temmuz darbe girişimine karşı milletin demokrasi ve bağımsızlık mücadelesi.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Zafer Bayramı',
      'tarih': '2026-08-30',
      'aciklama':
          'Büyük Taarruz\'un zaferle sonuçlanması, Türk ordusunun kahramanlığı.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Gaziler Günü',
      'tarih': '2026-09-19',
      'aciklama': 'Gazilerimizi minnet ve şükranla anıyoruz.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Cumhuriyet Bayramı',
      'tarih': '2026-10-29',
      'aciklama':
          'Türkiye Cumhuriyeti\'nin ilanı, bağımsızlık ve çağdaşlaşma bayramı.',
      'bildirim': false
    },
    {
      'ad': '🇹🇷 Atatürk\'ü Anma Günü',
      'tarih': '2026-11-10',
      'aciklama':
          'Büyük Önder Mustafa Kemal Atatürk\'ü vefatının yıldönümünde saygıyla anma günü.',
      'bildirim': false
    },
  ];

  static final List<Map<String, dynamic>> _digerOzelGunler = [
    {
      'ad': '🌍 Dünya Kadınlar Günü',
      'tarih': '2026-03-08',
      'aciklama': 'Kadın hakları ve eşitlik mücadelesinin simgesi.',
      'bildirim': false
    },
    {
      'ad': '🌳 Dünya Orman Günü',
      'tarih': '2026-03-21',
      'aciklama': 'Ormanların önemine dikkat çeken uluslararası gün.',
      'bildirim': false
    },
    {
      'ad': '💧 Dünya Su Günü',
      'tarih': '2026-03-22',
      'aciklama': 'Temiz suya erişimin önemine dikkat çekilen gün.',
      'bildirim': false
    },
    {
      'ad': '🩺 Dünya Sağlık Günü',
      'tarih': '2026-04-07',
      'aciklama': 'Halk sağlığının önemine dikkat çekilen gün.',
      'bildirim': false
    },
    {
      'ad': '📚 Dünya Kitap Günü',
      'tarih': '2026-04-23',
      'aciklama':
          'Kitap okumanın ve telif haklarının önemine dikkat çeken gün.',
      'bildirim': false
    },
    {
      'ad': '🌏 Dünya Çevre Günü',
      'tarih': '2026-06-05',
      'aciklama': 'Çevre bilincini artırmak için kutlanan uluslararası gün.',
      'bildirim': false
    },
    {
      'ad': '👨‍👩‍👧 Dünya Nüfus Günü',
      'tarih': '2026-07-11',
      'aciklama': 'Nüfus meselelerine dikkat çeken uluslararası gün.',
      'bildirim': false
    },
    {
      'ad': '🕊️ Dünya Barış Günü',
      'tarih': '2026-09-21',
      'aciklama': 'Dünya barışı için umut ve birlik mesajı.',
      'bildirim': false
    },
    {
      'ad': '👴 Dünya Yaşlılar Günü',
      'tarih': '2026-10-01',
      'aciklama': 'Yaşlı bireylere saygı ve destek günü.',
      'bildirim': false
    },
    {
      'ad': '👩‍🏫 Dünya Öğretmenler Günü',
      'tarih': '2026-10-05',
      'aciklama':
          'UNESCO tarafından ilan edilen, öğretmenlerin katkılarını kutlayan gün.',
      'bildirim': false
    },
    {
      'ad': '🍎 Dünya Gıda Günü',
      'tarih': '2026-10-16',
      'aciklama': 'Açlıkla mücadele ve gıda güvenliğine dikkat çeken gün.',
      'bildirim': false
    },
    {
      'ad': '💪 Dünya Engelliler Günü',
      'tarih': '2026-12-03',
      'aciklama':
          'Engelli bireylerin haklarına dikkat çekmek için birleşiyoruz.',
      'bildirim': false
    },
    {
      'ad': '🌍 Dünya Çocuk Hakları Günü',
      'tarih': '2026-11-20',
      'aciklama':
          'Çocuk haklarının korunması ve geliştirilmesi için farkındalık günü.',
      'bildirim': false
    },
    {
      'ad': '🕯️ İnsan Hakları Günü',
      'tarih': '2026-12-10',
      'aciklama': 'İnsan haklarının evrenselliğine vurgu yapıyoruz.',
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
          'kalanGunText': '🌸 BUGÜN 🌸',
          'aciklama': gun['aciklama'],
          'tarih': gun['tarih'],
          'bildirim': gun['bildirim'] ?? false,
        };
      } else if (kalanGun > 0) {
        return {
          'ad': gun['ad'],
          'kalanGun': kalanGun,
          'kalanGunText': '$kalanGun gün sonra 🌷',
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

// ==================== GÜNLÜK İÇERİK SERVİSİ ====================
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
    "Şüphesiz güçlükle beraber bir kolaylık vardır. (İnşirah, 5)",
    "Eğer şükrederseniz, elbette size nimetimi artırırım. (İbrahim, 7)",
    "Ben Rabbime tevekkül ettim. (Hud, 56)",
    "Allah kuluna kâfi değil midir? (Zümer, 36)",
    "Rabbimiz! Bize katından bir rahmet ver. (Kehf, 10)",
    "Allah, adaleti, iyiliği ve akrabaya yardımı emreder. (Nahl, 90)",
    "Kim zerre kadar iyilik yaparsa onu görür. (Zilzal, 7)",
    "Kim zerre kadar kötülük yaparsa onu görür. (Zilzal, 8)",
    "De ki: 'O Allah birdir.' (İhlas, 1)",
  ];

  static const int _nawawiHadisSayisi = 42;

  static Future<String> gununHadisiGetir() async {
    final yilinGunu = _getYilinGunu();
    final hadisNo = (yilinGunu % _nawawiHadisSayisi) + 1;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gunun_hadisi_$yilinGunu';

    final cached = prefs.getString(cacheKey);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/tur-nawawi/$hadisNo.json',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hadisler = data['hadiths'] as List;
        if (hadisler.isNotEmpty) {
          final metin = (hadisler[0]['text'] as String).trim();
          final sonuc = "$metin\n(Nevevi'nin Kırk Hadis'i, Hadis $hadisNo)";
          await prefs.setString(cacheKey, sonuc);
          return sonuc;
        }
      }
    } catch (_) {}
    return hadisler[yilinGunu % hadisler.length];
  }

  static const List<List<int>> gununDuasiReferanslari = [
    [2, 201],
    [2, 286],
    [3, 8],
    [3, 147],
    [3, 193],
    [7, 23],
    [14, 40],
    [14, 41],
    [20, 25],
    [21, 87],
    [21, 89],
    [23, 118],
    [25, 74],
    [28, 24],
    [59, 10],
  ];

  static const List<String> dualarYedek = [
    "Rabbenâ âtinâ fid-dünyâ haseneten ve fi'l-âhirati haseneten ve kınâ azâben-nâr. (Bakara, 201)",
    "Rabbenâ lâ tuâhiznâ in nesînâ ev ahta'nâ. (Bakara, 286)",
    "Rabbenâğfirlî ve li vâlideyye. (İbrahim, 41)",
    "Rabbi zidnî ilmâ. (Tâhâ, 114)",
    "Hasbunallâhu ve ni'mel vekîl. (Âl-i İmrân, 173)",
    "Rabbi'şrahlî sadrî ve yessirlî emrî. (Tâhâ, 25-26)",
    "Rabbenâ heb lenâ min ezvâcinâ ve zurriyyâtinâ kurrete a'yun. (Furkan, 74)",
  ];

  static const List<String> hadisler = [
    "Namaz, dinin direğidir. (Tirmizî)",
    "Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz. (Buhârî)",
    "Ameller niyetlere göredir. (Buhârî)",
    "Müslüman, Müslümanın kardeşidir. (Müslim)",
    "Sizin en hayırlınız, ahlakı en güzel olanınızdır. (Buhârî)",
    "Veren el, alan elden hayırlıdır. (Buhârî, Müslim)",
    "Sizden biriniz, kendisi için istediği kardeşi için de istemedikçe gerçek anlamda iman etmiş olmaz. (Buhârî, Müslim)",
    "Gülümseyen bile senin için bir sadakadır. (Tirmizî)",
    "Allah güzeldir, güzelliği sever. (Müslim)",
    "İyilik, güzel ahlaktır. (Müslim)",
  ];

  static const List<String> dualar = [
    "Rabbim! Bana ve aileme hayırlı evlat ver.",
    "Allah'ım! Kalbimi dinin üzere sabit kıl.",
    "Rabbenâ âtinâ fid-dünyâ haseneten ve fi'l-âhirati haseneten ve kınâ azâben-nâr. (Bakara, 201)",
    "Rabbi zidnî ilma. (Tâhâ, 114)",
    "Allah'ım! Beni senden uzaklaştıracak her şeyden koru.",
    "Rabbenâğfirli ve li vâlideyye. (İbrahim, 41)",
    "Hasbunallâhu ve ni'mel vekîl. (Âl-i İmrân, 173)",
  ];

  static const List<String> esmalar = [
    "Er-Rahmân (Dünyada her canlıya merhamet eden)",
    "Er-Rahîm (Ahirette sadece müminlere merhamet eden)",
    "El-Melik (Mülkün, evrenin mutlak sahibi)",
    "El-Kuddûs (Her türlü eksiklikten uzak olan)",
    "Es-Selâm (Kullarını selamete çıkaran)",
  ];

  static Future<String> gununDuasiGetir() async {
    final yilinGunu = _getYilinGunu();
    final ref =
        gununDuasiReferanslari[yilinGunu % gununDuasiReferanslari.length];
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gunun_duasi_$yilinGunu';

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
    return dualarYedek[yilinGunu % dualarYedek.length];
  }

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
    "Âl-i İmrân",
    "Nisâ",
    "Mâide",
    "En'âm",
    "A'râf",
    "Enfâl",
    "Tevbe",
    "Yûnus",
    "Hûd",
    "Yûsuf",
    "Ra'd",
    "İbrâhîm",
    "Hicr",
    "Nahl",
    "İsrâ",
    "Kehf",
    "Meryem",
    "Tâhâ",
    "Enbiyâ",
    "Hac",
    "Mü'minûn",
    "Nûr",
    "Furkân",
    "Şu'arâ",
    "Neml",
    "Kasas",
    "Ankebût",
    "Rûm",
    "Lokmân",
    "Secde",
    "Ahzâb",
    "Sebe'",
    "Fâtır",
    "Yâsîn",
    "Sâffât",
    "Sâd",
    "Zümer",
    "Mü'min",
    "Fussilet",
    "Şûrâ",
    "Zuhruf",
    "Duhân",
    "Câsiye",
    "Ahkâf",
    "Muhammed",
    "Fetih",
    "Hucurât",
    "Kâf",
    "Zâriyât",
    "Tûr",
    "Necm",
    "Kamer",
    "Rahmân",
    "Vâkıa",
    "Hadîd",
    "Mücâdele",
    "Haşr",
    "Mümtehine",
    "Saf",
    "Cuma",
    "Münâfikûn",
    "Teğâbün",
    "Talâk",
    "Tahrîm",
    "Mülk",
    "Kalem",
    "Hâkka",
    "Meâric",
    "Nûh",
    "Cin",
    "Müzzemmil",
    "Müddessir",
    "Kıyâme",
    "İnsân",
    "Mürselât",
    "Nebe",
    "Nâziât",
    "Abese",
    "Tekvîr",
    "İnfitâr",
    "Mutaffifîn",
    "İnşikâk",
    "Burûc",
    "Târık",
    "A'lâ",
    "Gâşiye",
    "Fecr",
    "Beled",
    "Şems",
    "Leyl",
    "Duhâ",
    "İnşirâh",
    "Tîn",
    "Alak",
    "Kadr",
    "Beyyine",
    "Zilzâl",
    "Âdiyât",
    "Kâria",
    "Tekâsür",
    "Asr",
    "Hümeze",
    "Fîl",
    "Kureyş",
    "Mâûn",
    "Kevser",
    "Kâfirûn",
    "Nasr",
    "Tebbet",
    "İhlâs",
    "Felak",
    "Nâs"
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
      throw Exception("Kur'an verisi alınamadı (kod: ${response.statusCode})");
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
              "🌺 Kuran sayfası yüklenirken hata oluştu.\nİnternet bağlantınızı kontrol edin.",
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
        AltBilgiMetni(isDark: widget.isDark),
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
    "Estağfirullah",
  ];
  int _seciliZikirIndex = 0;
  String _yeniZikir = "";
  int _yeniZikirHedefi = 33;
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
                Text("🌸 ${_zikirler[_seciliZikirIndex]} zikri tamamlandı!"),
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
                          label: const Text("Sıfırla"),
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

// ==================== KIBLE PUSULASI ====================
class KiblePusulasi extends StatefulWidget {
  final bool isDark;

  const KiblePusulasi({super.key, required this.isDark});

  @override
  State<KiblePusulasi> createState() => _KiblePusulasiState();
}

class _KiblePusulasiState extends State<KiblePusulasi> {
  double _heading = 0.0;
  bool _pusulaVar = true;

  final Map<String, List<double>> _ilKoordinat = {
    "Adana": [37.0, 35.3213333],
    "Adıyaman": [37.7641667, 38.2761667],
    "Afyonkarahisar": [38.76376, 30.54034],
    "Ağrı": [39.7216667, 43.0566667],
    "Amasya": [40.65, 35.8333333],
    "Ankara": [39.92077, 32.85411],
    "Antalya": [36.88414, 30.70563],
    "Artvin": [41.1833333, 41.8166667],
    "Aydın": [37.8444, 27.8458],
    "Balıkesir": [39.648369, 27.8826100],
    "Bilecik": [40.150131, 29.983061],
    "Bingöl": [38.8853490, 40.4982910],
    "Bitlis": [38.4, 42.1166667],
    "Bolu": [40.7394790, 31.6115610],
    "Burdur": [37.7269090, 30.2888760],
    "Bursa": [40.18257, 29.06687],
    "Çanakkale": [40.1553120, 26.4141600],
    "Çankırı": [40.6, 33.6166667],
    "Çorum": [40.5505556, 34.9555556],
    "Denizli": [37.77652, 29.08639],
    "Diyarbakır": [37.91441, 40.2306290],
    "Edirne": [41.6666667, 26.5666667],
    "Elazığ": [38.680969, 39.226398],
    "Erzincan": [39.75, 39.5],
    "Erzurum": [39.9043189, 41.2678853],
    "Eskişehir": [39.784302, 30.51922],
    "Gaziantep": [37.06622, 37.38332],
    "Giresun": [40.912811, 38.38953],
    "Gümüşhane": [40.4602778, 39.4813889],
    "Hakkari": [37.5833333, 43.7333333],
    "Hatay": [36.4018488, 36.3498097],
    "Isparta": [37.7666667, 30.55],
    "Mersin": [36.8, 34.6333333],
    "İstanbul": [41.00527, 28.97696],
    "İzmir": [38.41885, 27.12872],
    "Kars": [40.59267, 43.077831],
    "Kastamonu": [41.38871, 33.78273],
    "Kayseri": [38.7333333, 35.4833333],
    "Kırklareli": [41.7333333, 27.2166667],
    "Kırşehir": [39.15, 34.1666667],
    "Kocaeli": [40.8532704, 29.8815203],
    "Konya": [37.8666667, 32.4833333],
    "Kütahya": [39.4166667, 29.9833333],
    "Malatya": [38.35519, 38.30946],
    "Manisa": [38.619099, 27.428921],
    "Kahramanmaraş": [37.5833333, 36.9333333],
    "Mardin": [37.3122361, 40.7351120],
    "Muğla": [37.2152778, 28.3636111],
    "Muş": [38.7432926, 41.5064823],
    "Nevşehir": [38.62442, 34.723969],
    "Niğde": [37.9666667, 34.6833333],
    "Ordu": [40.9833333, 37.8833333],
    "Rize": [41.02005, 40.523449],
    "Sakarya": [40.7568793, 30.378138],
    "Samsun": [41.292782, 36.33128],
    "Siirt": [37.94429, 41.93288],
    "Sinop": [42.0264222, 35.1550745],
    "Sivas": [39.747662, 37.017879],
    "Tekirdağ": [40.9833333, 27.5166667],
    "Tokat": [40.3166667, 36.55],
    "Trabzon": [41.0, 39.7333333],
    "Tunceli": [39.1079868, 39.5401672],
    "Şanlıurfa": [37.15, 38.8],
    "Uşak": [38.682301, 29.40819],
    "Van": [38.4941667, 43.38],
    "Yozgat": [39.82, 34.8044444],
    "Zonguldak": [41.456409, 31.798731],
    "Aksaray": [38.36869, 34.03698],
    "Bayburt": [40.255169, 40.22488],
    "Karaman": [37.17593, 33.228748],
    "Kırıkkale": [39.846821, 33.515251],
    "Batman": [37.881168, 41.13509],
    "Şırnak": [37.5163889, 42.4611111],
    "Bartın": [41.6344444, 32.3375],
    "Ardahan": [41.110481, 42.702171],
    "Iğdır": [39.9166667, 44.0333333],
    "Yalova": [40.65, 29.2666667],
    "Karabük": [41.2, 32.6333333],
    "Kilis": [36.718399, 37.12122],
    "Osmaniye": [37.06805, 36.261589],
    "Düzce": [40.843849, 31.15654],
  };

  static const double _kabeLat = 21.4225;
  static const double _kabeLon = 39.8262;

  double _kibleAcisi = 154.0;
  String? _manuelIl;
  String _kayitliSehir = "Muş";

  // 3 Farklı Kıble Kaynağı
  Map<String, double> _kibleAcilar = {
    'Aladhan': 0.0,
    'Math': 0.0,
    'Geo': 0.0,
  };
  String _seciliKaynak = "Aladhan";

  final List<Map<String, dynamic>> _kibleKaynaklari = [
    {
      'id': 'Aladhan',
      'ad': '🌙 Aladhan',
      'aciklama': 'Uluslararası İslami API',
      'yildiz': 5
    },
    {
      'id': 'Math',
      'ad': '📐 Matematiksel',
      'aciklama': 'Büyük daire formülü',
      'yildiz': 4
    },
    {
      'id': 'Geo',
      'ad': '🌍 Coğrafi',
      'aciklama': 'Haversine formülü',
      'yildiz': 4
    },
  ];

  String _konumKaynagi = "kayitli";
  int? _gpsDogrulukYildizi;
  bool _gpsYukleniyor = false;
  String? _gpsHata;

  Stream<dynamic>? _compassStream;

  @override
  void initState() {
    super.initState();
    _pusulaKontrol();
    _konumBilgisiniYukle();
  }

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

  double _geoHesapla(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final x = math.sin(dLon) * math.cos(lat2Rad);
    final y = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    return (math.atan2(x, y) * 180 / math.pi + 360) % 360;
  }

  Future<void> _tumKibleAcilariniHesapla(double lat, double lon) async {
    try {
      final yanit = await http
          .get(Uri.parse('https://api.aladhan.com/v1/qibla/$lat/$lon'));
      final veri = jsonDecode(yanit.body);
      _kibleAcilar['Aladhan'] = (veri['data']['direction'] as num).toDouble();
    } catch (_) {
      _kibleAcilar['Aladhan'] = _bearingHesapla(lat, lon, _kabeLat, _kabeLon);
    }
    _kibleAcilar['Math'] = _bearingHesapla(lat, lon, _kabeLat, _kabeLon);
    _kibleAcilar['Geo'] = _geoHesapla(lat, lon, _kabeLat, _kabeLon);
    setState(() {});
  }

  Future<void> _gpsIleKibleBul() async {
    setState(() {
      _gpsYukleniyor = true;
      _gpsHata = null;
    });
    try {
      final servisAcik = await Geolocator.isLocationServiceEnabled();
      if (!servisAcik) {
        setState(() {
          _gpsHata =
              "Konum servisleri kapalı. Lütfen telefon ayarlarından açın.";
          _gpsYukleniyor = false;
        });
        return;
      }

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

      final konum = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _tumKibleAcilariniHesapla(konum.latitude, konum.longitude);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kible_manuel_il');

      setState(() {
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

  int _dogrulukYildizHesapla(double metreDogruluk) {
    if (metreDogruluk <= 10) return 5;
    if (metreDogruluk <= 25) return 4;
    if (metreDogruluk <= 50) return 3;
    if (metreDogruluk <= 100) return 2;
    return 1;
  }

  void _kibleAcisiniGuncelle(String il) {
    final koordinat = _ilKoordinat[il];
    if (koordinat == null) return;
    _tumKibleAcilariniHesapla(koordinat[0], koordinat[1]);
  }

  Future<void> _konumBilgisiniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final kayitli = prefs.getString('secilen_sehir') ?? "Muş";
    final manuel = prefs.getString('kible_manuel_il');
    setState(() {
      _kayitliSehir = _ilKoordinat.containsKey(kayitli) ? kayitli : "Muş";
      _manuelIl =
          (manuel != null && _ilKoordinat.containsKey(manuel)) ? manuel : null;
    });
    _kibleAcisiniGuncelle(_manuelIl ?? _kayitliSehir);
  }

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

  void _kaynakDegistir(String kaynakId) {
    setState(() {
      _seciliKaynak = kaynakId;
    });
  }

  Widget _yildizGoster(int sayi) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < sayi ? Icons.star : Icons.star_border,
          size: 14,
          color: const Color(0xFFB5627A),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secilenKaynak = _kibleKaynaklari.firstWhere(
      (k) => k['id'] == _seciliKaynak,
      orElse: () => _kibleKaynaklari[0],
    );
    final gosterilecekAci = _kibleAcilar[_seciliKaynak] ?? 0.0;

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
                      "🕋 Kıble Pusulası",
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
                            title: const Text("🕋 Kıble Pusulası"),
                            content: const Text(
                              "📱 Telefonu düz tutun ve etrafında dönün.\n"
                              "🌹 Pembe ok Kıble yönünü gösterir.\n"
                              "📍 Kırmızı ok Kuzey yönünü gösterir.\n\n"
                              "🔢 3 farklı kaynaktan Kıble açısı hesaplanır.\n"
                              "⭐ Yıldız sayısı kaynağın güvenilirliğini gösterir.",
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
                                  ? "📍 GPS (canlı)"
                                  : "📍 ${_manuelIl ?? _kayitliSehir}${_konumKaynagi == 'manuel' ? ' (manuel)' : ' (kayıtlı)'}",
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
                            _yildizGoster(_gpsDogrulukYildizi!),
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
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _gpsYukleniyor ? null : _gpsIleKibleBul,
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
                                  : "📍 GPS ile Bul"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB5627A),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        ],
                      ),
                      if (_konumKaynagi != "kayitli")
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: _kayitliKonumuKullan,
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text("Kayıtlı konuma dön"),
                            style: TextButton.styleFrom(
                              foregroundColor: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF2D1B2E).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFE8C4D0).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _kibleKaynaklari.map((kaynak) {
                      final secili = _seciliKaynak == kaynak['id'];
                      return GestureDetector(
                        onTap: () => _kaynakDegistir(kaynak['id']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: secili
                                ? const Color(0xFFB5627A).withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: secili
                                  ? const Color(0xFFB5627A)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                kaynak['ad'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: secili
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: secili
                                      ? const Color(0xFFB5627A)
                                      : (widget.isDark
                                          ? Colors.white54
                                          : Colors.black54),
                                ),
                              ),
                              if (secili) _yildizGoster(kaynak['yildiz']),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!_pusulaVar)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sensor_occupied,
                          size: 60,
                          color:
                              widget.isDark ? Colors.white54 : Colors.black54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Pusula sensörü bulunamadı.\nTelefonunuz pusula desteği sunmuyor olabilir.",
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
                                  angle: -_heading * math.pi / 180,
                                  child: Container(
                                    width: 220,
                                    height: 220,
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
                                          height: 90,
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
                                          height: 90,
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
                                          angle: 90 * math.pi / 180,
                                          child: Container(
                                            width: 2,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                            alignment: Alignment.bottomCenter,
                                            child: const Text(
                                              "D",
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Transform.rotate(
                                          angle: -90 * math.pi / 180,
                                          child: Container(
                                            width: 2,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                            alignment: Alignment.bottomCenter,
                                            child: const Text(
                                              "B",
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Transform.rotate(
                                          angle:
                                              gosterilecekAci * math.pi / 180,
                                          child: Container(
                                            width: 2,
                                            height: 100,
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
                            const SizedBox(height: 16),
                            Text(
                              "Kıble Açısı: ${gosterilecekAci.toStringAsFixed(1)}°",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.white
                                    : const Color(0xFF4A2E3B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Kaynak: ${secilenKaynak['ad']} ${secilenKaynak['aciklama']}",
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? Colors.white54
                                    : Colors.black45,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: _kibleKaynaklari
                                  .where((k) => k['id'] != _seciliKaynak)
                                  .map((k) {
                                final aci = _kibleAcilar[k['id']] ?? 0.0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.isDark
                                        ? Colors.white10
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${k['ad']}: ${aci.toStringAsFixed(1)}°",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: widget.isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "🌸 Pembe ok Kıble'yi gösterir",
                              style: TextStyle(
                                fontSize: 13,
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
              AltBilgiMetni(isDark: widget.isDark),
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

  const AnaSayfaGezgini({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.bildirimIzniKaliciRed,
    required this.yaziBoyutuOlcegi,
    required this.onYaziBoyutuChanged,
  });

  @override
  State<AnaSayfaGezgini> createState() => _AnaSayfaGezginiState();
}

class _AnaSayfaGezginiState extends State<AnaSayfaGezgini> {
  int _aktifSayfaIndex = 0;
  String secilenSehir = "Seçilmedi";
  String secilenIlce = "Seçilmedi";
  bool isLoading = false;
  List<dynamic> aylikVeriHavuzu = [];

  final Map<String, List<String>> _ilIlceMap = {
    "Adana": [
      "Aladağ",
      "Ceyhan",
      "Çukurova",
      "Feke",
      "İmamoğlu",
      "Karaisalı",
      "Karataş",
      "Kozan",
      "Pozantı",
      "Saimbeyli",
      "Sarıçam",
      "Seyhan",
      "Tufanbeyli",
      "Yumurtalık",
      "Yüreğir"
    ],
    "Adıyaman": [
      "Merkez",
      "Besni",
      "Çelikhan",
      "Gerger",
      "Gölbaşı",
      "Kahta",
      "Samsat",
      "Sincik",
      "Tut"
    ],
    "Afyonkarahisar": [
      "Merkez",
      "Başmakçı",
      "Bayat",
      "Bolvadin",
      "Çay",
      "Çobanlar",
      "Dazkırı",
      "Dinar",
      "Emirdağ",
      "Evciler",
      "Hocalar",
      "İhsaniye",
      "İscehisar",
      "Kızılören",
      "Sandıklı",
      "Sinanpaşa",
      "Şuhut",
      "Sultandağı"
    ],
    "Ağrı": [
      "Merkez",
      "Diyadin",
      "Doğubayazıt",
      "Eleşkirt",
      "Hamur",
      "Patnos",
      "Taşlıçay",
      "Tutak"
    ],
    "Amasya": [
      "Merkez",
      "Göynücek",
      "Gümüşhacıköy",
      "Hamamözü",
      "Merzifon",
      "Suluova",
      "Taşova"
    ],
    "Ankara": [
      "Akyurt",
      "Altındağ",
      "Ayaş",
      "Bala",
      "Beypazarı",
      "Çamlıdere",
      "Çankaya",
      "Çubuk",
      "Elmadağ",
      "Etimesgut",
      "Evren",
      "Gölbaşı",
      "Güdül",
      "Haymana",
      "Kahramankazan",
      "Kalecik",
      "Keçiören",
      "Kızılcahamam",
      "Mamak",
      "Nallıhan",
      "Polatlı",
      "Pursaklar",
      "Şereflikoçhisar",
      "Sincan",
      "Yenimahalle"
    ],
    "Antalya": [
      "Akseki",
      "Aksu",
      "Alanya",
      "Demre",
      "Döşemealtı",
      "Elmalı",
      "Finike",
      "Gazipaşa",
      "Gündoğmuş",
      "İbradı",
      "Kaş",
      "Kemer",
      "Kepez",
      "Konyaaltı",
      "Korkuteli",
      "Kumluca",
      "Manavgat",
      "Muratpaşa",
      "Serik"
    ],
    "Artvin": [
      "Merkez",
      "Ardanuç",
      "Arhavi",
      "Borçka",
      "Hopa",
      "Kemalpaşa",
      "Murgul",
      "Şavşat",
      "Yusufeli"
    ],
    "Aydın": [
      "Bozdoğan",
      "Buharkent",
      "Çine",
      "Didim",
      "Efeler",
      "Germencik",
      "İncirliova",
      "Karacasu",
      "Karpuzlu",
      "Koçarlı",
      "Köşk",
      "Kuşadası",
      "Kuyucak",
      "Nazilli",
      "Söke",
      "Sultanhisar",
      "Yenipazar"
    ],
    "Balıkesir": [
      "Altıeylül",
      "Ayvalık",
      "Balya",
      "Bandırma",
      "Bigadiç",
      "Burhaniye",
      "Dursunbey",
      "Edremit",
      "Erdek",
      "Gömeç",
      "Gönen",
      "Havran",
      "İvrindi",
      "Karesi",
      "Kepsut",
      "Manyas",
      "Marmara",
      "Savaştepe",
      "Sındırgı",
      "Susurluk"
    ],
    "Bilecik": [
      "Merkez",
      "Bozüyük",
      "Gölpazarı",
      "İnhisar",
      "Osmaneli",
      "Pazaryeri",
      "Söğüt",
      "Yenipazar"
    ],
    "Bingöl": [
      "Merkez",
      "Adaklı",
      "Genç",
      "Karlıova",
      "Kiğı",
      "Solhan",
      "Yayladere",
      "Yedisu"
    ],
    "Bitlis": [
      "Merkez",
      "Adilcevaz",
      "Ahlat",
      "Güroymak",
      "Hizan",
      "Mutki",
      "Tatvan"
    ],
    "Bolu": [
      "Merkez",
      "Dörtdivan",
      "Gerede",
      "Göynük",
      "Kıbrıscık",
      "Mengen",
      "Mudurnu",
      "Seben",
      "Yeniçağa"
    ],
    "Burdur": [
      "Merkez",
      "Ağlasun",
      "Altınyayla",
      "Bucak",
      "Çavdır",
      "Çeltikçi",
      "Gölhisar",
      "Karamanlı",
      "Kemer",
      "Tefenni",
      "Yeşilova"
    ],
    "Bursa": [
      "Büyükorhan",
      "Gemlik",
      "Gürsu",
      "Harmancık",
      "İnegöl",
      "İznik",
      "Karacabey",
      "Keles",
      "Kestel",
      "Mudanya",
      "Mustafakemalpaşa",
      "Nilüfer",
      "Orhaneli",
      "Orhangazi",
      "Osmangazi",
      "Yenişehir",
      "Yıldırım"
    ],
    "Çanakkale": [
      "Merkez",
      "Ayvacık",
      "Bayramiç",
      "Biga",
      "Bozcaada",
      "Çan",
      "Eceabat",
      "Ezine",
      "Gelibolu",
      "Gökçeada",
      "Lapseki",
      "Yenice"
    ],
    "Çankırı": [
      "Merkez",
      "Atkaracalar",
      "Bayramören",
      "Çerkeş",
      "Eldivan",
      "Ilgaz",
      "Kızılırmak",
      "Korgun",
      "Kurşunlu",
      "Orta",
      "Şabanözü",
      "Yapraklı"
    ],
    "Çorum": [
      "Merkez",
      "Alaca",
      "Bayat",
      "Boğazkale",
      "Dodurga",
      "İskilip",
      "Kargı",
      "Laçin",
      "Mecitözü",
      "Oğuzlar",
      "Ortaköy",
      "Osmancık",
      "Sungurlu",
      "Uğurludağ"
    ],
    "Denizli": [
      "Acıpayam",
      "Babadag",
      "Baklan",
      "Bekilli",
      "Beyağaç",
      "Bozkurt",
      "Buldan",
      "Çal",
      "Çameli",
      "Çardak",
      "Çivril",
      "Güney",
      "Honaz",
      "Kale",
      "Merkezefendi",
      "Pamukkale",
      "Sarayköy",
      "Serinhisar",
      "Tavas"
    ],
    "Diyarbakır": [
      "Bağlar",
      "Bismil",
      "Çermik",
      "Çınar",
      "Çüngüş",
      "Dicle",
      "Eğil",
      "Ergani",
      "Hani",
      "Hazro",
      "Kayapınar",
      "Kocaköy",
      "Kulp",
      "Lice",
      "Silvan",
      "Sur",
      "Yenişehir"
    ],
    "Edirne": [
      "Merkez",
      "Enez",
      "Havsa",
      "İpsala",
      "Keşan",
      "Lalapaşa",
      "Meriç",
      "Süloğlu",
      "Uzunköprü"
    ],
    "Elazığ": [
      "Merkez",
      "Ağın",
      "Alacakaya",
      "Arıcak",
      "Baskil",
      "Karakocan",
      "Keban",
      "Kovancılar",
      "Maden",
      "Palu",
      "Sivrice"
    ],
    "Erzincan": [
      "Merkez",
      "Çayırlı",
      "İliç",
      "Kemah",
      "Kemaliye",
      "Otlukbeli",
      "Refahiye",
      "Tercan",
      "Üzümlü"
    ],
    "Erzurum": [
      "Aşkale",
      "Aziziye",
      "Çat",
      "Hınıs",
      "Horasan",
      "İspir",
      "Karaçoban",
      "Karayazı",
      "Köprüköy",
      "Narman",
      "Oltu",
      "Olur",
      "Palandöken",
      "Pasinler",
      "Pazaryolu",
      "Şenkaya",
      "Tekman",
      "Tortum",
      "Uzundere",
      "Yakutiye"
    ],
    "Eskişehir": [
      "Alpu",
      "Beylikova",
      "Çifteler",
      "Günyüzü",
      "Han",
      "İnönü",
      "Mahmudiye",
      "Mihalgazi",
      "Mihalıççık",
      "Odunpazarı",
      "Sarıcakaya",
      "Seyitgazi",
      "Sivrihisar",
      "Tepebaşı"
    ],
    "Gaziantep": [
      "Araban",
      "İslahiye",
      "Karkamış",
      "Nizip",
      "Nurdağı",
      "Oğuzeli",
      "Şahinbey",
      "Şehitkamil",
      "Yavuzeli"
    ],
    "Giresun": [
      "Merkez",
      "Alucra",
      "Bulancak",
      "Çamoluk",
      "Çanakçı",
      "Dereli",
      "Doğankent",
      "Espiye",
      "Eynesil",
      "Görele",
      "Güce",
      "Keşap",
      "Piraziz",
      "Şebinkarahisar",
      "Tirebolu",
      "Yağlıdere"
    ],
    "Gümüşhane": ["Merkez", "Kelkit", "Köse", "Kürtün", "Şiran", "Torul"],
    "Hakkari": ["Merkez", "Çukurca", "Derecik", "Şemdinli", "Yüksekova"],
    "Hatay": [
      "Altınözü",
      "Antakya",
      "Arsuz",
      "Belen",
      "Defne",
      "Dörtyol",
      "Erzin",
      "Hassa",
      "İskenderun",
      "Kırıkhan",
      "Kumlu",
      "Payas",
      "Reyhanlı",
      "Samandağ",
      "Yayladağı"
    ],
    "Isparta": [
      "Merkez",
      "Aksu",
      "Atabey",
      "Eğirdir",
      "Gelendost",
      "Gönen",
      "Keçiborlu",
      "Şarkikaraağaç",
      "Senirkent",
      "Sütçüler",
      "Uluborlu",
      "Yalvaç",
      "Yenişarbademli"
    ],
    "Mersin": [
      "Akdeniz",
      "Anamur",
      "Aydıncık",
      "Bozyazı",
      "Çamlıyayla",
      "Erdemli",
      "Gülnar",
      "Mezitli",
      "Mut",
      "Silifke",
      "Tarsus",
      "Toroslar",
      "Yenişehir"
    ],
    "İstanbul": [
      "Adalar",
      "Arnavutköy",
      "Ataşehir",
      "Avcılar",
      "Bağcılar",
      "Bahçelievler",
      "Bakırköy",
      "Başakşehir",
      "Bayrampaşa",
      "Beşiktaş",
      "Beykoz",
      "Beylikdüzü",
      "Beyoğlu",
      "Büyükçekmece",
      "Çatalca",
      "Çekmeköy",
      "Esenler",
      "Esenyurt",
      "Eyüpsultan",
      "Fatih",
      "Gaziosmanpaşa",
      "Güngören",
      "Kadıköy",
      "Kağıthane",
      "Kartal",
      "Küçükçekmece",
      "Maltepe",
      "Pendik",
      "Sancaktepe",
      "Sarıyer",
      "Şile",
      "Silivri",
      "Şişli",
      "Sultanbeyli",
      "Sultangazi",
      "Tuzla",
      "Ümraniye",
      "Üsküdar",
      "Zeytinburnu"
    ],
    "İzmir": [
      "Aliağa",
      "Balçova",
      "Bayındır",
      "Bayraklı",
      "Bergama",
      "Beydağ",
      "Bornova",
      "Buca",
      "Çeşme",
      "Çiğli",
      "Dikili",
      "Foça",
      "Gaziemir",
      "Güzelbahçe",
      "Karabaglar",
      "Karaburun",
      "Karşıyaka",
      "Kemalpaşa",
      "Kınık",
      "Kiraz",
      "Konak",
      "Menderes",
      "Menemen",
      "Narlıdere",
      "Ödemiş",
      "Seferihisar",
      "Selçuk",
      "Tire",
      "Torbalı",
      "Urla"
    ],
    "Kars": [
      "Merkez",
      "Akyaka",
      "Arpaçay",
      "Digor",
      "Kağızman",
      "Sarıkamış",
      "Selim",
      "Susuz"
    ],
    "Kastamonu": [
      "Merkez",
      "Abana",
      "Ağlı",
      "Araç",
      "Azdavay",
      "Bozkurt",
      "Çatalzeytin",
      "Cide",
      "Daday",
      "Devrekani",
      "Doğanyurt",
      "Hanönü",
      "İhsangazi",
      "İnebolu",
      "Küre",
      "Pınarbaşı",
      "Şenpazar",
      "Seydiler",
      "Taşköprü",
      "Tosya"
    ],
    "Kayseri": [
      "Akkışla",
      "Bünyan",
      "Develi",
      "Felahiye",
      "Hacılar",
      "İncesu",
      "Kocasinan",
      "Melikgazi",
      "Özvatan",
      "Pınarbaşı",
      "Sarıoğlan",
      "Sarız",
      "Talas",
      "Tomarza",
      "Yahyalı",
      "Yeşilhisar"
    ],
    "Kırklareli": [
      "Merkez",
      "Babaeski",
      "Demirköy",
      "Kofçaz",
      "Lüleburgaz",
      "Pehlivanköy",
      "Pınarhisar",
      "Vize"
    ],
    "Kırşehir": [
      "Merkez",
      "Akçakent",
      "Akpınar",
      "Boztepe",
      "Çiçekdağı",
      "Kaman",
      "Mucur"
    ],
    "Kocaeli": [
      "Başiskele",
      "Çayırova",
      "Darıca",
      "Derince",
      "Dilovası",
      "Gebze",
      "Gölcük",
      "İzmit",
      "Kandıra",
      "Karamürsel",
      "Kartepe",
      "Körfez"
    ],
    "Konya": [
      "Ahırlı",
      "Akören",
      "Akşehir",
      "Altınekin",
      "Beyşehir",
      "Bozkır",
      "Çeltik",
      "Cihanbeyli",
      "Çumra",
      "Derbent",
      "Derebucak",
      "Doğanhisar",
      "Emirgazi",
      "Ereğli",
      "Güneysınır",
      "Hadim",
      "Halkapınar",
      "Hüyük",
      "Ilgın",
      "Kadınhanı",
      "Karapınar",
      "Karatay",
      "Kulu",
      "Meram",
      "Sarayönü",
      "Selçuklu",
      "Seydişehir",
      "Taşkent",
      "Tuzlukçu",
      "Yalıhüyük",
      "Yunak"
    ],
    "Kütahya": [
      "Merkez",
      "Altıntaş",
      "Aslanapa",
      "Çavdarhisar",
      "Domaniç",
      "Dumlupınar",
      "Emet",
      "Gediz",
      "Hisarcık",
      "Pazarlar",
      "Şaphane",
      "Simav",
      "Tavşanlı"
    ],
    "Malatya": [
      "Akçadağ",
      "Arapgir",
      "Arguvan",
      "Battalgazi",
      "Darende",
      "Doğanşehir",
      "Doğanyol",
      "Hekimhan",
      "Kale",
      "Kuluncak",
      "Pütürge",
      "Yazıhan",
      "Yeşilyurt"
    ],
    "Manisa": [
      "Ahmetli",
      "Akhisar",
      "Alaşehir",
      "Demirci",
      "Gölmarmara",
      "Gördes",
      "Kırkağaç",
      "Köprübaşı",
      "Kula",
      "Salihli",
      "Sarıgöl",
      "Saruhanlı",
      "Şehzadeler",
      "Selendi",
      "Soma",
      "Turgutlu",
      "Yunusemre"
    ],
    "Kahramanmaraş": [
      "Afşin",
      "Andırın",
      "Çağlayancerit",
      "Dulkadiroğlu",
      "Ekinözü",
      "Elbistan",
      "Göksun",
      "Nurhak",
      "Onikişubat",
      "Pazarcık",
      "Türkoğlu"
    ],
    "Mardin": [
      "Artuklu",
      "Dargeçit",
      "Derik",
      "Kızıltepe",
      "Mazıdağı",
      "Midyat",
      "Nusaybin",
      "Ömerli",
      "Savur",
      "Yeşilli"
    ],
    "Muğla": [
      "Bodrum",
      "Dalaman",
      "Datça",
      "Fethiye",
      "Kavaklıdere",
      "Köyceğiz",
      "Marmaris",
      "Menteşe",
      "Milas",
      "Ortaca",
      "Seydikemer",
      "Ula",
      "Yatağan"
    ],
    "Muş": ["Merkez", "Bulanık", "Hasköy", "Korkut", "Malazgirt", "Varto"],
    "Nevşehir": [
      "Merkez",
      "Acıgöl",
      "Avanos",
      "Derinkuyu",
      "Gülşehir",
      "Hacıbektaş",
      "Kozaklı",
      "Ürgüp"
    ],
    "Niğde": ["Merkez", "Altunhisar", "Bor", "Çamardı", "Çiftlik", "Ulukışla"],
    "Ordu": [
      "Akkuş",
      "Altınordu",
      "Aybastı",
      "Çamaş",
      "Çatalpınar",
      "Çaybaşı",
      "Fatsa",
      "Gölköy",
      "Gülyalı",
      "Gürgentepe",
      "İkizce",
      "Kabadüz",
      "Kabataş",
      "Korgan",
      "Kumru",
      "Mesudiye",
      "Perşembe",
      "Ulubey",
      "Ünye"
    ],
    "Rize": [
      "Merkez",
      "Ardeşen",
      "Çamlıhemşin",
      "Çayeli",
      "Derepazarı",
      "Fındıklı",
      "Güneysu",
      "Hemşin",
      "İkizdere",
      "İyidere",
      "Kalkandere",
      "Pazar"
    ],
    "Sakarya": [
      "Adapazarı",
      "Akyazı",
      "Arifiye",
      "Erenler",
      "Ferizli",
      "Geyve",
      "Hendek",
      "Karapürçek",
      "Karasu",
      "Kaynarca",
      "Kocaali",
      "Pamukova",
      "Sapanca",
      "Serdivan",
      "Söğütlü",
      "Taraklı"
    ],
    "Samsun": [
      "19 Mayıs",
      "Alaçam",
      "Asarcık",
      "Atakum",
      "Ayvacık",
      "Bafra",
      "Canik",
      "Çarşamba",
      "Havza",
      "İlkadım",
      "Kavak",
      "Ladik",
      "Salıpazarı",
      "Tekkeköy",
      "Terme",
      "Vezirköprü",
      "Yakakent"
    ],
    "Siirt": [
      "Merkez",
      "Baykan",
      "Eruh",
      "Kurtalan",
      "Pervari",
      "Şirvan",
      "Tillo"
    ],
    "Sinop": [
      "Merkez",
      "Ayancık",
      "Boyabat",
      "Dikmen",
      "Durağan",
      "Erfelek",
      "Gerze",
      "Saraydüzü",
      "Türkeli"
    ],
    "Sivas": [
      "Merkez",
      "Akıncılar",
      "Altınyayla",
      "Divriği",
      "Doğanşar",
      "Gemerek",
      "Gölova",
      "Gürün",
      "Hafik",
      "İmranlı",
      "Kangal",
      "Koyulhisar",
      "Şarkışla",
      "Suşehri",
      "Ulaş",
      "Yıldızeli",
      "Zara"
    ],
    "Tekirdağ": [
      "Çerkezköy",
      "Çorlu",
      "Ergene",
      "Hayrabolu",
      "Kapaklı",
      "Malkara",
      "Marmaraereğlisi",
      "Muratlı",
      "Saray",
      "Şarköy",
      "Süleymanpaşa"
    ],
    "Tokat": [
      "Merkez",
      "Almus",
      "Artova",
      "Başçiftlik",
      "Erbaa",
      "Niksar",
      "Pazar",
      "Reşadiye",
      "Sulusaray",
      "Turhal",
      "Yeşilyurt",
      "Zile"
    ],
    "Trabzon": [
      "Akçaabat",
      "Araklı",
      "Arsin",
      "Beşikdüzü",
      "Çarşıbaşı",
      "Çaykara",
      "Dernekpazarı",
      "Düzköy",
      "Hayrat",
      "Köprübaşı",
      "Maçka",
      "Of",
      "Ortahisar",
      "Salpazarı",
      "Sürmene",
      "Tonya",
      "Vakfıkebir",
      "Yomra"
    ],
    "Tunceli": [
      "Merkez",
      "Çemişgezek",
      "Hozat",
      "Mazgirt",
      "Nazimiye",
      "Ovacık",
      "Pertek",
      "Pülümür"
    ],
    "Şanlıurfa": [
      "Akçakale",
      "Birecik",
      "Bozova",
      "Ceylanpınar",
      "Eyyübiye",
      "Halfeti",
      "Haliliye",
      "Harran",
      "Hilvan",
      "Karaköprü",
      "Siverek",
      "Suruç",
      "Viranşehir"
    ],
    "Uşak": ["Merkez", "Banaz", "Eşme", "Karahallı", "Sivaslı", "Ulubey"],
    "Van": [
      "Bahçesaray",
      "Başkale",
      "Çaldıran",
      "Çatak",
      "Edremit",
      "Erciş",
      "Gevaş",
      "Gürpınar",
      "İpekyolu",
      "Muradiye",
      "Özalp",
      "Saray",
      "Tuşba"
    ],
    "Yozgat": [
      "Merkez",
      "Akdağmadeni",
      "Aydıncık",
      "Boğazlıyan",
      "Çandır",
      "Çayıralan",
      "Çekerek",
      "Kadışehri",
      "Saraykent",
      "Sarıkaya",
      "Sefaatli",
      "Sorgun",
      "Yenifakılı",
      "Yerköy"
    ],
    "Zonguldak": [
      "Merkez",
      "Alaplı",
      "Çaycuma",
      "Devrek",
      "Ereğli",
      "Gökçebey",
      "Kilimli",
      "Kozlu"
    ],
    "Aksaray": [
      "Merkez",
      "Ağaçören",
      "Eskil",
      "Gülağaç",
      "Güzelyurt",
      "Ortaköy",
      "Sarıyahşi",
      "Sultanhanı"
    ],
    "Bayburt": ["Merkez", "Aydıntepe", "Demirözü"],
    "Karaman": [
      "Merkez",
      "Ayrancı",
      "Başyayla",
      "Ermenek",
      "Kazımkarabekir",
      "Sariveliler"
    ],
    "Kırıkkale": [
      "Merkez",
      "Bahşılı",
      "Balışeyh",
      "Çelebi",
      "Delice",
      "Karakeçili",
      "Keskin",
      "Sulakyurt",
      "Yahşihan"
    ],
    "Batman": ["Merkez", "Beşiri", "Gercüş", "Hasankeyf", "Kozluk", "Sason"],
    "Şırnak": [
      "Merkez",
      "Beytüşşebap",
      "Cizre",
      "Güçlükonak",
      "İdil",
      "Silopi",
      "Uludere"
    ],
    "Bartın": ["Merkez", "Amasra", "Kurucaşile", "Ulus"],
    "Ardahan": ["Merkez", "Çıldır", "Damal", "Göle", "Hanak", "Posof"],
    "Iğdır": ["Merkez", "Aralık", "Karakoyunlu", "Tuzluca"],
    "Yalova": [
      "Merkez",
      "Altınova",
      "Armutlu",
      "Çiftlikköy",
      "Çınarcık",
      "Termal"
    ],
    "Karabük": [
      "Merkez",
      "Eflani",
      "Eskipazar",
      "Ovacık",
      "Safranbolu",
      "Yenice"
    ],
    "Kilis": ["Merkez", "Elbeyli", "Musabeyli", "Polateli"],
    "Osmaniye": [
      "Merkez",
      "Bahçe",
      "Düziçi",
      "Hasanbeyli",
      "Kadirli",
      "Sumbas",
      "Toprakkale"
    ],
    "Düzce": [
      "Merkez",
      "Akçakoca",
      "Çilimli",
      "Cumayeri",
      "Gölyaka",
      "Gümüşova",
      "Kaynaşlı",
      "Yığılca"
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
  String siradakiVakit = "Yükleniyor...";
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
    "Adıyaman",
    "Afyonkarahisar",
    "Ağrı",
    "Amasya",
    "Ankara",
    "Antalya",
    "Artvin",
    "Aydın",
    "Balıkesir",
    "Bilecik",
    "Bingöl",
    "Bitlis",
    "Bolu",
    "Burdur",
    "Bursa",
    "Çanakkale",
    "Çankırı",
    "Çorum",
    "Denizli",
    "Diyarbakır",
    "Edirne",
    "Elazığ",
    "Erzincan",
    "Erzurum",
    "Eskişehir",
    "Gaziantep",
    "Giresun",
    "Gümüşhane",
    "Hakkari",
    "Hatay",
    "Isparta",
    "Mersin",
    "İstanbul",
    "İzmir",
    "Kars",
    "Kastamonu",
    "Kayseri",
    "Kırklareli",
    "Kırşehir",
    "Kocaeli",
    "Konya",
    "Kütahya",
    "Malatya",
    "Manisa",
    "Kahramanmaraş",
    "Mardin",
    "Muğla",
    "Muş",
    "Nevşehir",
    "Niğde",
    "Ordu",
    "Rize",
    "Sakarya",
    "Samsun",
    "Siirt",
    "Sinop",
    "Sivas",
    "Tekirdağ",
    "Tokat",
    "Trabzon",
    "Tunceli",
    "Şanlıurfa",
    "Uşak",
    "Van",
    "Yozgat",
    "Zonguldak",
    "Aksaray",
    "Bayburt",
    "Karaman",
    "Kırıkkale",
    "Batman",
    "Şırnak",
    "Bartın",
    "Ardahan",
    "Iğdır",
    "Yalova",
    "Karabük",
    "Kilis",
    "Osmaniye",
    "Düzce"
  ];

  String? _ozelGunMesaji;

  @override
  void initState() {
    super.initState();
    _yukleTumAyarlar().then((_) {
      if (secilenSehir != "Seçilmedi") {
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
          "🔔 Bildirim İzni Gerekli",
          style: TextStyle(color: Color(0xFFB5627A)),
        ),
        content: const Text(
          "Uygulamanın namaz vakitlerini hatırlatabilmesi için bildirim izni gereklidir.\n\nLütfen Ayarlar > Uygulamalar > Ezan Vakti > Bildirimler yolunu izleyerek izni açın.",
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
        showNotification("🌸 Özel Gün!", "$bugun kutlu olsun! 🎉", sesli: true);
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
                    labelText: "İl Seçin",
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
                    labelText: "İlçe Seçin",
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
                child: const Text("İptal",
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
    if (secilenSehir == "Seçilmedi") return;
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
      debugPrint("Bağlantı hatası: $e");
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
            "⏰ Vakit Yaklaşıyor 🌸",
            "$vakitIsmi vaktine $erkenUyariDakikasi dakika kaldı.",
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
          "$vakitIsmi ezanı okunuyor.",
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
          siradakiVakit == "Yükleniyor..." ? "Namaz" : siradakiVakit;
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
              "Namazınızı kılmayı unutmayın.",
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
      secilenSehir = prefs.getString('secilen_sehir') ?? "Seçilmedi";
      secilenIlce = prefs.getString('secilen_ilce') ?? "Seçilmedi";

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
                          "🌸 Uygulama Ayarları",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB5627A)),
                        ),
                        const Divider(color: Color(0xFFE8C4D0)),
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
                              "🌷 Vaktinden önce uyarılmak istiyor musun?"),
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
                                const Text("Hatırlatma Süresi:",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  "${_kacDakikaOnceSlider.toInt()} dakika önce",
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
                        const Text("Bildirim kurulacak vakitleri seçin:",
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
                          title: const Text("🦋 Tam Ekran Uyarı"),
                          subtitle: const Text(
                              "Ekran kapalı/açık olsa da tam uyarı metni kaplasın"),
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
                              label: const Text("Uyarıyı Test Et 🌸"),
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
                          title: const Text("🌼 Bildirim Çubuğu"),
                          subtitle: const Text(
                              "Namaz vaktine kalan süre bildirim çubuğunda sabit dursun"),
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
                        const Text("🏙️ Şehir / İlçe Listem",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB5627A))),
                        const SizedBox(height: 5),
                        _kullaniciSehirler.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                    "Henüz hiç şehir eklemediniz. Lütfen 'Yeni Ekle' butonunu kullanın. 🌷",
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
                                          secilenSehir = "Seçilmedi";
                                          secilenIlce = "Seçilmedi";
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
              label: '🕋 Kıble'),
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
    _gununHadisiniCanliCek();
    _gununDuasiniCanliCek();
    _ozelGunleriHazirla();
  }

  Future<void> _gununDuasiniCanliCek() async {
    final canliDua = await GunlukIcerikServisi.gununDuasiGetir();
    if (!mounted) return;
    setState(() {
      bugununIcerikleri = {...bugununIcerikleri, "dua": canliDua};
    });
  }

  Future<void> _gununAyetiniCanliCek() async {
    final canliAyet = await GunlukIcerikServisi.gununAyetiGetir();
    if (!mounted) return;
    setState(() {
      bugununIcerikleri = {...bugununIcerikleri, "ayet": canliAyet};
    });
  }

  Future<void> _gununHadisiniCanliCek() async {
    final canliHadis = await GunlukIcerikServisi.gununHadisiGetir();
    if (!mounted) return;
    setState(() {
      bugununIcerikleri = {...bugununIcerikleri, "hadis": canliHadis};
    });
  }

  Future<void> _ozelGunleriHazirla() async {
    await OzelGunler.diniGunleriHazirla();
    if (!mounted) return;
    setState(() {});
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
                      Text("🌸 Yaklaşan Özel Gün",
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
                          "${yaklasanOzelGun['kalanGun']} gün sonra 🌷",
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
              "🌷 Günün Ayeti", bugununIcerikleri["ayet"]!, isDesktop, isDark),
          const SizedBox(height: 12),
          _buyukKarti("🌺 Günün Hadisi", bugununIcerikleri["hadis"]!, isDesktop,
              isDark),
          const SizedBox(height: 12),
          _buyukKarti(
              "🦋 Günün Duası", bugununIcerikleri["dua"]!, isDesktop, isDark),
          const SizedBox(height: 12),
          _buyukKarti(
              "🌸 Günün Esması", bugununIcerikleri["esma"]!, isDesktop, isDark),
          const SizedBox(height: 20),
          AltBilgiMetni(isDark: isDark),
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
        AltBilgiMetni(isDark: isDark),
      ],
    );
  }
}
