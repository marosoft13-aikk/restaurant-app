// ---------------------------
// الجزء الأول: الاستيراد (imports)
// العن��صر التي نحتاجها من مكتبات خارجية وداخلية.
// ---------------------------

import 'dart:async'; // نستخدمها عندما نريد "الانتظار" لأشياء تحدث بعد قليل.
import 'dart:ui' as ui; // لإعداد اتجاه النص (يمين لليسار أو يسار لليمين).
import 'package:flutter/material.dart'; // صندوق أدوات Flutter لبناء الواجهة.
import 'package:provider/provider.dart'; // هنا نحتفظ "بصناديق" (Providers) بها بيانات التطبيق.
import 'package:firebase_core/firebase_core.dart'; // لنربط التطبيق مع Firebase (خدمة سحابية).
import 'firebase_options.dart'; // ملف الإعدادات الخاص بFirebase (يجب أن يوجد في مشروعك).
import 'package:intl/intl.dart'; // للتعامل مع التواريخ والأرقام حسب اللغة.
import 'package:intl/date_symbol_data_local.dart'; // بيانات التواريخ للغات مختلفة.
import 'package:flutter_localizations/flutter_localizations.dart'; // لتجعل Flutter يتكلم لغتك.

// ---------------------------
// استيراد خدمات وصفحات ومقدّمات الحالة (Providers).
// فكر فيهم كأجزاء التطبيق: صفحات (شاشات)، و"خدمات" تفعل أشياء، و"صناديق" تحمل بيانات.
// ---------------------------

// Services (خدمات)
import 'services/notification_service.dart'; // خدمة الإشعارات — تجعل التطبيق يرسل إشعارات.

// Providers (صناديق تحمل بيانات وتُعلِم الواجهة عندما تتغير)
import 'providers/menu_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/user_provider.dart';
import 'providers/firestore_menu_provider.dart';

// Pages (الشاشات — الأماكن التي يراها المستخدم)
import 'pages/login_page.dart';
import 'pages/video_welcome.dart';
import 'pages/full-menu.dart';
import 'pages/cart_page.dart';
import 'pages/order_tracking_page.dart';
import 'pages/payment_page.dart';
import 'pages/settings_page.dart';
import 'pages/offers_page.dart';
import 'pages/social_login_screen.dart';
import 'pages/home_page.dart';
import 'pages/payment_webview.dart';
import 'pages/driver_tracking_page.dart';
import 'pages/admin_upload_menu.dart';
import 'pages/admin_menu_page.dart';
import 'pages/add_offer_page.dart';
import 'pages/edit_offer_page.dart';

// ---------------------------
// دالة main: المكان الذي يبدأ منه التطبيق.
// فكر فيها كباب بيتك — قبل أن تدخل (runApp) نفعل بعض التحضيرات.
// ---------------------------

Future<void> main() async {
  // هذا السطر مهم: يقول لـ Flutter "استعد، قد نفعل أشياء تحتاج انتظار".
  WidgetsFlutterBinding.ensureInitialized();

  // نربط تطبيقنا بحساب Firebase الخاص بالمشروع.
  // هذا يشبه توصيل التطبيق بخدمات سحابية (لتخزين البيانات، الإشعارات، وغيرها).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // نريد أن تظهر التواريخ والأيام والشهور باللغة التي نريدها (مثل العربية).
  // initializeDateFormatting يحمل بيانات تنسيقات التواريخ.
  try {
    await initializeDateFormatting();
  } catch (e) {
    // لو فشل التحميل، نطبع رسالة في سجلات التطوير (لا نغلق التطبيق).
    debugPrint('initializeDateFormatting failed: $e');
  }

  // نحاول تهيئة خدمة الإشعارات (NotificationService).
  // لو فشلت، نطبع رسالة في السجلات.
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService.init failed: $e');
  }

  // هذا يساعد Flutter أن يطبع أخطاؤه في وحدة السجل (console).
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // runZonedGuarded يلتقط الأخطاء الغير متوقعة التي تحدث أثناء تشغيل التطبيق.
  // فكّر فيه كشبكة أمان: لو حصل شيء خاطئ ستمسكه الشبكة بدلاً من سقوط التطبيق.
  runZonedGuarded(() {
    // ErrorWidget.builder: يحدد ما يظهر على الشاشة لو واجهنا خطأ أثناء بناء واجهة ما.
    // بدلاً من شاشة بيضاء أو تعطل، نظهر رسالة لطيفة.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('ErrorWidget: ${details.exception}');
      return Scaffold(
        body: Center(
          child: Text(
            'حدث خطأ غير متوقع — راجع السجلات',
            textAlign: TextAlign.center,
          ),
        ),
      );
    };

    // الآن نفتح التطبيق.
    runApp(const MainWrapper());
  }, (error, stack) {
    // هذا الجزء يتنفّذ إذا حدث خطأ كبير في أي مكان.
    debugPrint('UNCAUGHT ERROR: $error\n$stack');
    // في تطبيق حقيقي قد نرسل هذا الخطأ إلى خدمة تسجيل الأخطاء (Sentry...).
  });
}

// ---------------------------
// MainWrapper: هنا نضع كل "الصناديق" (Providers) التي سيحتاجها التطبيق.
// نفعل ذلك قبل أن نعرض التطبيق حتى كل شيء يكون جاهزاً عند التشغيل.
// ---------------------------

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider كصندوق كبير به عدة صناديق صغيرة بداخلها.
    // كل ChangeNotifierProvider يُنشئ "صندوق" يحمل بيانات ويمكن للواجهة الاستماع إليه.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(
          // FirestoreMenuProvider مثال: بعد إنشائه يقوم بتحميل المنتجات من Firestore.
          create: (_) => FirestoreMenuProvider()..loadProducts(),
        ),
      ],
      child: const MyApp(), // ثم نعرض التطبيق نفسه.
    );
  }
}

// ---------------------------
// MyApp: هذا هو التطبيق نفسه.
// اخترت StatefulWidget لأننا نريد تغيير اللغة أثناء التشغيل.
// ---------------------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // نحتفظ باللغة الحالية كسلسلة نصية ('ar' للعربية، 'en' للإنجليزية).
  String locale = 'ar'; // نبدأ بالعربية.

  @override
  void initState() {
    super.initState();
    // نعلم مكتبة intl أي لغة نستخدم كافتراضية.
    Intl.defaultLocale = locale;
  }

  // دالة لتبديل اللغة بين العربية والإنجليزية.
  // يمكن استدعاؤها من زر أو قائمة داخل التطبيق.
  Future<void> toggleLocale() async {
    // إذا كنا الآن بالعربية، نغّير إلى الإنجليزية، وإلا نعود للعربية.
    final newLocale = locale == 'ar' ? 'en' : 'ar';
    try {
      // نحاول جلب بيانات تنسيق التواريخ للغة الجديدة (قد لا تحتاج وقت فعلي لكن نحاول).
      await initializeDateFormatting(newLocale, null);
    } catch (e) {
      // لو فشل التحميل لا نوقف التطبيق — نطبع فقط.
      debugPrint('initializeDateFormatting($newLocale) failed: $e');
    }
    // نحدث حالة الواجهة لتظهر اللغة الجديدة.
    setState(() {
      locale = newLocale;
    });
    // ونعلم مكتبة intl أيضاً.
    Intl.defaultLocale = newLocale;
  }

  @override
  Widget build(BuildContext context) {
    // isAr هو متغير بسيط يخبرنا هل اللغة العربية أم لا.
    final isAr = locale == 'ar';

    // MaterialApp يشبه الصندوق الكبير الذي يحتوي كل التطبيق (السمات، المسارات، اللغة...).
    return MaterialApp(
      debugShowCheckedModeBanner:
          false, // يزيل علامة DEBUG عن التطبيق أثناء التط��ير.
      title: 'Brostaky', // اسم التطبيق (ظاهر أحياناً في إعدادات النظام).
      theme: ThemeData(
        fontFamily:
            "Cairo", // اسم الخط الافتراضي — تأكد أنه مضاف في pubspec.yaml.
        primarySwatch: Colors.deepOrange,
        useMaterial3: true, // نستخدم مظهر Material 3 إن أردت.
      ),
      // نخبر Flutter ما هي اللغة الحالية للتطبيق.
      locale: Locale(locale),
      // Delegates تساعد Flutter على ترجمة مكونات النظام (مثل أزرار التاريخ).
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // اللغات التي يدعمها تطبيقك — هنا العربية والإنجليزية.
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      // الشاشة التي ستظهر أولاً عند فتح التطبيق.
      home: const LoginPage(),
      // هنا نعرّف "خرائط" أو "أسماء الأماكن" (المسارات) للتنقل داخل التطبيق.
      routes: {
        '/login': (_) => const LoginPage(),
        '/video': (_) => const VideoWelcomePage(),
        '/cart': (_) => const CartPage(),
        '/tracking': (_) => const OrderTrackingPage(),
        '/settings': (_) => const SettingsPage(),
        '/offers': (_) => const OffersPage(),
        '/home': (_) => const HomeScreen(),
        '/social': (_) => const SocialLoginPage(),

        // أمثلة لمسارات الدفع: نضع قيم افتراضية هنا للمثال.
        '/payment_native': (_) =>
            PaymentPage(orderId: "no-id", totalAmount: 100),
        '/payment_webview': (_) => PaymentWebViewPage(),
        '/payment_page': (_) => PaymentPage(orderId: "no-id", totalAmount: 100),

        // المسار الخاص بالقائمة (Menu). نغلف الشاشة بـ Directionality ليكون اتجاه النص صحيح.
        // إذا كانت العربية، نضع اتجاه النص من اليمين إلى اليسار (RTL).
        '/menu': (context) => Directionality(
              textDirection: isAr ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              child:
                  MenuHomeScreen(locale: locale, onToggleLocale: toggleLocale),
            ),

        // مثال لمسار تتبع السائق (Driver Tracking).
        '/driver_tracking': (_) =>
            const DriverTrackingPage(orderId: 'sampleOrderId'),

        "/add-offer": (_) => const AddOfferPage(),

        // مثال لمسار تحرير عرض — هنا نتوقع أن نحصل على بيانات من arguments.
        "/edit-offer": (context) {
          // عندما نستخدم Navigator.pushNamed(context, '/edit-offer', arguments: {...});
          // يمكننا جلب هذه البيانات هنا.
          final route = ModalRoute.of(context);
          if (route == null || route.settings.arguments == null) {
            // قابل للتعديل حسب احتياجك — هنا نعيد صفحة فارغة أو رسالة.
            return const Scaffold(
              body: Center(child: Text('بيانات العرض غير موجودة')),
            );
          }
          final args = route.settings.arguments as Map<String, dynamic>;
          // ملاحظة مهمة جداً للمبتدئين:
          // استخدام "!" يعني أنك تقول "أنا متأكد أن هذه القيمة ليست فارغة".
          // هنا نتفادى "!" ونفحص null كما فوق.
          return EditOfferPage(id: args["id"], data: args["data"]);
        },

        '/admin-upload-menu': (_) => const AdminUploadMenuPage(),
        '/admin-menu': (_) => const AdminMenuPage(),
      },
    );
  }
}

// ---------------------------
// ملاحظات بسيطة وسهلة التنفيذ بعد قراءة الملف:
// ---------------------------
// 1) للتشغيل: افتح الـ terminal وشغّل: flutter run
// 2) لو ظهر خطأ عن firebase_options.dart: تأكد أنك شغّلت إعداد Firebase وملف الإعدادات موجود.
// 3) لو ظهر خطأ عن الخط "Cairo": افتح pubspec.yaml وأضف الخط ضمن assets/fonts ثم اعمل flutter pub get.
// 4) عند استخدام routes ومعاملات (arguments): تأكد أنك ترسل بيانات صحيحة وإلا استخدم فحص null قبل الاستخدام.
// 5) لتبديل اللغة أثناء التشغيل: اجعل هناك زر في واجهة القائمة يستدعي onToggleLocale (الدالة toggleLocale).
// 6) إذا أردت أن ترسل الأخطاء لتطبيق خارجي (مثل Sentry)، أضف الكود في المكان الذي يوجد فيه debugPrint('UNCAUGHT ERROR').
//قاعدة ذهبية
//نوع_البيان اسم الحاجه = القيمة;
// int age = 30;
// String name = "Ahmad";
//double price = 19.99;
// ---------------------------
