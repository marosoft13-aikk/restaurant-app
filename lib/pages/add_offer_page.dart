import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

class AddOfferPage extends StatefulWidget {
  const AddOfferPage({super.key});

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final discountController = TextEditingController();

  File? imageFile;
  bool loading = false;

  final ImagePicker _picker = ImagePicker();

  // --------------------------------------------------------
  // 🔥 دالة رفع الصور إلى Cloudinary
  // --------------------------------------------------------
  Future<String> uploadToCloudinary(File imageFile) async {
    const cloudName = "dhn7dcwej"; // Cloud Name
    const preset = "unsigned_preset"; // Upload Preset

    final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";

    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(imageFile.path),
      "upload_preset": preset,
    });

    Dio dio = Dio();
    final response = await dio.post(url, data: formData);

    if (response.statusCode == 200) {
      return response.data["secure_url"];
    } else {
      throw "فشل رفع الصورة";
    }
  }

  // --------------------------------------------------------
  // 📸 اختيار الصورة
  // --------------------------------------------------------
  Future pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => imageFile = File(picked.path));
      }
    } catch (e) {
      debugPrint("PICK IMAGE ERROR: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("فشل اختيار الصورة")));
    }
  }

  // --------------------------------------------------------
  // ➕ إضافة العرض
  // --------------------------------------------------------
  Future addOffer() async {
    if (titleController.text.isEmpty ||
        descController.text.isEmpty ||
        discountController.text.isEmpty ||
        imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك املأ جميع البيانات واختر صورة")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // ⬆ رفع الصورة لـ Cloudinary
      final imageUrl = await uploadToCloudinary(imageFile!);

      await FirebaseFirestore.instance.collection("offers").add({
        "title": titleController.text.trim(),
        "desc": descController.text.trim(),
        "discount": discountController.text.trim(),
        "image": imageUrl,
        "createdAt": Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إضافة العرض بنجاح")),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("ADD OFFER ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل إضافة العرض: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // --------------------------------------------------------
  // 🎨 الواجهة UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text("إضافة عرض جديد", style: GoogleFonts.cairo()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: imageFile == null
                      ? const Center(child: Text("اضغط لاختيار صورة"))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(imageFile!, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "عنوان العرض"),
                textDirection: TextDirection.rtl,
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "وصف العرض"),
                textDirection: TextDirection.rtl,
              ),
              TextField(
                controller: discountController,
                decoration: const InputDecoration(labelText: "الخصم"),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: loading ? null : addOffer,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12)),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white))
                    : Text(
                        "إضافة العرض",
                        style: GoogleFonts.cairo(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
