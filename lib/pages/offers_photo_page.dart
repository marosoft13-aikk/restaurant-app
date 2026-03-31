import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddOfferPage extends StatefulWidget {
  const AddOfferPage({super.key});

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final title = TextEditingController();
  final desc = TextEditingController();
  final discount = TextEditingController();

  File? pickedImage;
  bool isUploading = false;

  Future<void> pickImage() async {
    final XFile? image =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        pickedImage = File(image.path);
      });
    }
  }

  Future<String> uploadImage(File image) async {
    String fileName = "offers/${DateTime.now().millisecondsSinceEpoch}.png";
    Reference ref = FirebaseStorage.instance.ref().child(fileName);

    UploadTask uploadTask = ref.putFile(image);
    TaskSnapshot snapshot = await uploadTask;

    return await snapshot.ref.getDownloadURL();
  }

  Future<void> saveOffer() async {
    if (pickedImage == null || title.text.isEmpty) return;

    setState(() => isUploading = true);

    String imageUrl = await uploadImage(pickedImage!);

    await FirebaseFirestore.instance.collection("offers").add({
      "title": title.text,
      "desc": desc.text,
      "discount": discount.text,
      "image": imageUrl,
      "createdAt": Timestamp.now(),
    });

    setState(() => isUploading = false);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text("إضافة عرض جديد", style: GoogleFonts.cairo()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: pickedImage == null
                    ? Center(
                        child: Text(
                          "اضغط لاختيار صورة العرض",
                          style: GoogleFonts.cairo(fontSize: 16),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(pickedImage!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: "عنوان العرض"),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: "الوصف"),
            ),
            TextField(
              controller: discount,
              decoration: const InputDecoration(labelText: "الخصم"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isUploading ? null : saveOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("إضافة العرض",
                      style:
                          GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}
