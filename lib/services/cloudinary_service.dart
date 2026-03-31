// lib/services/cloudinary_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class CloudinaryService {
  final String cloudName;
  final String uploadPreset;

  CloudinaryService({
    required this.cloudName,
    required this.uploadPreset,
  });

  Future<String?> uploadFile(File file, {String folder = ''}) async {
    final url =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['upload_preset'] = uploadPreset;
    if (folder.isNotEmpty) request.fields['folder'] = folder;

    final response = await request.send();
    final str = await response.stream.bytesToString();
    final data = jsonDecode(str);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data['secure_url'];
    } else {
      print('Cloudinary upload error: $data');
      return null;
    }
  }
}
