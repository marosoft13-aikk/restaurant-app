import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminCartPage extends StatelessWidget {
  const AdminCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text("إدارة السلة",
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Text(
          "لا توجد عناصر في السلة حالياً",
          style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
