import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/menu_item_model.dart';
import '../services/firebase_menu_service.dart';
import '../data/full_menu.dart'
    show fullMenuList; // optional local import for import feature

class AdminMenuPage extends StatefulWidget {
  const AdminMenuPage({super.key});

  @override
  State<AdminMenuPage> createState() => _AdminMenuPageState();
}

class _AdminMenuPageState extends State<AdminMenuPage> {
  final FirebaseMenuService _service = FirebaseMenuService();

  // Configure Cloudinary (or other image host) if you want image uploads
  static const String _cloudName = 'dhn7dcwej';
  static const String _uploadPreset = 'ml_default';

  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Manage Menu'),
        backgroundColor: Colors.orange,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'import') {
                await _confirmAndImportLocalMenu();
              } else if (v == 'clear') {
                await _confirmAndClearAll();
              } else if (v == 'refresh') {
                setState(() {});
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'import', child: Text('Import local menu')),
              const PopupMenuItem(
                  value: 'clear', child: Text('Clear collection')),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<MenuItemModel>>(
            stream: _service.menuStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('لا يوجد أصناف هنا بعد'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final imageSrc = (item.imagePath ?? '').isNotEmpty
                      ? item.imagePath!
                      : (item.image ?? '');
                  Widget leading;
                  if ((imageSrc ?? '').isNotEmpty) {
                    if (imageSrc!.startsWith('http')) {
                      leading = SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(imageSrc,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image_not_supported))));
                    } else {
                      leading = SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(imageSrc, fit: BoxFit.cover)));
                    }
                  } else {
                    leading = const SizedBox(
                        width: 56, height: 56, child: Icon(Icons.fastfood));
                  }

                  return Card(
                    elevation: 3,
                    child: ListTile(
                      leading: leading,
                      title: Text((item.titleEn?.isNotEmpty == true)
                          ? item.titleEn!
                          : (item.titleAr ?? '')),
                      subtitle: Text(
                          '${item.category ?? ''} • ${item.price?.toString() ?? '0'} ج.م'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _openEditor(existing: item)),
                          IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(item)),
                        ],
                      ),
                      onTap: () => _showDetails(item),
                    ),
                  );
                },
              );
            },
          ),
          if (_importing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Importing menu... Please wait',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () => _openEditor(),
      ),
    );
  }

  Future<void> _confirmAndImportLocalMenu() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import local menu'),
        content: const Text(
            'Import the local bundled menu into Firestore.\nChoose behavior for ID conflicts:'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: const Text('Skip existing')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Overwrite existing')),
        ],
      ),
    );

    if (choice == null || choice == 'cancel') return;
    final overwrite = choice == 'overwrite';

    await _importLocalMenu(overwrite: overwrite);
  }

  Future<void> _importLocalMenu({required bool overwrite}) async {
    setState(() => _importing = true);
    try {
      final col =
          FirebaseFirestore.instance.collection(_service.collectionName);
      final snap = await col.get();
      final existingIds = snap.docs.map((d) => d.id).toSet();

      final batch = FirebaseFirestore.instance.batch();

      for (final localItem in fullMenuList) {
        final id = localItem.id ??
            FirebaseFirestore.instance
                .collection(_service.collectionName)
                .doc()
                .id;
        final docRef = col.doc(id);

        if (!overwrite && existingIds.contains(id)) {
          continue;
        }

        final map = localItem.toMap();
        if (!(map.containsKey('createdAt') && map['createdAt'] != null)) {
          map['createdAt'] = FieldValue.serverTimestamp();
        }

        batch.set(docRef, map, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Import completed'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Import failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _importing = false);
    }
  }

  Future<void> _confirmDelete(MenuItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text(
            'Are you sure you want to delete "${(item.titleEn?.isNotEmpty == true) ? item.titleEn : item.titleAr}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      // pass id safely (fallback to empty string if null)
      final targetId = item.id ?? '';
      if (targetId.isNotEmpty) {
        await _service.deleteItem(targetId);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Item deleted'), backgroundColor: Colors.green));
      } else {
        // if no id, show error
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Cannot delete: missing id'),
              backgroundColor: Colors.red));
      }
    }
  }

  void _showDetails(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((item.titleEn?.isNotEmpty == true)
            ? item.titleEn!
            : (item.titleAr ?? '')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (((item.imagePath ?? '').isNotEmpty) ||
                  ((item.image ?? '').isNotEmpty))
                SizedBox(
                  height: 150,
                  child: Image.network(
                      (item.imagePath?.isNotEmpty == true)
                          ? item.imagePath!
                          : (item.image ?? ''),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported)),
                ),
              const SizedBox(height: 8),
              Text('Category: ${item.category ?? ''}'),
              Text('Price: ${item.price?.toString() ?? '0'}'),
              const SizedBox(height: 8),
              Text(
                  'Description (EN): ${item.descriptionEn ?? item.description ?? ''}'),
              const SizedBox(height: 6),
              Text('Description (AR): ${item.descriptionAr ?? ''}'),
              const SizedBox(height: 8),
              Text(
                  'Options: ${((item.options ?? []).map((o) => (o['value'] ?? o['name'] ?? '')).where((s) => (s ?? '').isNotEmpty).join(', '))}'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _openEditor({MenuItemModel? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.titleAr ?? existing?.name ?? '');
    final titleEnCtrl = TextEditingController(text: existing?.titleEn ?? '');
    final descCtrl = TextEditingController(
        text: existing?.descriptionEn ?? existing?.description ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null && existing.price != null
            ? existing.price.toString()
            : '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    File? pickedImage;
    final optionsCtrl = TextEditingController(
        text: existing != null
            ? (existing.options ?? [])
                .map((o) => (o['value'] ?? o['name'] ?? '').toString())
                .join(', ')
            : '');

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateSB) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              existing == null ? 'Add item' : 'Edit item',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close))
                    ]),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker()
                            .pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setStateSB(() => pickedImage = File(picked.path));
                        }
                      },
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                          image: pickedImage == null &&
                                  existing != null &&
                                  ((existing.imagePath?.isNotEmpty ?? false) ||
                                      (existing.image?.isNotEmpty ?? false))
                              ? DecorationImage(
                                  image:
                                      (existing.imagePath?.startsWith('http') ==
                                              true)
                                          ? NetworkImage(existing.imagePath!)
                                          : AssetImage(existing.imagePath ??
                                              existing.image ??
                                              '') as ImageProvider,
                                  fit: BoxFit.cover)
                              : pickedImage != null
                                  ? DecorationImage(
                                      image: FileImage(pickedImage!),
                                      fit: BoxFit.cover)
                                  : null,
                        ),
                        child: const Center(child: Text("اضغط لاختيار صورة")),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                            labelText: "Title (AR / name)")),
                    const SizedBox(height: 8),
                    TextField(
                        controller: titleEnCtrl,
                        decoration:
                            const InputDecoration(labelText: "Title (EN)")),
                    const SizedBox(height: 8),
                    TextField(
                        controller: descCtrl,
                        decoration:
                            const InputDecoration(labelText: "Description")),
                    const SizedBox(height: 8),
                    TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Price")),
                    const SizedBox(height: 8),
                    TextField(
                        controller: categoryCtrl,
                        decoration:
                            const InputDecoration(labelText: "Category")),
                    const SizedBox(height: 8),
                    TextField(
                        controller: optionsCtrl,
                        decoration: const InputDecoration(
                            labelText: "Options (comma separated)")),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          onPressed: () async {
                            final imgUrl = (pickedImage != null)
                                ? await _uploadTempImage(pickedImage!)
                                : (existing?.imagePath?.isNotEmpty == true
                                    ? existing!.imagePath
                                    : (existing?.image ?? ''));
                            final id = existing?.id ??
                                FirebaseFirestore.instance
                                    .collection(_service.collectionName)
                                    .doc()
                                    .id;
                            final parsedOptions =
                                (optionsCtrl.text.trim().isEmpty)
                                    ? []
                                    : optionsCtrl.text
                                        .split(',')
                                        .map((s) => {'value': s.trim()})
                                        .where((m) =>
                                            (m['value'] as String).isNotEmpty)
                                        .toList();

                            final modelMap = {
                              'id': id,
                              'name': nameCtrl.text.trim(),
                              'titleEn': titleEnCtrl.text.trim(),
                              'titleAr': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'descriptionEn': descCtrl.text.trim(),
                              'descriptionAr': descCtrl.text.trim(),
                              'price':
                                  double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                              'imagePath': imgUrl,
                              'image': imgUrl,
                              'category':
                                  categoryCtrl.text.trim().toLowerCase(),
                              'options': parsedOptions,
                              'order': existing?.order ?? 0,
                              'visible': existing?.visible ?? true,
                              'createdAt': existing == null
                                  ? FieldValue.serverTimestamp()
                                  : null,
                            };

                            final model = MenuItemModel.fromMap(modelMap);
                            await _service.addOrUpdateItem2(model);

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Saved'),
                                      backgroundColor: Colors.green));
                            }
                          },
                          child: Text(existing == null ? 'Create' : 'Update'),
                        ),
                        const SizedBox(width: 12),
                        if (existing != null)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (dctx) => AlertDialog(
                                  title: const Text('Confirm delete'),
                                  content: Text(
                                      'Delete "${existing.titleEn ?? existing.titleAr}"?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dctx, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dctx, true),
                                        child: const Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                final targetId = existing.id ?? '';
                                if (targetId.isNotEmpty) {
                                  await _service.deleteItem(targetId);
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Deleted'),
                                            backgroundColor: Colors.green));
                                  }
                                } else {
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Cannot delete: missing id'),
                                            backgroundColor: Colors.red));
                                }
                              }
                            },
                            child: const Text('Delete'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<String> _uploadTempImage(File file) async {
    try {
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final res = await req.send();
      final body = await res.stream.bytesToString();
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;
      return (jsonBody['secure_url'] ?? '') as String;
    } catch (e) {
      debugPrint('temp upload failed: $e');
      return '';
    }
  }

  Future<void> _confirmAndClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear products collection'),
        content: const Text(
            'This will delete ALL documents in the products collection. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _service.clearAll();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('All products deleted'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Clear failed: $e'), backgroundColor: Colors.red));
    }
  }
}
