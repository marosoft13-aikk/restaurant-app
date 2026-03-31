import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// صفحة رفع إيصال الدفع — الآن تعرض رقمي Instapay و Vodafone Cash مع زر لاستبدال الاختيار.
/// الأرقام تبقى موجودة دائماً، والزر "استبدال" يبدّل فقط الطريقة المحددة.
class OnlinePaymentPage extends StatefulWidget {
  final double amount;
  final String orderId;

  const OnlinePaymentPage({
    super.key,
    required this.amount,
    required this.orderId,
  });

  @override
  State<OnlinePaymentPage> createState() => _OnlinePaymentPageState();
}

class _OnlinePaymentPageState extends State<OnlinePaymentPage> {
  // الطريقة المحددة حالياً
  String selectedMethod = "Instapay";
  File? receiptImage;
  bool uploading = false;
  final TextEditingController txNumberCtrl = TextEditingController();
  final TextEditingController payerPhoneCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // ---------- CLOUDINARY (UNSIGNED) CONFIG ----------
  static const bool useCloudinary = true;
  static const String cloudName = "dhn7dcwej"; // ضع هنا cloud name الخاص بك
  static const String uploadPreset =
      "unsigned_preset"; // اسم الـ unsigned preset لديك
  // --------------------------------------------------

  // الأرقام المخزنة (ستبقى كما هي)
  final Map<String, String> paymentNumbers = {
    "Instapay": "+20 10 16610399",
    "Vodafone Cash": "+201113331253",
  };

  Future<void> pickImage() async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        setState(() => receiptImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('pickImage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل اختيار الصورة')));
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نسخ الرقم')));
    }
  }

  Future<String> uploadToCloudinaryUnsigned(File file) async {
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      final data = json.decode(body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null) {
        throw Exception('Cloudinary response missing secure_url');
      }
      return secureUrl;
    } else {
      String friendly = 'Cloudinary upload failed (${streamed.statusCode})';
      try {
        final err = json.decode(body);
        if (err is Map && err['error'] != null) {
          final e = err['error'];
          if (e is Map && e['message'] != null) {
            friendly = e['message'];
          } else if (e is String) {
            friendly = e;
          }
        }
      } catch (_) {}
      throw Exception(friendly);
    }
  }

  Future<void> uploadPayment() async {
    final method = selectedMethod;
    final tx = txNumberCtrl.text.trim();

    if (method.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("اختر طريقة الدفع")));
      return;
    }

    if (tx.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("أدخل رقم التحويل / المرجع")));
      return;
    }

    if (receiptImage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("ارفع صورة الإيصال")));
      return;
    }

    setState(() => uploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'anonymous';
      final userEmail = user?.email ?? '';

      String imageUrl;

      if (useCloudinary) {
        imageUrl = await uploadToCloudinaryUnsigned(receiptImage!);
        debugPrint('Cloudinary unsigned upload succeeded: $imageUrl');
      } else {
        throw Exception('Firebase Storage upload not enabled in this build.');
      }

      final receiptsCol = FirebaseFirestore.instance.collection('receipts');
      final docRef = receiptsCol.doc();

      final docData = {
        'id': docRef.id,
        'userId': uid,
        'userEmail': userEmail,
        'orderId': widget.orderId,
        'amount': widget.amount,
        'method': method,
        'merchantNumber': paymentNumbers[method] ?? '',
        'transactionNumber': tx,
        'payerPhone': payerPhoneCtrl.text.trim(),
        'imageUrl': imageUrl,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await docRef.set(docData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✔ تم إرسال الإيصال بنجاح")));
      }

      if (mounted) Navigator.pop(context, {'receiptId': docRef.id});
    } catch (e, st) {
      debugPrint('uploadPayment error: $e\n$st');
      final msg = e.toString().toLowerCase();
      if (msg.contains('upload preset') || msg.contains('unsigned')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'خطأ: تأكد أن الـ upload preset مفعل كـ Unsigned واسمه مضبوط في الكود.')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("فشل رفع الإيصال: $e")));
        }
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  // دالة تبديل الاختيار بين الطريقتين (تبديل الطريقة المحددة فقط)
  void _toggleSelectedMethod() {
    setState(() {
      selectedMethod =
          (selectedMethod == 'Instapay') ? 'Vodafone Cash' : 'Instapay';
    });
  }

  @override
  void dispose() {
    txNumberCtrl.dispose();
    payerPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantNumber = paymentNumbers[selectedMethod] ?? '-';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        title: const Text("الدفع الإلكتروني",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Order ID',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(widget.orderId,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('${widget.amount.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 18)),
                        ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // عرض كل الأرقام (Instapay و Vodafone) كمقالات منفصلة،
            // مع مؤشر اختياري (Radio) و زر نسخ لكل واحد.
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  ListTile(
                    leading: Radio<String>(
                      value: 'Instapay',
                      groupValue: selectedMethod,
                      onChanged: (v) {
                        if (v != null) setState(() => selectedMethod = v);
                      },
                    ),
                    title: const Text('Instapay'),
                    subtitle: Text(paymentNumbers['Instapay'] ?? '-'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.orange),
                      onPressed: () =>
                          _copyToClipboard(paymentNumbers['Instapay'] ?? ''),
                    ),
                    onTap: () => setState(() => selectedMethod = 'Instapay'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Radio<String>(
                      value: 'Vodafone Cash',
                      groupValue: selectedMethod,
                      onChanged: (v) {
                        if (v != null) setState(() => selectedMethod = v);
                      },
                    ),
                    title: const Text('Vodafone Cash'),
                    subtitle: Text(paymentNumbers['Vodafone Cash'] ?? '-'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.orange),
                      onPressed: () => _copyToClipboard(
                          paymentNumbers['Vodafone Cash'] ?? ''),
                    ),
                    onTap: () =>
                        setState(() => selectedMethod = 'Vodafone Cash'),
                  ),
                  // زر استبدال سريع في أسفل البطاقة
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _toggleSelectedMethod,
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('استبدال'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 12),

            // عرض الرقم المختار في بطاقة مميزة (معلومات سريعة)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade100)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(merchantNumber,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.orange),
                    onPressed: () {
                      _copyToClipboard(merchantNumber);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: txNumberCtrl,
              decoration: InputDecoration(
                labelText: 'رقم التحويل / المرجع',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon:
                    const Icon(Icons.confirmation_number, color: Colors.orange),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: payerPhoneCtrl,
              decoration: InputDecoration(
                labelText: 'رقم المرسل (اختياري)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.phone, color: Colors.orange),
                hintText: '+2011XXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: pickImage,
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: 120, maxHeight: 240),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: receiptImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.upload_file,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('اضغط لرفع صورة الإيصال'),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(receiptImage!,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: uploading ? null : uploadPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: uploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('✔ تأكيد ورفع الإيصال',
                      style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
