// lib/pages/social_login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'video_welcome.dart';

// Google Sign-In
Future<UserCredential?> signInWithGoogle() async {
  try {
    if (kIsWeb) {
      return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } else {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    }
  } catch (e, st) {
    debugPrint("Google Sign-In Error: $e\n$st");
    return null;
  }
}

// Facebook Sign-In
Future<UserCredential?> signInWithFacebook() async {
  try {
    if (kIsWeb) {
      return await FirebaseAuth.instance
          .signInWithPopup(FacebookAuthProvider());
    } else {
      final result = await FacebookAuth.instance.login();

      if (result.status != LoginStatus.success) return null;

      final credential =
          FacebookAuthProvider.credential(result.accessToken!.tokenString);

      return await FirebaseAuth.instance.signInWithCredential(credential);
    }
  } catch (e, st) {
    debugPrint("Facebook Sign-In Error: $e\n$st");
    return null;
  }
}

class SocialLoginPage extends StatefulWidget {
  const SocialLoginPage({super.key});

  @override
  State<SocialLoginPage> createState() => _SocialLoginPageState();
}

class _SocialLoginPageState extends State<SocialLoginPage> {
  bool loading = false;

  void navigateAfterLogin(User user) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.setUser(user);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VideoWelcomePage()),
    );
  }

  Future<void> handleSocialLogin(
      Future<UserCredential?> Function() loginMethod) async {
    setState(() => loading = true);

    final userCred = await loginMethod();

    setState(() => loading = false);

    if (userCred != null && userCred.user != null) {
      navigateAfterLogin(userCred.user!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل تسجيل الدخول، حاول مرة أخرى")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تسجيل الدخول الاجتماعي"),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.g_mobiledata, color: Colors.red),
              label: const Text("Google"),
              onPressed:
                  loading ? null : () => handleSocialLogin(signInWithGoogle),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(250, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.facebook, color: Colors.white),
              label: const Text("Facebook"),
              onPressed:
                  loading ? null : () => handleSocialLogin(signInWithFacebook),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                minimumSize: const Size(250, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
