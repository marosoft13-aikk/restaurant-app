import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UploadMenuPage extends StatefulWidget {
  const UploadMenuPage({super.key});

  @override
  State<UploadMenuPage> createState() => _UploadMenuPageState();
}

class _UploadMenuPageState extends State<UploadMenuPage> {
  final titleAr = TextEditingController();
  final titleEn = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final category = TextEditingController();

  File? imageFile;
  bool loading = false;

  Future<String?> uploadToCloudinary(File file) async {
    const cloudName = "dhn7dcwej"; // ← انت اللي بعتهولي
    const uploadPreset = "ml_default"; // ← اللي قولتلي عليه

    final url =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest("POST", url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await request.send();
    final body = await res.stream.bytesToString();
    final data = json.decode(body);

    return data["secure_url"];
  }

  Future<void> saveProduct() async {
    if (imageFile == null) return;

    setState(() => loading = true);

    final imageUrl = await uploadToCloudinary(imageFile!);

    if (imageUrl == null) {
      setState(() => loading = false);
      return;
    }

    final doc = FirebaseFirestore.instance.collection("products").doc();

    final productData = {
      "id": doc.id,
      "titleAr": titleAr.text,
      "titleEn": titleEn.text,
      "description": description.text,
      "price": double.tryParse(price.text) ?? 0,
      "category": category.text,
      "image": imageUrl,
      "createdAt": FieldValue.serverTimestamp(),
    };

    /// حفظ داخل Firestore
    await doc.set(productData);

    /// حفظ نسخة Backup
    await FirebaseFirestore.instance
        .collection("products_backup")
        .doc(doc.id)
        .set(productData);

    setState(() => loading = false);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("رفع منتج جديد للمنيو"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleAr,
                decoration:
                    const InputDecoration(labelText: "اسم المنتج بالعربي"),
              ),
              TextField(
                controller: titleEn,
                decoration:
                    const InputDecoration(labelText: "اسم المنتج بالإنجليزي"),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: "الوصف"),
              ),
              TextField(
                controller: price,
                decoration: const InputDecoration(labelText: "السعر"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: "التصنيف"),
              ),
              const SizedBox(height: 16),
              if (imageFile != null) Image.file(imageFile!, height: 180),
              ElevatedButton(
                onPressed: () async {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => imageFile = File(picked.path));
                  }
                },
                child: const Text("اختيار صورة"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : saveProduct,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("رفع المنتج"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
