// Improved SignUpPage: Google (mobile + web) and Facebook (mobile + web)
// - For Google on web we use FirebaseAuth.signInWithPopup to avoid needing a
//   hard-coded web client id in this file.
// - For Facebook on web we also use FirebaseAuth.signInWithPopup (requires
//   Facebook app + JS SDK configured in index.html). On mobile we use
//   flutter_facebook_auth to get token then sign-in with Firebase credential.
//
// Make sure you still complete the Firebase + Google + Facebook platform
// setup (Android/iOS/Web). See notes below after the file.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Google
import 'package:google_sign_in/google_sign_in.dart';

// Facebook
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../pages/video_welcome.dart';

class SignUpPage extends StatefulWidget {
  final bool isArabic;

  const SignUpPage({super.key, required this.isArabic});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool loading = false;
  bool _obscure = true;

  // Set to false to hide the Facebook button (as requested).
  // Change to true if you want to show Facebook button again.
  final bool showFacebook = false;

  bool get isArabic => widget.isArabic;

  Future<void> saveUserToken(String uid) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .set({"fcmToken": token}, SetOptions(merge: true));
        debugPrint("🔥 User token saved: $token");
      }
    } catch (e) {
      debugPrint("❌ Error saving token: $e");
    }
  }

  Future<void> saveUserData(User user) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "name": nameController.text.isEmpty
            ? (user.displayName ?? "")
            : nameController.text.trim(),
        "email": user.email ?? "",
        "role": "user",
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("❌ saveUserData failed: $e");
    }
  }

  void _goToVideoPage() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VideoWelcomePage()),
    );
  }

  String? _validateEmail(String email) {
    if (email.isEmpty)
      return isArabic ? 'أدخل البريد الإلكتروني' : 'Enter email';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      return isArabic ? 'بريد إلكتروني غير صالح' : 'Invalid email';
    }
    return null;
  }

  String? _validatePassword(String pass) {
    if (pass.isEmpty) return isArabic ? 'أدخل كلمة المرور' : 'Enter password';
    if (pass.length < 6)
      return isArabic ? 'كلمة المرور قصيرة (6+)' : 'Password too short (6+)';
    return null;
  }

  Future<void> signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = emailController.text.trim();
    final pass = passwordController.text;
    final name = nameController.text.trim();

    setState(() => loading = true);
    try {
      UserCredential userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = userCred.user!;
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      await saveUserData(user);
      await saveUserToken(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isArabic
                  ? "تم إنشاء الحساب بنجاح"
                  : "Account created successfully")),
        );
        _goToVideoPage();
      }
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? (isArabic ? "حدث خطأ" : "Error");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(isArabic ? "حدث خطأ" : "$e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> signUpWithGoogle() async {
    setState(() => loading = true);
    try {
      if (kIsWeb) {
        // On web use the Firebase popup flow (no local google_sign_in web client id required here).
        final provider = GoogleAuthProvider();
        // add scopes if needed: provider.addScope('email');
        final UserCredential userCred =
            await FirebaseAuth.instance.signInWithPopup(provider);
        final user = userCred.user!;
        await saveUserData(user);
        await saveUserToken(user.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isArabic
                    ? "تم التسجيل بواسطة Google"
                    : "Signed up with Google")),
          );
          _goToVideoPage();
        }
      } else {
        // Mobile / desktop flow using google_sign_in package
        final GoogleSignIn googleSignIn =
            GoogleSignIn(scopes: ['email', 'profile']);

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // user cancelled
          if (mounted) setState(() => loading = false);
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        final UserCredential userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);

        final user = userCred.user!;
        await saveUserData(user);
        await saveUserToken(user.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isArabic
                    ? "تم التسجيل بواسطة Google"
                    : "Signed up with Google")),
          );
          _goToVideoPage();
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException Google: ${e.code} ${e.message}');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? "$e")));
    } catch (e, st) {
      debugPrint('Exception during Google sign-up: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Robust Facebook sign-in flow (web + mobile)
  Future<void> signUpWithFacebook() async {
    setState(() => loading = true);
    try {
      if (kIsWeb) {
        // On web use Firebase popup provider (requires FB JS SDK + appId configured in index.html)
        final provider = FacebookAuthProvider();
        // provider.addScope('email'); // add scopes if needed
        final UserCredential userCred =
            await FirebaseAuth.instance.signInWithPopup(provider);

        final user = userCred.user!;
        await saveUserData(user);
        await saveUserToken(user.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isArabic
                  ? "تم التسجيل بواسطة Facebook"
                  : "Signed up with Facebook")));
          _goToVideoPage();
        }
      } else {
        // Mobile/native flow using flutter_facebook_auth to get token, then sign-in with Firebase
        debugPrint('🔵 Starting Facebook login (mobile/native)...');
        final LoginResult result = await FacebookAuth.instance
            .login(permissions: ['email', 'public_profile']);

        debugPrint(
            '🔵 Facebook login result: ${result.status} - ${result.message}');

        if (result.status == LoginStatus.success) {
          // accessToken can be different shapes depending on package version; handle robustly
          String? token;
          try {
            final accessTokenObj = result.accessToken;
            if (accessTokenObj == null) {
              token = null;
            } else {
              // common shape: AccessToken { token: '...' }
              try {
                token = (accessTokenObj as dynamic).token as String?;
              } catch (_) {
                try {
                  // older shapes might expose 'accessToken' or be a Map
                  final maybeMap = accessTokenObj as dynamic;
                  if (maybeMap is Map) {
                    token = (maybeMap['token'] ?? maybeMap['accessToken'])
                        as String?;
                  } else {
                    token = null;
                  }
                } catch (_) {
                  token = null;
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error extracting FB token: $e');
            token = null;
          }

          if (token == null || token.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isArabic
                      ? "فشل الحصول على توكن فيسبوك"
                      : "Failed to get Facebook token")));
            }
            return;
          }

          final fbCredential = FacebookAuthProvider.credential(token);

          try {
            final UserCredential userCred =
                await FirebaseAuth.instance.signInWithCredential(fbCredential);

            final user = userCred.user!;
            await saveUserData(user);
            await saveUserToken(user.uid);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isArabic
                      ? "تم التسجيل بواسطة Facebook"
                      : "Signed up with Facebook")));
              _goToVideoPage();
            }
          } on FirebaseAuthException catch (e) {
            debugPrint(
                'FirebaseAuthException during FB sign-in: ${e.code} ${e.message}');
            if (e.code == 'account-exists-with-different-credential') {
              final email = e.email;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isArabic
                        ? "هناك حساب مرتبط بنفس البريد بموفر آخر. سجّل الدخول وادمج الحسابات."
                        : "An account already exists with the same email with a different sign-in method. Please sign in with that provider and link accounts.")));
              }
              if (email != null) {
                try {
                  final methods = await (FirebaseAuth.instance as dynamic)
                      .fetchSignInMethodsForEmail(email);
                  debugPrint('Sign-in methods for $email: $methods');
                } catch (inner) {
                  debugPrint('⚠️ Could not fetch sign-in methods: $inner');
                }
              }
            } else {
              if (mounted)
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.message ?? "$e")));
            }
          }
        } else if (result.status == LoginStatus.cancelled) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isArabic ? "ألغيت العملية" : "Cancelled")));
        } else {
          final message = result.message ??
              (isArabic ? "فشل تسجيل فيسبوك" : "Facebook sign-in failed");
          if (mounted)
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException outer: ${e.code} ${e.message}');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? "$e")));
    } catch (e, st) {
      debugPrint('Exception during Facebook sign-up: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Widget _socialButton({
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required Widget icon,
    required String label,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: iconColor,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: loading ? null : onTap,
      icon: icon,
      label: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = 12.0;
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? "إنشاء حساب" : "Create Account"),
        backgroundColor: Colors.orange,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isArabic ? "مرحبا بك" : "Welcome",
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.orange,
                      child: const Icon(Icons.restaurant,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
                SizedBox(height: spacing),

                // Card with form
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nameController,
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                            decoration: InputDecoration(
                              labelText: isArabic ? "الاسم" : "Name",
                              prefixIcon: const Icon(Icons.person),
                            ),
                            validator: (v) {
                              return null; // name optional
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: emailController,
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: isArabic
                                  ? "البريد الإلكتروني"
                                  : "Email Address",
                              prefixIcon: const Icon(Icons.email),
                            ),
                            validator: (v) => _validateEmail(v?.trim() ?? ''),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: passwordController,
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                            decoration: InputDecoration(
                              labelText: isArabic ? "كلمة المرور" : "Password",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            obscureText: _obscure,
                            validator: (v) => _validatePassword(v ?? ''),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : signUpWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                  isArabic ? "إنشاء الحساب" : "Create Account",
                                  style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Social sign-in
                Text(isArabic ? "أو التسجيل بواسطة:" : "Or sign up with:",
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),

                // Layout: if Facebook is hidden, show Google button full-width and centered.
                if (!showFacebook) ...[
                  SizedBox(
                    width: double.infinity,
                    child: _socialButton(
                      color: const Color(0xFFDB4437),
                      iconColor: Colors.white,
                      onTap: signUpWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, color: Colors.white),
                      label: 'Google',
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _socialButton(
                          color: const Color(0xFFDB4437),
                          iconColor: Colors.white,
                          onTap: signUpWithGoogle,
                          icon: const Icon(Icons.g_mobiledata,
                              color: Colors.white),
                          label: 'Google',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _socialButton(
                          color: const Color(0xFF1877F2),
                          iconColor: Colors.white,
                          onTap: signUpWithFacebook,
                          icon: const Icon(Icons.facebook, color: Colors.white),
                          label: 'Facebook',
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Terms / small note
                Text(
                  isArabic
                      ? "بالاستمرار أنت توافق على الشروط وسياسة الخصوصية."
                      : "By continuing you agree to the Terms & Privacy Policy.",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // loading overlay
          if (loading)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
