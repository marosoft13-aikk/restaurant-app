import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class PaymentPage extends StatefulWidget {
  final String orderId;
  final double totalAmount;

  const PaymentPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  File? selectedReceipt;
  bool uploading = false;
  final picker = ImagePicker();

  final TextEditingController accountController =
      TextEditingController(); // رقم التحويل المدخل من المستخدم
  final TextEditingController payerPhoneController =
      TextEditingController(); // رقم مُرسل الدفع (اختياري)
  final TextEditingController notesController = TextEditingController();

  // Cloudinary config (أدخل القيم الحقيقية لديك)
  static const String _cloudName = 'dhn7dcwej';
  static const String _uploadPreset =
      'unsigned_preset'; // تأكد من وجود unsigned preset أو استخدم توقيع server-side

  Future<void> pickImage() async {
    final XFile? img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      setState(() => selectedReceipt = File(img.path));
    }
  }

  Future<String?> uploadToCloudinary(File image) async {
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final req = http.MultipartRequest('POST', uri);
    req.fields['upload_preset'] = _uploadPreset;
    req.files.add(await http.MultipartFile.fromPath('file', image.path));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['secure_url'] as String?;
    } else {
      debugPrint('Cloudinary upload failed: $body');
      return null;
    }
  }

  Future<void> submitReceipt() async {
    final txNumber = accountController.text.trim();
    if (txNumber.isEmpty) {
      _showSnack(
          isArabic
              ? 'من فضلك أدخل رقم التحويل'
              : 'Please enter the transaction number',
          color: Colors.red);
      return;
    }
    if (selectedReceipt == null) {
      _showSnack(
          isArabic
              ? 'من فضلك اختر صورة الإيصال'
              : 'Please select receipt image',
          color: Colors.red);
      return;
    }

    setState(() => uploading = true);

    final imageUrl = await uploadToCloudinary(selectedReceipt!);
    if (imageUrl == null) {
      setState(() => uploading = false);
      _showSnack(isArabic ? 'فشل رفع الإيصال' : 'Receipt upload failed',
          color: Colors.red);
      return;
    }

    try {
      final docRef =
          await FirebaseFirestore.instance.collection('receipts').add({
        'orderId': widget.orderId,
        'imageUrl': imageUrl,
        'amount': widget.totalAmount,
        'paymentNumber': txNumber,
        'payerPhone': payerPhoneController.text.trim(),
        'method': 'Vodafone Cash / InstaPay', // أو اختر القيمة المناسبة
        'status': 'pending',
        'notes': notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Option A (مُوصى به): إرسال SMS من الخادم (Cloud Function) عند إنشاء هذا المستند.
      // Option B (بديل محلي): افتح تطبيق الرسائل للمستخدم ليرسل إشعاراً للتاجر يدوياً
      //
      // هنا نستعمل الخيار الموصى: Cloud Function ستراقب collection 'receipts' وترسل SMS.
      // لذا لا نحتاج لعمل شيء إضافي هنا. لكن يمكنك أيضاً استدعاء Function مباشرة عبر HTTP إذا رغبت.

      setState(() => uploading = false);
      _showSnack(
          isArabic ? 'تم رفع الإيصال بنجاح' : 'Receipt uploaded successfully',
          color: Colors.green);

      // إغلاق الصفحة والرجوع أو إظهار تفاصيل الطلب
      Navigator.pop(context, {'receiptId': docRef.id});
    } catch (e) {
      setState(() => uploading = false);
      _showSnack(isArabic ? 'فشل حفظ الإيصال' : 'Failed to save receipt',
          color: Colors.red);
      debugPrint('Firestore save failed: $e');
    }
  }

  bool get isArabic => true; // غيّر إن أردت التحكم بلغات

  void _showSnack(String text, {Color color = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: color));
  }

  @override
  void dispose() {
    accountController.dispose();
    payerPhoneController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text(isArabic ? "رفع الإيصال" : "Upload Receipt",
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                              isArabic ? 'إجمالي الدفع' : 'Total amount',
                              style: GoogleFonts.cairo(
                                  fontSize: 14, fontWeight: FontWeight.w600))),
                      Text('${widget.totalAmount.toStringAsFixed(2)} ج.م',
                          style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(isArabic ? 'Order ID: ' : 'Order ID: ',
                      style:
                          GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                  Text(widget.orderId, style: GoogleFonts.cairo(fontSize: 12)),
                ]),
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: accountController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: isArabic
                    ? 'رقم التحويل (Transaction ID)'
                    : 'Transaction number',
                hintText: 'مثال: 123456789',
                prefixIcon:
                    const Icon(Icons.confirmation_number, color: Colors.orange),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: payerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: isArabic
                    ? 'رقم المرسل (اختياري)'
                    : 'Payer phone (optional)',
                hintText: '+2011xxxxxxx',
                prefixIcon: const Icon(Icons.phone, color: Colors.orange),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isArabic ? 'ملاحظات (اختياري)' : 'Notes (optional)',
                prefixIcon: const Icon(Icons.note, color: Colors.orange),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 18),

            GestureDetector(
              onTap: pickImage,
              child: DottedBorderContainer(
                child: selectedReceipt == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                size: 38, color: Colors.orange),
                            const SizedBox(height: 8),
                            Text(
                                isArabic
                                    ? 'اضغط لاختيار صورة الإيصال'
                                    : 'Tap to select receipt image',
                                style:
                                    GoogleFonts.cairo(color: Colors.black54)),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(selectedReceipt!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover)),
              ),
            ),

            const SizedBox(height: 20),

            uploading
                ? Center(
                    child: Column(children: const [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 8),
                    Text('Uploading...')
                  ]))
                : ElevatedButton.icon(
                    onPressed: submitReceipt,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                        isArabic
                            ? 'رفع الإيصال وإرسال إشعار'
                            : 'Upload receipt & notify',
                        style: GoogleFonts.cairo()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

            const SizedBox(height: 12),

            // Alternative: quick SMS composer for manual notification (client-side)
            TextButton.icon(
              onPressed: () {
                // open SMS app with prefilled message (client-side fallback)
                final msg = Uri.encodeComponent(
                    'New receipt uploaded for order ${widget.orderId}. Tx: ${accountController.text.trim()}');
                final phone = '+201113331253'; // merchant number you provided
                final uri = Uri.parse('sms:$phone?body=$msg');
                launchUrlExternal(uri.toString());
              },
              icon: const Icon(Icons.sms, color: Colors.orange),
              label: Text(
                  isArabic
                      ? 'إرسال إشعار يدويًا (SMS)'
                      : 'Send manual SMS notification',
                  style: GoogleFonts.cairo(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );
  }

  void launchUrlExternal(String url) async {
    // fallback method to open URL (SMS composer)
    // Use url_launcher package in your project.
    // Example:
    // final uri = Uri.parse(url); await launchUrl(uri);
    // Here we use basic approach:
    // NOTE: Make sure to add url_launcher dependency and use launchUrl
    debugPrint('Open URL: $url');
  }
}

/// small UI helper - dotted border container (simple)
class DottedBorderContainer extends StatelessWidget {
  final Widget child;
  const DottedBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.orange.withOpacity(0.6), width: 1.6)),
      child: child,
    );
  }
}
