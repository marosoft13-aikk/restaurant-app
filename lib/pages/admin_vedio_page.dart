// AdminVideoPage - upload-from-device + preview
// تم تعديل الواجهات لتفادي overflow عن طريق استخدام Wrap و Expanded وقيود العرض المناسبة
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as p;

class AdminVideoPage extends StatefulWidget {
  const AdminVideoPage({super.key});

  @override
  State<AdminVideoPage> createState() => _AdminVideoPageState();
}

class _AdminVideoPageState extends State<AdminVideoPage> {
  final _docRef = FirebaseFirestore.instance
      .collection('app_settings')
      .doc('welcome_video');

  bool _loading = true;
  bool _enabled = false;
  String _type = 'asset'; // 'asset' or 'network'
  final TextEditingController _sourceCtrl = TextEditingController();
  VideoPlayerController? _previewController;
  StreamSubscription<DocumentSnapshot>? _sub;

  // storage info
  String? _storagePath;
  UploadTask? _uploadTask;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub = _docRef.snapshots().listen((snap) {
      if (!snap.exists) {
        setState(() {
          _loading = false;
          _enabled = false;
          _type = 'asset';
          _sourceCtrl.text = '';
          _storagePath = null;
        });
        _disposePreview();
        return;
      }
      final data = snap.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _loading = false;
        _enabled = data['enabled'] == true;
        _type = (data['type'] ?? 'asset') as String;
        _sourceCtrl.text = (data['source'] ?? '') as String;
        _storagePath = (data['storagePath'] ?? '') as String;
        if (_storagePath != '') {
          // keep as non-null string
        } else {
          _storagePath = null;
        }
      });
      _setupPreviewIfNeeded();
    }, onError: (e) {
      setState(() => _loading = false);
    });
  }

  Future<void> _setupPreviewIfNeeded() async {
    _disposePreview();

    final src = _sourceCtrl.text.trim();
    if (src.isEmpty) return;
    try {
      if (_type == 'network') {
        _previewController = VideoPlayerController.network(src);
      } else {
        _previewController = VideoPlayerController.asset(src);
      }
      await _previewController!.initialize();
      _previewController!.setLooping(true);
      // start paused then play after setState so layout can update
      setState(() {});
      _previewController!.play();
    } catch (e) {
      debugPrint('Preview init failed: $e');
      _disposePreview();
    }
  }

  void _disposePreview() {
    try {
      _previewController?.pause();
      _previewController?.dispose();
    } catch (_) {}
    _previewController = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _disposePreview();
    _sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final src = _sourceCtrl.text.trim();
    await _docRef.set({
      'enabled': _enabled,
      'type': _type,
      'source': src,
      'storagePath': _storagePath ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  Future<void> _clear() async {
    // delete storage file if exists
    if (_storagePath != null && _storagePath!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(_storagePath).delete();
      } catch (e) {
        debugPrint('Failed to delete storage file: $e');
      }
    }
    await _docRef.delete();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cleared')));
    }
  }

  Future<void> _pickAndUploadVideo() async {
    // pick video file from device
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res == null || res.files.isEmpty) return;
    final pf = res.files.first;

    final filePath = pf.path;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل الحصول على الملف')));
      }
      return;
    }

    final file = File(filePath);
    final fileName = p.basename(filePath);
    final storageRef = FirebaseStorage.instance.ref().child(
        'welcome_videos/$fileName-${DateTime.now().millisecondsSinceEpoch}');

    try {
      setState(() {
        _uploadTask = storageRef.putFile(file);
        _uploadProgress = 0.0;
      });

      _uploadTask!.snapshotEvents.listen((event) {
        final total = event.totalBytes ?? 0;
        final transferred = event.bytesTransferred;
        if (total > 0) {
          setState(() {
            _uploadProgress = transferred / total;
          });
        }
      }, onError: (e) {
        debugPrint('Upload error: $e');
      });

      final snapshot = await _uploadTask!;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        _sourceCtrl.text = downloadUrl;
        _type = 'network';
        _storagePath = snapshot.ref.fullPath;
        _uploadTask = null;
        _uploadProgress = 0.0;
      });

      // auto-save after upload
      await _save();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Upload complete')));
      }
    } catch (e) {
      debugPrint('Upload failed: $e');
      setState(() {
        _uploadTask = null;
        _uploadProgress = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل رفع الفيديو')));
      }
    }
  }

  Future<void> _deleteStorageFile() async {
    if (_storagePath == null || _storagePath!.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(_storagePath).delete();
      setState(() {
        _storagePath = null;
      });
      // also clear Firestore doc
      await _docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الملف ومسح الإعداد')));
      }
    } catch (e) {
      debugPrint('Delete storage failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل حذف الملف')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفيديو الترحيبي'),
        backgroundColor: Colors.orange,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              // use a max width for large screens to avoid overly wide content
              final maxWidth =
                  constraints.maxWidth > 900 ? 900.0 : constraints.maxWidth;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          title: const Text('عرض الفيديو عند الفتح'),
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('المصدر: '),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _type,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'asset',
                                      child: Text('من ملف داخل التطبيق')),
                                  DropdownMenuItem(
                                      value: 'network',
                                      child: Text('من رابط شبكة (URL)')),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _type = v;
                                  });
                                  _setupPreviewIfNeeded();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _sourceCtrl,
                          decoration: const InputDecoration(
                            labelText:
                                'المسار / الرابط (مثال: assets/videos/welcome.mp4 أو https://...)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _setupPreviewIfNeeded(),
                        ),
                        const SizedBox(height: 12),

                        // Wrap بدلاً من Row لتفادي overflow عندما تكون الشاشة ضيقة
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.upload_file),
                              label: const Text('ارفع فيديو من الجهاز'),
                              onPressed: _pickAndUploadVideo,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('حفظ'),
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('مسح / إخفاء'),
                              onPressed: _clear,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (_uploadTask != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(value: _uploadProgress),
                              const SizedBox(height: 8),
                              Text(
                                  'جارٍ الرفع: ${(100 * _uploadProgress).toStringAsFixed(0)}%',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                            ],
                          ),

                        // Preview area
                        if (_previewController != null &&
                            _previewController!.value.isInitialized)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Constrain the preview height to avoid huge video on large screens
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.5,
                                ),
                                child: AspectRatio(
                                  aspectRatio:
                                      _previewController!.value.aspectRatio,
                                  child: VideoPlayer(_previewController!),
                                ),
                              ),
                              VideoProgressIndicator(_previewController!,
                                  allowScrubbing: true),
                              const SizedBox(height: 8),
                              // controls: use Wrap to avoid overflow
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_previewController!
                                              .value.isPlaying) {
                                            _previewController!.pause();
                                          } else {
                                            _previewController!.play();
                                          }
                                        });
                                      },
                                      icon: Icon(
                                          _previewController!.value.isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow)),
                                  if (_storagePath != null)
                                    ElevatedButton.icon(
                                      onPressed: _deleteStorageFile,
                                      icon: const Icon(Icons.delete),
                                      label: const Text('حذف ملف الStorage'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),

                        // If no preview, show helpful hint (wrapped)
                        if (_previewController == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'لا يوجد معاينة حالياً. أدخل رابط أو ارفع فيديو لعرض معاينة.',
                              style: TextStyle(color: Colors.grey.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
    );
  }
}
