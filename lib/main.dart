import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezan_vakti/main.dart';
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

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  if (!kIsWeb) {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'namaz_vakitleri',
      'Namaz Vakitleri',
      description: 'Namaz vakitleri ve hatırlatıcı bildirimleri',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
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
              Icon(Icons.local_florist, size: 100, color: Color(0xFFB5627A)),
              SizedBox(height: 40),
              Text(
                "🌸 HOŞ GELDİN NEBAHAT 🌸",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB5627A),
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.white,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                "🌷 Ezan Vakti Uygulaması",
                style: TextStyle(
                  fontSize: 20,
                  color: Color(0xFF4A2E3B),
                  fontWeight: FontWeight.w500,
                ),
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

  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'namaz_vakitleri',
    'Namaz Vakitleri',
    importance: Importance.max,
    priority: Priority.high,
    playSound: sesli,
    sound: sound != null && sound != "default" && sound != "silent"
        ? RawResourceAndroidNotificationSound(sound)
        : null,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
  );
  NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    platformChannelSpecifics,
  );
}

Future<void> updateNotification(String remainingTime, String nextPrayer) async {
  if (kIsWeb) return;

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'namaz_vakitleri_sabit',
    'Sabit Namaz Vakti',
    channelDescription: 'Namaz vaktine kalan süreyi gösterir',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    playSound: false,
    enableVibration: false,
    onlyAlertOnce: true,
    showWhen: false,
  );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    999,
    "⏰ Namaz Vaktine Kalan Süre",
    "$nextPrayer namazına $remainingTime kaldı",
    platformChannelSpecifics,
  );
}

Future<void> cancelNotification() async {
  await flutterLocalNotificationsPlugin.cancel(999);
}

// ==================== EZAN VAKTİ APP ====================
class EzanVaktiApp extends StatefulWidget {
  const EzanVaktiApp({super.key});

  @override
  State<EzanVaktiApp> createState() => _EzanVaktiAppState();
}

class _EzanVaktiAppState extends State<EzanVaktiApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _temaAyariYukle();
  }

  Future<void> _temaAyariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('gece_modu') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezan Vakti 🌸',
      debugShowCheckedModeBanner: false,
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
              opacity: isDark ? 0.04 : 0.08,
              child: Image.asset(
                'assets/images/app_icon.png',
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

// ==================== ÖZEL GÜNLER VE DOĞUM GÜNLERİ ====================
class OzelGunler {
  // 6 ÖZEL GÜN
  static final List<Map<String, dynamic>> _ozelGunler = [
    {
      'ad': '🌸 Öğretmenler Günü',
      'tarih': '2025-11-24',
      'aciklama':
          'Başöğretmen Mustafa Kemal Atatürk\'e ve tüm öğretmenlere saygı ve şükran günü.',
    },
    {
      'ad': '🌷 Anneler Günü',
      'tarih': '2025-05-11',
      'aciklama':
          'Annelerimize sevgi, saygı ve şükran duygularımızı ifade ettiğimiz özel gün.',
    },
    {
      'ad': '🍒 Malatyalılar Günü',
      'tarih': '2025-05-15',
      'aciklama':
          'Malatya\'nın düşman işgalinden kurtuluşu, gurur ve dayanışma günü.',
    },
    {
      'ad': '👩‍💻 Kadın Yazılımcılar Günü',
      'tarih': '2025-10-13',
      'aciklama':
          'Kadın yazılımcıların teknoloji dünyasındaki başarılarını kutladığımız özel gün.',
    },
    {
      'ad': '🎓 Akademisyenler Günü',
      'tarih': '2025-05-19',
      'aciklama':
          'Gençlik ve Spor Bayramı, Atatürk\'ü Anma, tüm akademisyenlerin günü.',
    },
    {
      'ad': '💪 Fizyoterapistler Günü',
      'tarih': '2025-09-08',
      'aciklama':
          'Fizyoterapistlerin sağlık alanındaki önemli katkılarının kutlandığı gün.',
    },
  ];

  // 6 DOĞUM GÜNÜ
  static final List<Map<String, dynamic>> _dogumGunleri = [
    {
      'ad': '🌸 BEYZA\'NIN DOĞUM GÜNÜ',
      'tarih': '2025-12-15',
      'aciklama': 'Sevgili Beyza\'nın doğum günü kutlu olsun! 🎂',
    },
    {
      'ad': '🌷 AYŞENUR\'UN DOĞUM GÜNÜ',
      'tarih': '2025-08-18',
      'aciklama': 'Sevgili Ayşenur\'un doğum günü kutlu olsun! 🎂',
    },
    {
      'ad': '🌺 ESMANUR\'UN DOĞUM GÜNÜ',
      'tarih': '2025-04-13',
      'aciklama': 'Sevgili Esmanur\'un doğum günü kutlu olsun! 🎂',
    },
    {
      'ad': '🌼 SENANUR\'UN DOĞUM GÜNÜ',
      'tarih': '2025-06-22',
      'aciklama': 'Sevgili Senanur\'un doğum günü kutlu olsun! 🎂',
    },
    {
      'ad': '🌹 ANNE\'NİN DOĞUM GÜNÜ',
      'tarih': '2025-05-11',
      'aciklama': 'Canım Annem\'in doğum günü kutlu olsun! 🌸',
    },
    {
      'ad': '🌻 SÜMEYRA\'NIN DOĞUM GÜNÜ HAFTASI',
      'tarih': '2025-10-01',
      'aciklama':
          'Sevgili Sümeyra\'nın doğum günü haftası kutlu olsun! 🎂 (1-7 Ekim)',
      'hafta': true,
    },
  ];

  static Map<String, dynamic>? getYaklasanOzelGun() {
    DateTime now = DateTime.now();
    int currentYear = now.year;

    List<Map<String, dynamic>> tumGunler = [];

    for (var gun in _ozelGunler) {
      String tarih = gun['tarih'];
      List<String> parts = tarih.split('-');
      String yeniTarih = '$currentYear-${parts[1]}-${parts[2]}';
      if (DateTime.parse(yeniTarih).isBefore(now) && int.parse(parts[1]) < 12) {
        yeniTarih = '${currentYear + 1}-${parts[1]}-${parts[2]}';
      }
      tumGunler.add({
        'ad': gun['ad'],
        'tarih': yeniTarih,
        'aciklama': gun['aciklama'],
        'tur': 'ozel',
      });
    }

    for (var gun in _dogumGunleri) {
      String tarih = gun['tarih'];
      List<String> parts = tarih.split('-');
      String yeniTarih = '$currentYear-${parts[1]}-${parts[2]}';
      if (DateTime.parse(yeniTarih).isBefore(now)) {
        yeniTarih = '${currentYear + 1}-${parts[1]}-${parts[2]}';
      }
      tumGunler.add({
        'ad': gun['ad'],
        'tarih': yeniTarih,
        'aciklama': gun['aciklama'],
        'tur': 'dogum',
        'hafta': gun.containsKey('hafta'),
      });
    }

    tumGunler.sort(
      (a, b) =>
          DateTime.parse(a['tarih']).compareTo(DateTime.parse(b['tarih'])),
    );

    for (var gun in tumGunler) {
      DateTime gunTarih = DateTime.parse(gun['tarih']);
      if (gun['tur'] == 'dogum' &&
          gun.containsKey('hafta') &&
          gun['hafta'] == true) {
        if (now.month == 10 && now.day >= 1 && now.day <= 7) {
          return {
            'ad': gun['ad'],
            'kalanGun': 7 - now.day,
            'aciklama': gun['aciklama'],
            'tarih': gun['tarih'],
            'tur': 'dogum',
            'hafta': true,
          };
        }
      }
      if (gunTarih.isAfter(now) || gunTarih.isAtSameMomentAs(now)) {
        int kalanGun = gunTarih.difference(now).inDays;
        return {
          'ad': gun['ad'],
          'kalanGun': kalanGun,
          'aciklama': gun['aciklama'],
          'tarih': gun['tarih'],
          'tur': gun['tur'],
        };
      }
    }
    return null;
  }

  static String? bugunOzelGunVarMi() {
    DateTime now = DateTime.now();
    String bugun = DateFormat('yyyy-MM-dd').format(now);

    for (var gun in _ozelGunler) {
      String tarih = gun['tarih'];
      List<String> parts = tarih.split('-');
      String kontrolTarih = '${now.year}-${parts[1]}-${parts[2]}';
      if (kontrolTarih == bugun) {
        return gun['ad'];
      }
    }

    for (var gun in _dogumGunleri) {
      String tarih = gun['tarih'];
      List<String> parts = tarih.split('-');
      String kontrolTarih = '${now.year}-${parts[1]}-${parts[2]}';
      if (kontrolTarih == bugun) {
        return gun['ad'];
      }
      if (gun['ad'] == '🌻 SÜMEYRA\'NIN DOĞUM GÜNÜ HAFTASI') {
        if (now.month == 10 && now.day >= 1 && now.day <= 7) {
          return '🌻 SÜMEYRA\'NIN DOĞUM GÜNÜ HAFTASI';
        }
      }
    }
    return null;
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
    "Şüphesiz güçlükle beraber bir kolaylık vardır. (İnşirah, 5)",
    "Eğer şükrederseniz, elbette size nimetimi artırırım. (İbrahim, 7)",
    "Ben Rabbime tevekkül ettim. (Hûd, 56)",
    "Allah kuluna kâfi değil midir? (Zümer, 36)",
    "Rabbimiz! Bize katından bir rahmet ver. (Kehf, 10)",
    "Allah, adaleti, iyiliği ve akrabaya yardımı emreder. (Nahl, 90)",
    "Kim zerre kadar iyilik yaparsa onu görür. (Zilzal, 7)",
    "Kim zerre kadar kötülük yaparsa onu görür. (Zilzal, 8)",
    "De ki: 'O Allah birdir.' (İhlas, 1)",
  ];

  static const List<String> hadisler = [
    "Namaz, dinin direğidir. (Tirmizî)",
    "Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz. (Buhari)",
    "Ameller niyetlere göredir. (Buhari)",
    "Müslüman, Müslümanın kardeşidir. (Müslim)",
    "Sizin en hayırlınız, ahlakı en güzel olanınızdır. (Buhari)",
    "Veren el, alan elden hayırlıdır. (Buhârî, Müslim)",
    "Sizden biriniz, kendisi için istediğini kardeşi için de istemedikçe gerçek anlamda iman etmiş olmaz. (Buhârî, Müslim)",
    "Gülümsemen bile senin için bir sadakadır. (Tirmizî)",
    "Allah güzeldir, güzelliği sever. (Müslim)",
    "İyilik, güzel ahlaktır. (Müslim)",
  ];

  static const List<String> dualar = [
    "Rabbim! Bana ve aileme hayırlı evlat ver.",
    "Allah'ım! Kalbimi dinin üzere sabit kıl.",
    "Rabbenâ âtinâ fid-dünyâ haseneten ve fil âhirati haseneten ve kınâ azâben-nâr. (Bakara, 201)",
    "Rabbi zidnî ilmâ. (Tâhâ, 114)",
    "Allah'ım! Beni senden uzaklaştıracak her şeyden koru.",
    "Rabbenağfirlî ve li vâlideyye. (İbrahim, 41)",
    "Hasbunallâhu ve ni'mel vekîl. (Âl-i İmrân, 173)",
  ];

  static const List<String> esmalar = [
    "Er-Rahmân (Dünyada her canlıya merhamet eden)",
    "Er-Rahîm (Ahirette sadece müminlere merhamet eden)",
    "El-Melik (Mülkün, evrenin mutlak sahibi)",
    "El-Kuddûs (Her türlü eksiklikten uzak olan)",
    "Es-Selâm (Kullarını selamete çıkaran)",
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
    "İbrahim",
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
    "Şuarâ",
    "Neml",
    "Kasas",
    "Ankebût",
    "Rûm",
    "Lokman",
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
    "Cum'a",
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
    "İnsan",
    "Mürselât",
    "Nebe'",
    "Nâziât",
    "Abese",
    "Tekvîr",
    "İnfitâr",
    "Mutaffifîn",
    "İnşikâk",
    "Bürûc",
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
    "Kadir",
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
    "Nâs",
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
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          widget.isDark ? const Color(0xFF1A1118) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
        ),
      )
      ..loadRequest(Uri.parse('https://kuran.diyanet.gov.tr/mushaf'));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

// ==================== KIBLE WEB VIEW (DİYANET KIBLE BULUCU) ====================
class KibleWebView extends StatefulWidget {
  final bool isDark;

  const KibleWebView({super.key, required this.isDark});

  @override
  State<KibleWebView> createState() => _KibleWebViewState();
}

class _KibleWebViewState extends State<KibleWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          widget.isDark ? const Color(0xFF1A1118) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
        ),
      )
      ..loadRequest(Uri.parse('https://kible.diyanet.gov.tr/'));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

// ==================== ANA SAYFA GEZGİNİ ====================
class AnaSayfaGezgini extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const AnaSayfaGezgini({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<AnaSayfaGezgini> createState() => _AnaSayfaGezginiState();
}

class _AnaSayfaGezginiState extends State<AnaSayfaGezgini> {
  int _aktifSayfaIndex = 0;
  String secilenSehir = "Muş";
  String secilenIlce = "Merkez";
  bool isLoading = true;
  List<dynamic> aylikVeriHavuzu = [];

  final Map<String, List<String>> _ilIlceMap = {
    "Muş": ["Merkez", "Bulanık", "Hasköy", "Korkut", "Malazgirt", "Varto"],
    "Balıkesir": [
      "Merkez",
      "Altıeylül",
      "Ayvalık",
      "Bandırma",
      "Gönen",
      "Edremit"
    ],
    "Malatya": [
      "Merkez",
      "Akçadağ",
      "Arapgir",
      "Battalgazi",
      "Darende",
      "Yeşilyurt"
    ],
    "Sivas": [
      "Merkez",
      "Şarkışla",
      "Suşehri",
      "Gemerek",
      "Kangal",
      "Yıldızeli"
    ],
    "Ankara": [
      "Merkez",
      "Çankaya",
      "Keçiören",
      "Mamak",
      "Etimesgut",
      "Sincan",
      "Gölbaşı"
    ],
    "İstanbul": [
      "Merkez",
      "Kadıköy",
      "Üsküdar",
      "Beşiktaş",
      "Fatih",
      "Beyoğlu"
    ],
    "İzmir": ["Merkez", "Konak", "Karşıyaka", "Bornova", "Bayraklı", "Çiğli"],
    "Bursa": ["Merkez", "Nilüfer", "Osmangazi", "Yıldırım", "Gürsu", "Kestel"],
    "Konya": ["Merkez", "Selçuklu", "Meram", "Karatay", "Ereğli", "Akşehir"],
    "Antalya": [
      "Merkez",
      "Muratpaşa",
      "Konyaaltı",
      "Kepez",
      "Alanya",
      "Manavgat"
    ],
    "Diyarbakır": [
      "Merkez",
      "Bağlar",
      "Kayapınar",
      "Ergani",
      "Bismil",
      "Çermik"
    ],
    "Gaziantep": [
      "Merkez",
      "Şahinbey",
      "Şehitkamil",
      "Nizip",
      "İslahiye",
      "Araban"
    ],
    "Mersin": [
      "Merkez",
      "Akdeniz",
      "Yenişehir",
      "Tarsus",
      "Silifke",
      "Erdemli"
    ],
  };

  final List<Map<String, String>> _sabitSehirler = [
    {"display": "🌸 Muş (Merkez)", "il": "Muş", "ilce": "Merkez"},
    {"display": "🌸 Balıkesir (Gönen)", "il": "Balıkesir", "ilce": "Gönen"},
    {"display": "🌸 Malatya (Merkez)", "il": "Malatya", "ilce": "Merkez"},
    {"display": "🌸 Sivas (Şarkışla)", "il": "Sivas", "ilce": "Şarkışla"},
  ];

  List<Map<String, String>> _kullaniciSehirler = [];

  Map<String, String> bugununVakitleri = {
    "İmsak": "--:--",
    "Güneş": "--:--",
    "Öğle": "--:--",
    "İkindi": "--:--",
    "Akşam": "--:--",
    "Yatsı": "--:--",
  };

  String kalanSure = "00:00:00";
  String siradakiVakit = "Yükleniyor...";
  double ilerlemeOrani = 1.0;
  Timer? _saniyeSayaci;

  bool _vakitGeldiMi = false;

  bool _vakitOncesiUyari = true;
  double _kacDakikaOnceSlider = 15.0;
  String _bildirimSesTipi = "default";
  bool _tamEkranUyari = false;
  bool _bildirimCubugu = false;
  Map<String, bool> _seciliVakitler = {
    "İmsak": true,
    "Güneş": true,
    "Öğle": true,
    "İkindi": true,
    "Akşam": true,
    "Yatsı": true,
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
    "Hakkâri",
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
      ezanVakitleriniGetir();
    });
    _saniyeSayaci = Timer.periodic(const Duration(seconds: 1), (timer) {
      sayaciGuncelle();
      _bildirimCubuguGuncelle();
      _kaydetKalanSure();
      _ozelGunKontrol();
    });
  }

  @override
  void dispose() {
    _saniyeSayaci?.cancel();
    super.dispose();
  }

  List<Map<String, String>> get _tumSehirler {
    return [..._sabitSehirler, ..._kullaniciSehirler];
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
    String? secilenIl;
    String? secilenIlce;

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
              "🌸 Şehir Ekle",
              style: TextStyle(color: Color(0xFFB5627A)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "İl Seçin",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  value: secilenIl,
                  items: turkiyeIlleri.map((il) {
                    return DropdownMenuItem(value: il, child: Text(il));
                  }).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      secilenIl = value;
                      secilenIlce = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "İlçe Seçin",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  value: secilenIlce,
                  items: secilenIl != null && _ilIlceMap.containsKey(secilenIl)
                      ? _ilIlceMap[secilenIl]!.map((ilce) {
                          return DropdownMenuItem(
                              value: ilce, child: Text(ilce));
                        }).toList()
                      : [],
                  onChanged: (value) {
                    setStateDialog(() {
                      secilenIlce = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "İptal",
                  style: TextStyle(color: Color(0xFFB5627A)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (secilenIl != null && secilenIlce != null) {
                    setState(() {
                      _kullaniciSehirler.add({
                        "display": "🌸 $secilenIl ($secilenIlce)",
                        "il": secilenIl!,
                        "ilce": secilenIlce!,
                      });
                      secilenSehir = secilenIl!;
                      secilenIlce = secilenIlce!;
                    });
                    _kaydetTumAyarlar();
                    ezanVakitleriniGetir();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8C4D0),
                  foregroundColor: const Color(0xFF4A2E3B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
          "İmsak": temizleZaman(timings['Fajr']),
          "Güneş": temizleZaman(timings['Sunrise']),
          "Öğle": temizleZaman(timings['Dhuhr']),
          "İkindi": temizleZaman(timings['Asr']),
          "Akşam": temizleZaman(timings['Maghrib']),
          "Yatsı": temizleZaman(timings['Isha']),
        };
      });
    }
    sayaciGuncelle();
  }

  String temizleZaman(String? v) {
    if (v == null) return "--:--";
    final match = RegExp(r'(\d{2}:\d{2})').firstMatch(v);
    return match != null ? match.group(0)! : "--:--";
  }

  void sayaciGuncelle() {
    if (bugununVakitleri.values.any((v) => v == "--:--")) return;
    final simdi = DateTime.now();
    final imsakTime = parseTime(bugununVakitleri["İmsak"]!);
    final gunesTime = parseTime(bugununVakitleri["Güneş"]!);
    final ogleTime = parseTime(bugununVakitleri["Öğle"]!);
    final ikindiTime = parseTime(bugununVakitleri["İkindi"]!);
    final aksamTime = parseTime(bugununVakitleri["Akşam"]!);
    final yatsiTime = parseTime(bugununVakitleri["Yatsı"]!);

    DateTime hedeflenenVakit;
    DateTime baslangicTime;
    String vakitIsmi;

    if (simdi.isBefore(imsakTime)) {
      hedeflenenVakit = imsakTime;
      baslangicTime = yatsiTime.subtract(const Duration(days: 1));
      vakitIsmi = "İmsak";
    } else if (simdi.isBefore(gunesTime)) {
      hedeflenenVakit = gunesTime;
      baslangicTime = imsakTime;
      vakitIsmi = "Güneş";
    } else if (simdi.isBefore(ogleTime)) {
      hedeflenenVakit = ogleTime;
      baslangicTime = gunesTime;
      vakitIsmi = "Öğle";
    } else if (simdi.isBefore(ikindiTime)) {
      hedeflenenVakit = ikindiTime;
      baslangicTime = ogleTime;
      vakitIsmi = "İkindi";
    } else if (simdi.isBefore(aksamTime)) {
      hedeflenenVakit = aksamTime;
      baslangicTime = ikindiTime;
      vakitIsmi = "Akşam";
    } else if (simdi.isBefore(yatsiTime)) {
      hedeflenenVakit = yatsiTime;
      baslangicTime = aksamTime;
      vakitIsmi = "Yatsı";
    } else {
      hedeflenenVakit = imsakTime.add(const Duration(days: 1));
      baslangicTime = yatsiTime;
      vakitIsmi = "İmsak";
    }

    final toplamSure = hedeflenenVakit.difference(baslangicTime);
    final kalanSureDuration = hedeflenenVakit.difference(simdi);

    if (_vakitOncesiUyari) {
      int erkenUyariSaniyesi = (_kacDakikaOnceSlider.toInt() * 60);
      if (kalanSureDuration.inSeconds == erkenUyariSaniyesi) {
        showNotification(
          "⏰ Vakit Yaklaşıyor 🌸",
          "$vakitIsmi vaktine ${_kacDakikaOnceSlider.toInt()} dakika kaldı.",
        );
      }
    }

    if (kalanSureDuration.inSeconds <= 0 && !_vakitGeldiMi) {
      _vakitGeldiMi = true;
      if (_seciliVakitler[vakitIsmi] == true) {
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
    } else if (kalanSureDuration.inSeconds > 0) {
      _vakitGeldiMi = false;
    }

    if (mounted) {
      setState(() {
        siradakiVakit = vakitIsmi;
        ilerlemeOrani = (kalanSureDuration.inSeconds / toplamSure.inSeconds)
            .clamp(0.0, 1.0);
        kalanSure =
            "${kalanSureDuration.inHours.toString().padLeft(2, '0')}:${(kalanSureDuration.inMinutes % 60).toString().padLeft(2, '0')}:${(kalanSureDuration.inSeconds % 60).toString().padLeft(2, '0')}";
      });
      _kaydetKalanSure();
    }
  }

  void _bildirimCubuguGuncelle() async {
    if (_bildirimCubugu && kalanSure != "00:00:00") {
      await updateNotification(kalanSure, siradakiVakit);
    } else if (!_bildirimCubugu) {
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
      secilenSehir = prefs.getString('secilen_sehir') ?? "Muş";
      secilenIlce = prefs.getString('secilen_ilce') ?? "Merkez";

      String? seciliVakitlerJson = prefs.getString('secili_vakitler');
      if (seciliVakitlerJson != null) {
        Map<String, dynamic> json = jsonDecode(seciliVakitlerJson);
        _seciliVakitler = json.map((k, v) => MapEntry(k, v as bool));
      }
      if (!_seciliVakitler.containsKey("Güneş")) {
        _seciliVakitler["Güneş"] = true;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
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
                            color: Color(0xFFB5627A),
                          ),
                        ),
                        const Divider(color: Color(0xFFE8C4D0)),
                        SwitchListTile(
                          title: const Text(
                            "🌷 Vaktinden önce uyarılmak istiyor musun?",
                          ),
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
                                const Text(
                                  "Hatırlatma Süresi:",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "${_kacDakikaOnceSlider.toInt()} dakika önce",
                                  style: const TextStyle(
                                    color: Color(0xFFB5627A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
                        const Text(
                          "Bildirim kurulacak vakitleri seçin:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB5627A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _seciliVakitler.keys.map((vakit) {
                            return FilterChip(
                              label: Text(vakit),
                              selected: _seciliVakitler[vakit]!,
                              onSelected: (val) {
                                setModalState(
                                  () => _seciliVakitler[vakit] = val,
                                );
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
                            "Ekran kapalı/açık olsa da tam uyarı metni kaplasın",
                          ),
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
                              label: const Text("Uyanışı Test Et 🌸"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8C4D0),
                                foregroundColor: const Color(0xFF4A2E3B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                _tamEkranUyariGoster("Test");
                              },
                            ),
                          ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text("🌼 Bildirim Çubuğu"),
                          subtitle: const Text(
                            "Namaz vaktine kalan süre bildirim çubuğunda sabit dursun",
                          ),
                          value: _bildirimCubugu,
                          onChanged: (val) async {
                            setModalState(() => _bildirimCubugu = val);
                            setState(() => _bildirimCubugu = val);
                            _kaydetTumAyarlar();
                            if (val) {
                              await updateNotification(
                                kalanSure,
                                siradakiVakit,
                              );
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
                        const Text(
                          "🏙️ Şehir / İlçe Seçimi",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB5627A),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Column(
                          children: _tumSehirler.map((sehir) {
                            bool isSabit = _sabitSehirler.contains(sehir);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(sehir["display"]!),
                              trailing: isSabit
                                  ? null
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _kullaniciSehirler.remove(sehir);
                                        });
                                        _kaydetTumAyarlar();
                                        if (_kullaniciSehirler.isNotEmpty) {
                                          final son = _kullaniciSehirler.last;
                                          secilenSehir = son["il"]!;
                                          secilenIlce = son["ilce"]!;
                                        } else {
                                          final ilk = _sabitSehirler.first;
                                          secilenSehir = ilk["il"]!;
                                          secilenIlce = ilk["ilce"]!;
                                        }
                                        ezanVakitleriniGetir();
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
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: _tumSehirler.any(
                                  (s) =>
                                      s["il"] == secilenSehir &&
                                      s["ilce"] == secilenIlce,
                                )
                                    ? "$secilenSehir|||$secilenIlce"
                                    : null,
                                isExpanded: true,
                                hint: Text(secilenSehir),
                                items: _tumSehirler.map((sehir) {
                                  String value =
                                      "${sehir["il"]}|||${sehir["ilce"]}";
                                  bool isSabit = _sabitSehirler.contains(sehir);
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(sehir["display"]!),
                                        ),
                                        if (!isSabit)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _kullaniciSehirler.remove(
                                                  sehir,
                                                );
                                              });
                                              _kaydetTumAyarlar();
                                              if (_kullaniciSehirler
                                                  .isNotEmpty) {
                                                final son =
                                                    _kullaniciSehirler.last;
                                                secilenSehir = son["il"]!;
                                                secilenIlce = son["ilce"]!;
                                              } else {
                                                final ilk =
                                                    _sabitSehirler.first;
                                                secilenSehir = ilk["il"]!;
                                                secilenIlce = ilk["ilce"]!;
                                              }
                                              ezanVakitleriniGetir();
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    List<String> parts = val.split("|||");
                                    String il = parts[0];
                                    String ilce = parts[1];
                                    setState(() {
                                      secilenSehir = il;
                                      secilenIlce = ilce;
                                    });
                                    ezanVakitleriniGetir();
                                    _kaydetTumAyarlar();
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Color(0xFFB5627A),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isDarkMode
                        ? [
                            const Color(0xFF2D1B2E).withValues(alpha: 0.7),
                            const Color(0xFF1A1118).withValues(alpha: 0.5),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.6),
                            const Color(0xFFFDF0F2).withValues(alpha: 0.3),
                          ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_florist,
                            color: Color(0xFFB5627A),
                            size: 18,
                          ),
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
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat(
                              'd MMMM yyyy',
                              'tr_TR',
                            ).format(DateTime.now()),
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 13,
                              color: widget.isDarkMode
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
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
                              : const Color(0xFFB5627A).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: widget.isDarkMode
                              ? const Color(0xFFF5B7B7)
                              : const Color(0xFFB5627A),
                          size: 28,
                        ),
                        onPressed: _ayarlarMenusunuAc,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFB5627A),
                        ),
                      )
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
                          KibleWebView(isDark: widget.isDarkMode),
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
            icon: Icon(Icons.timer, size: 28),
            label: '🌸 Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_filled, size: 28),
            label: '🌷 Vakitler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book, size: 28),
            label: '🌺 Kuran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.compass_calibration, size: 28),
            label: '🧭 Kıble',
          ),
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
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 16,
        vertical: 8,
      ),
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
                        color: isDark ? Colors.white : const Color(0xFFB5627A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "🌸 Sıradaki: $siradakiVakit",
                      style: TextStyle(
                        color: const Color(0xFFB5627A),
                        fontSize: isDesktop ? 18 : 14,
                        fontWeight: FontWeight.bold,
                      ),
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
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration,
                    color: Color(0xFFB5627A),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.ozelGunMesaji!,
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF4A2E3B),
                      ),
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
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFFB5627A),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "🌸 Yaklaşan Özel Gün",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFFB5627A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    yaklasanOzelGun['ad'],
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF4A2E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${yaklasanOzelGun['kalanGun']} gün sonra 🌷",
                    style: const TextStyle(
                      color: Color(0xFFB5627A),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    yaklasanOzelGun['aciklama'],
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          _buyukKarti(
            "🌷 Günün Ayeti",
            bugununIcerikleri["ayet"]!,
            isDesktop,
            isDark,
          ),
          const SizedBox(height: 12),
          _buyukKarti(
            "🌺 Günün Hadisi",
            bugununIcerikleri["hadis"]!,
            isDesktop,
            isDark,
          ),
          const SizedBox(height: 12),
          _buyukKarti(
            "🦋 Günün Duası",
            bugununIcerikleri["dua"]!,
            isDesktop,
            isDark,
          ),
          const SizedBox(height: 12),
          _buyukKarti(
            "🌸 Günün Esması",
            bugununIcerikleri["esma"]!,
            isDesktop,
            isDark,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "🌸 Bu uygulama AYŞE NUR tarafından annesi için hazırlanmıştır 🌸",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buyukKarti(
    String baslik,
    String icerik,
    bool isDesktop,
    bool isDark,
  ) {
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
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(
              color: Color(0xFFB5627A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            icerik,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: isDesktop ? 16 : 14,
              height: 1.4,
            ),
          ),
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
      "İmsak": 0,
      "Güneş": 1,
      "Öğle": 2,
      "İkindi": 3,
      "Akşam": 4,
      "Yatsı": 5,
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
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration,
                    color: Color(0xFFB5627A),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ozelGunMesaji!,
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF4A2E3B),
                      ),
                    ),
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
                  vertical: isDesktop ? 24 : 18,
                ),
                decoration: BoxDecoration(
                  gradient: isCurrent
                      ? LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF3D1F3A),
                                  const Color(0xFF2D1B2E)
                                ]
                              : [
                                  const Color(0xFFF5E6E8),
                                  const Color(0xFFE8C4D0)
                                ],
                        )
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
                    width: isCurrent ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8C4D0).withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCurrent ? Icons.circle : Icons.circle_outlined,
                          color: isCurrent
                              ? const Color(0xFFB5627A)
                              : (isDark ? Colors.white54 : Colors.grey),
                          size: isDesktop ? 16 : 12,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: isDesktop ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? const Color(0xFFB5627A)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: isDesktop ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: isCurrent
                            ? const Color(0xFFB5627A)
                            : (isDark ? Colors.white70 : Colors.black87),
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
          child: Text(
            "🌸 Bu uygulama AYŞE NUR tarafından annesi için hazırlanmıştır 🌸",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
