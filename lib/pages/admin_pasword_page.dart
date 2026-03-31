import 'package:flutter/material.dart';
import 'admin_dashboard_page.dart';

class AdminPasswordPage extends StatefulWidget {
  const AdminPasswordPage({super.key});

  @override
  State<AdminPasswordPage> createState() => _AdminPasswordPageState();
}

class _AdminPasswordPageState extends State<AdminPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final String adminPassword = "123456"; // ← غيره براحتك

  bool loading = false;
  bool hide = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrange.shade50,
      appBar: AppBar(
        title: const Text("تأكيد كلمة السر"),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(Icons.lock, size: 80, color: Colors.deepOrange.shade300),
                const SizedBox(height: 25),
                Text(
                  "ادخل كلمة السر للدخول للوحة التحكم",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 35),

                // 🔑 TextField
                TextField(
                  controller: passwordController,
                  obscureText: hide,
                  decoration: InputDecoration(
                    labelText: "كلمة السر",
                    prefixIcon:
                        const Icon(Icons.password, color: Colors.deepOrange),
                    suffixIcon: IconButton(
                      icon:
                          Icon(hide ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => hide = !hide),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),

                const SizedBox(height: 25),

                // 🔘 زر الدخول
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 70, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: loading
                      ? null
                      : () {
                          final input = passwordController.text.trim();

                          if (input == adminPassword) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminDashboardPage()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("❌ كلمة المرور غير صحيحة")),
                            );
                          }
                        },
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "دخول",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
