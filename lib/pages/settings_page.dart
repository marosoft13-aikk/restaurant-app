import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/user_provider.dart';
import 'admin_dashboard_page.dart';
import 'login_page.dart';
import 'signup_page.dart';

// Added imports for chat/support pages and admin customers page
import 'client_support_page.dart';
import 'admin_customers_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isArabic = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text(
            isArabic ? "الإعدادات ⚙️" : "Settings ⚙️",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            final firebaseUser = authSnap.data;
            // We'll load the Firestore user doc when we have a signed user
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: firebaseUser != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(firebaseUser.uid)
                      .get()
                  : Future.value(null),
              builder: (context, userDocSnap) {
                final userDoc = userDocSnap.data;
                final role =
                    userDoc?.data()?['role']?.toString().trim().toLowerCase();
                final displayName =
                    firebaseUser?.displayName ?? userDoc?.data()?['name'];
                final email = firebaseUser?.email ?? userDoc?.data()?['email'];

                final displayLabel =
                    displayName ?? (isArabic ? 'زائر' : 'Guest');
                final emailLabel =
                    email ?? (isArabic ? 'غير مسجل' : 'Not signed in');

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.orange[100],
                          child: const Icon(Icons.person,
                              size: 70, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: Text(
                          displayLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Center(
                          child: Text(emailLabel,
                              style: const TextStyle(fontSize: 16))),
                      const SizedBox(height: 30),
                      const Divider(),

                      // Toggle language (local only)
                      SwitchListTile(
                        title:
                            Text(isArabic ? "تغيير اللغة" : "Change Language"),
                        subtitle: Text(isArabic ? "العربية" : "English"),
                        value: isArabic,
                        activeColor: Colors.orange,
                        onChanged: (value) {
                          setState(() {
                            isArabic = value;
                          });
                        },
                      ),
                      const Divider(),

                      // Delivery address (editable; saved to users/{uid}.address if signed in)
                      ListTile(
                        leading: const Icon(Icons.home, color: Colors.orange),
                        title: Text(
                            isArabic ? "عنوان التوصيل" : "Delivery Address"),
                        subtitle: Text(
                            userDoc?.data()?['address']?.toString() ??
                                "Banha, Qalyubia, Egypt"),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _editAddress(firebaseUser),
                      ),
                      const Divider(),

                      const SizedBox(height: 20),
                      Text(
                        isArabic ? "📍 فروعنا" : "📍 Our Branches",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Branch cards are rendered from a local list for display.
                      // To edit branches use the Admin Dashboard (visible only to admins).
                      _buildBranchCard(
                        title: isArabic ? "الفرع الأول" : "Branch 1",
                        address: isArabic
                            ? "كفر تصفا - البوفيه مقابل صيدلية أم أحمد"
                            : "Kafr Tasfa - Buffet opposite Umm Ahmed Pharmacy",
                        phones: const ["01122256344"],
                      ),
                      _buildBranchCard(
                        title: isArabic ? "الفرع الثاني" : "Branch 2",
                        address: isArabic
                            ? "الفحص فود كورت ريفيرا بجوار ترافيل - الفلل"
                            : "El Fakhkh - Rivera Food Court next to Travel - Villas",
                        phones: const ["01034104484", "01040520585"],
                      ),
                      _buildBranchCard(
                        title: isArabic ? "الفرع الثالث" : "Branch 3",
                        address: isArabic
                            ? "بنها الاستاد - شارع مستشفى الأمل بجوار كافيه ريحانة"
                            : "Banha Stadium - Al-Amal Hospital St., next to Rehana Cafe",
                        phones: const ["01040520585", "01555488133"],
                      ),
                      _buildBranchCard(
                        title: isArabic ? "الفرع الرابع" : "Branch 4",
                        address: isArabic
                            ? "كفر شكر - عبد المنعم رياض بجوار البنك الأهلي - أسفل معمل المختبر"
                            : "Kafr Shukr - Abdel Moneim Riad St., next to National Bank, below Al Mokhtabar Lab",
                        phones: const ["01019747170", "01101189333"],
                      ),

                      const SizedBox(height: 30),
                      const Divider(),

                      // CHAT / SUPPORT entry - visible to everyone.
                      ListTile(
                        leading: const Icon(Icons.chat, color: Colors.orange),
                        title:
                            Text(isArabic ? "الدعم والشات" : "Support & Chat"),
                        subtitle: Text(isArabic
                            ? "افتح المحادثة مع الدعم أو إدارة العملاء"
                            : "Open chat with support or admin panel"),
                        onTap: () {
                          // If the user is admin -> open admin customers page (admin can chat with any user)
                          // Otherwise open client support page where user can chat with admin/support.
                          if (role == 'admin') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AdminCustomersPage()),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ClientSupportPage()),
                            );
                          }
                        },
                      ),
                      const Divider(),

                      // Manage branches - only visible for admin users
                      if (role == 'admin') ...[
                        ListTile(
                          leading:
                              const Icon(Icons.apartment, color: Colors.orange),
                          title: Text(
                              isArabic ? "إدارة الفروع" : "Manage Branches"),
                          subtitle: Text(isArabic
                              ? "تحديث بيانات الفروع"
                              : "Edit branch information (admin)"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AdminDashboardPage()),
                            );
                          },
                        ),
                        const Divider(),
                      ],

                      // Authentication actions
                      if (firebaseUser == null) ...[
                        // Not signed in: show Login and Sign up
                        ListTile(
                          leading: const Icon(Icons.login, color: Colors.blue),
                          title: Text(isArabic ? "تسجيل الدخول" : "Login"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginPage()),
                            );
                          },
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.person_add, color: Colors.green),
                          title: Text(isArabic ? "إنشاء حساب" : "Sign up"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      SignUpPage(isArabic: isArabic)),
                            );
                          },
                        ),
                      ] else ...[
                        // Signed in: only show logout (edit profile removed per request)
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: Text(isArabic ? "تسجيل الخروج" : "Logout"),
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            // Try to clear provider user state safely (dynamic call as fallback)
                            try {
                              (userProvider as dynamic).clearUser();
                            } catch (_) {
                              try {
                                (userProvider as dynamic).setUser(null);
                              } catch (_) {}
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(isArabic
                                          ? "تم تسجيل الخروج"
                                          : "Signed out")));
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editAddress(User? user) async {
    final controller = TextEditingController();
    String initial = "Banha, Qalyubia, Egypt";
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      initial = doc.data()?['address']?.toString() ?? initial;
    }
    controller.text = initial;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit delivery address'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Enter address'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );

    if (result == null) return;

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'address': result,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Address saved'), backgroundColor: Colors.green));
          setState(() {}); // refresh UI to show saved address
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Save failed: $e'), backgroundColor: Colors.red));
        }
      }
    } else {
      // user not signed in — just show confirmation (not persisted)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Address updated locally'),
            backgroundColor: Colors.orange));
        setState(() {});
      }
    }
  }

  Widget _buildBranchCard({
    required String title,
    required String address,
    required List<String> phones,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.orange, size: 20),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(address,
                        style: GoogleFonts.poppins(fontSize: 15))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone, color: Colors.green, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: phones
                        .map((p) =>
                            Text(p, style: GoogleFonts.poppins(fontSize: 15)))
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
