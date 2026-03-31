import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

class EditOfferPage extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;

  const EditOfferPage({
    super.key,
    required this.id,
    required this.data,
  });

  @override
  State<EditOfferPage> createState() => _EditOfferPageState();
}

class _EditOfferPageState extends State<EditOfferPage> {
  late TextEditingController title;
  late TextEditingController desc;
  late TextEditingController discount;

  String imageUrl = "";
  File? newImage;

  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.data["title"]);
    desc = TextEditingController(text: widget.data["desc"]);
    discount = TextEditingController(text: widget.data["discount"]);
    imageUrl = widget.data["image"];
  }

  // --------------------------------------------------------
  // 📸 اختيار صورة جديدة
  // --------------------------------------------------------
  Future pickImage() async {
    final XFile? img =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => newImage = File(img.path));
    }
  }

  // --------------------------------------------------------
  // 🔥 رفع الصورة إلى Cloudinary
  // --------------------------------------------------------
  Future<String> uploadToCloudinary(File imageFile) async {
    const cloudName = "dhn7dcwej"; // ← Cloud Name بتاعك
    const preset = "unsigned_preset"; // ← Upload Preset

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
  // 💾 حفظ التعديلات
  // --------------------------------------------------------
  Future<void> saveChanges() async {
    setState(() => isUploading = true);

    String finalImageUrl = imageUrl;

    // لو المستخدم اختار صورة جديدة → نرفعها
    if (newImage != null) {
      finalImageUrl = await uploadToCloudinary(newImage!);
    }

    // نحافظ على createdAt زي ما هو
    final createdAt = widget.data["createdAt"] ?? Timestamp.now();

    await FirebaseFirestore.instance
        .collection("offers")
        .doc(widget.id)
        .update({
      "title": title.text.trim(),
      "desc": desc.text.trim(),
      "discount": discount.text.trim(),
      "image": finalImageUrl,
      "createdAt": createdAt,
    });

    setState(() => isUploading = false);
    Navigator.pop(context);
  }

  // --------------------------------------------------------
  // 🎨 الواجهة UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تعديل العرض", style: GoogleFonts.cairo()),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: newImage == null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(imageUrl, fit: BoxFit.cover),
                        )
                      : Image.file(newImage!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: "عنوان العرض"),
                textDirection: TextDirection.rtl,
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: "الوصف"),
                textDirection: TextDirection.rtl,
              ),
              TextField(
                controller: discount,
                decoration: const InputDecoration(labelText: "الخصم"),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isUploading ? null : saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                child: isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "حفظ التعديلات",
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
