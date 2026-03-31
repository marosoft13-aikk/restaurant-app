import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../pages/signup_page.dart' as myAuth;
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';

// صفحات التوجيه
import '../pages/driver_page.dart';
import '../pages/restaurant_home_page.dart';
import '../pages/video_welcome.dart';
import '../pages/admin_dashboard_page.dart';

// About page
import 'about_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isArabic = true;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool loading = false;

  // 🔥 SAVE FCM TOKEN AFTER LOGIN
  Future<void> saveUserToken(String uid) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .set({"fcmToken": token}, SetOptions(merge: true));

        debugPrint("🔥 FCM Token saved: $token");
      } else {
        debugPrint("⚠️ No FCM token found");
      }
    } catch (e, st) {
      debugPrint("❌ Error saving FCM token: $e");
      debugPrint("$st");
    }
  }

  // مشترَك بعد تسجيل الدخول
  Future<void> postSignIn(User user) async {
    Provider.of<UserProvider>(context, listen: false).setUser(user);

    debugPrint("LOGIN SUCCESS uid=${user.uid} email=${user.email}");

    final userDocRef =
        FirebaseFirestore.instance.collection("users").doc(user.uid);
    final snap = await userDocRef.get();

    if (!snap.exists) {
      await userDocRef.set({
        "uid": user.uid,
        "email": user.email ?? "",
        "name": user.displayName ?? "",
        "phone": "",
        "role": "client",
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("Created Firestore user doc for ${user.uid}");
    }

    await saveUserToken(user.uid);

    final data = (await userDocRef.get()).data();
    debugPrint("FIRESTORE DATA = $data");

    String role = (data?["role"] ?? "client").toString().trim().toLowerCase();

    debugPrint("ROLE = $role");

    if (!mounted) return;

    if (role == "driver") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DriverPage()));
    } else if (role == "restaurant") {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const RestaurantHomePage()));
    } else if (role == "admin") {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const VideoWelcomePage()));
    }
  }

  // تسجيل دخول بالإيميل وكلمة المرور (أي يوزر مسجّل في Firebase)
  Future<void> loginUser() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCred.user;

      if (user == null) {
        throw FirebaseAuthException(
            code: 'null-user', message: 'Sign in returned null user');
      }

      await postSignIn(user);
    } on FirebaseAuthException catch (e) {
      String msg = isArabic ? "حصل خطأ أثناء تسجيل الدخول" : "Login error";

      if (e.code == 'user-not-found') {
        msg = isArabic ? "البريد الإلكتروني غير مسجَّل" : "User not found";
      } else if (e.code == 'wrong-password') {
        msg = isArabic ? "كلمة المرور غير صحيحة" : "Wrong password";
      } else if (e.code == 'invalid-email') {
        msg = isArabic ? "البريد الإلكتروني غير صالح" : "Invalid email";
      } else if (e.code == 'user-disabled') {
        msg = isArabic ? "تم تعطيل الحساب" : "User disabled";
      } else {
        msg = e.message ?? msg;
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      debugPrint("❌ Unexpected error during login: $e");
      debugPrint("$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isArabic
                  ? "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا"
                  : "Unexpected error occurred, please try again")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // تسجيل الدخول التلقائي مُزال: لا نستخدم مستمع authStateChanges هنا بعد الآن.
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF9800), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => setState(() => isArabic = !isArabic),
                    child: Text(isArabic ? "EN" : "AR"),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            Image.asset("assets/images/brostaky.png",
                                height: 140),
                            const SizedBox(height: 20),
                            Text(
                              isArabic
                                  ? "بروست بنكهة سعودية!"
                                  : "Broast with Saudi flavor!",
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),

                            // EMAIL
                            TextFormField(
                              controller: emailController,
                              validator: (v) => v != null && v.contains("@")
                                  ? null
                                  : (isArabic
                                      ? "الرجاء إدخال بريد إلكتروني صالح"
                                      : "Please enter a valid email"),
                              textAlign:
                                  isArabic ? TextAlign.right : TextAlign.left,
                              decoration: inputDec(
                                hint: isArabic ? "البريد الإلكتروني" : "Email",
                                icon: Icons.email,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              enabled: true,
                            ),

                            const SizedBox(height: 16),

                            // PASSWORD
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              validator: (v) => v != null && v.length >= 6
                                  ? null
                                  : (isArabic
                                      ? "يجب أن تكون كلمة المرور 6 أحرف أو أكثر"
                                      : "Password must be at least 6 characters"),
                              textAlign:
                                  isArabic ? TextAlign.right : TextAlign.left,
                              decoration: inputDec(
                                hint: isArabic ? "كلمة المرور" : "Password",
                                icon: Icons.lock,
                              ),
                              enabled: true,
                            ),

                            const SizedBox(height: 22),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 80, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: loading ? null : loginUser,
                              child: loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      isArabic ? "تسجيل الدخول" : "Login",
                                      style: const TextStyle(fontSize: 18),
                                    ),
                            ),

                            const SizedBox(height: 12),

                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      myAuth.SignUpPage(isArabic: isArabic),
                                ),
                              ),
                              child: Text(
                                isArabic
                                    ? "لا تمتلك حسابًا؟ سجّل الآن"
                                    : "Don't have an account? Sign up",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // MARO SOFT and About link (about in English directly under MARO SOFT, with small spacing)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "MARO SOFT",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                                const SizedBox(height: 2), // very close
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AboutPageCinematic(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    "about",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration inputDec({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.orange),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }
}
