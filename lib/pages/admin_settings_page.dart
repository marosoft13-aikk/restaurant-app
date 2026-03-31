import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_page.dart';
import 'admin_dashboard_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  // UI language toggle (saved to SharedPreferences so SettingsPage can read it)
  bool isArabic = false;

  // Authorization (optional master password)
  final TextEditingController masterPassCtrl = TextEditingController();
  bool authorized = false;
  String _savedMasterPass = '987654';

  // Login/master password controllers
  final TextEditingController newLoginPassCtrl = TextEditingController();
  final TextEditingController confirmLoginPassCtrl = TextEditingController();
  final TextEditingController newMasterPassCtrl = TextEditingController();
  final TextEditingController confirmMasterPassCtrl = TextEditingController();

  // Firestore collection for branches
  final CollectionReference<Map<String, dynamic>> _branchesCol =
      FirebaseFirestore.instance.collection('branches');

  @override
  void initState() {
    super.initState();
    _loadMasterPassword();
    _loadLanguagePref();
  }

  Future<void> _loadMasterPassword() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedMasterPass = prefs.getString('master_password') ?? _savedMasterPass;
    });
  }

  Future<void> _loadLanguagePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool('app_is_ar') ?? false;
      if (mounted) setState(() => isArabic = v);
    } catch (_) {}
  }

  Future<void> _saveLanguagePref(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_is_ar', v);
      if (mounted) setState(() => isArabic = v);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(v ? 'الواجهة: العربية' : 'UI: English'),
          duration: const Duration(seconds: 1)));
    } catch (_) {}
  }

  void _showSnack(String text, {Color bg = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: bg,
      ),
    );
  }

  void _authorize() {
    if (masterPassCtrl.text.trim() == _savedMasterPass) {
      setState(() {
        authorized = true;
        masterPassCtrl.clear();
      });
      _showSnack(isArabic ? '✔ مُصرّح' : '✔ Authorized', bg: Colors.green);
    } else {
      _showSnack(
          isArabic
              ? '❌ كلمة مرور المدير غير صحيحة'
              : '❌ Master password incorrect',
          bg: Colors.red);
    }
  }

  Future<void> _updateLoginPassword() async {
    final p1 = newLoginPassCtrl.text.trim();
    final p2 = confirmLoginPassCtrl.text.trim();
    if (p1.isEmpty || p2.isEmpty) {
      _showSnack(
          isArabic
              ? '❌ اكتب كلمة المرور الجديدة وتأكيدها'
              : '❌ Enter and confirm new password',
          bg: Colors.red);
      return;
    }
    if (p1 != p2) {
      _showSnack(
          isArabic ? '❌ كلمتا السر غير متطابقتين' : '❌ Passwords do not match',
          bg: Colors.red);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_password', p1);
    newLoginPassCtrl.clear();
    confirmLoginPassCtrl.clear();
    _showSnack(
        isArabic ? '✔ تم تغيير كلمة سر الدخول' : '✔ Login password updated',
        bg: Colors.green);
  }

  Future<void> _updateMasterPassword() async {
    final p1 = newMasterPassCtrl.text.trim();
    final p2 = confirmMasterPassCtrl.text.trim();
    if (p1.isEmpty || p2.isEmpty) {
      _showSnack(
          isArabic
              ? '❌ اكتب كلمة مرور المدير الجديدة وتأكيدها'
              : '❌ Enter and confirm new master password',
          bg: Colors.red);
      return;
    }
    if (p1 != p2) {
      _showSnack(
          isArabic ? '❌ كلمتا السر غير متطابقتين' : '❌ Passwords do not match',
          bg: Colors.red);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('master_password', p1);
    setState(() => _savedMasterPass = p1);
    newMasterPassCtrl.clear();
    confirmMasterPassCtrl.clear();
    _showSnack(
        isArabic ? '✔ تم تحديث كلمة مرور المدير' : '✔ Master password updated',
        bg: Colors.green);
  }

  // ---------------- Branch helpers for testing ----------------

  Future<void> addSampleBranch() async {
    try {
      final newDoc = _branchesCol.doc();
      await newDoc.set({
        'id': newDoc.id,
        'titleEn': 'Branch Test EN',
        'titleAr': 'فرع تجريبي',
        'addressEn': 'Test address EN',
        'addressAr': 'اختبار العنوان',
        'phones': ['01000000000'],
        'visible': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSnack(isArabic ? '✔ تمت إضافة فرع تجريبي' : '✔ Sample branch added',
          bg: Colors.green);
    } catch (e) {
      _showSnack((isArabic ? 'فشل الإضافة: ' : 'Add failed: ') + e.toString(),
          bg: Colors.red);
    }
  }

  Future<void> debugListBranches() async {
    try {
      final snap = await _branchesCol.get();
      _showSnack(
          '${snap.docs.length} ${isArabic ? 'فروع في القاعدة' : 'branches in collection'}',
          bg: Colors.black87);
      // Print to console as well for developer debugging
      for (final d in snap.docs) {
        // ignore: avoid_print
        print('branch ${d.id} => ${d.data()}');
      }
    } catch (e) {
      _showSnack((isArabic ? 'فشل القراءة: ' : 'Read failed: ') + e.toString(),
          bg: Colors.red);
    }
  }

  // ---------------- Branch CRUD ----------------

  Future<void> _showAddEditBranch(
      [DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final isEdit = doc != null;

    final titleEnCtrl = TextEditingController(
        text: isEdit ? (doc!.data()?['titleEn']?.toString() ?? '') : '');
    final titleArCtrl = TextEditingController(
        text: isEdit ? (doc!.data()?['titleAr']?.toString() ?? '') : '');
    final addressEnCtrl = TextEditingController(
        text: isEdit ? (doc!.data()?['addressEn']?.toString() ?? '') : '');
    final addressArCtrl = TextEditingController(
        text: isEdit ? (doc!.data()?['addressAr']?.toString() ?? '') : '');
    final phonesCtrl = TextEditingController(
        text: isEdit
            ? ((doc!.data()?['phones'] as List<dynamic>?)?.join(',') ?? '')
            : '');
    bool visible = isEdit ? ((doc!.data()?['visible'] ?? true) as bool) : true;

    final save = await showDialog<bool?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateSB) {
          return AlertDialog(
            title: Text(isArabic
                ? (isEdit ? 'تعديل الفرع' : 'إضافة فرع')
                : (isEdit ? 'Edit Branch' : 'Add Branch')),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                      controller: titleEnCtrl,
                      decoration: InputDecoration(
                          labelText: isArabic ? 'العنوان (EN)' : 'Title (EN)')),
                  TextField(
                      controller: titleArCtrl,
                      decoration: InputDecoration(
                          labelText: isArabic ? 'العنوان (AR)' : 'Title (AR)')),
                  TextField(
                      controller: addressEnCtrl,
                      decoration: InputDecoration(
                          labelText: isArabic
                              ? 'العنوان التفصيلي (EN)'
                              : 'Address (EN)')),
                  TextField(
                      controller: addressArCtrl,
                      decoration: InputDecoration(
                          labelText: isArabic
                              ? 'العنوان التفصيلي (AR)'
                              : 'Address (AR)')),
                  TextField(
                      controller: phonesCtrl,
                      decoration: InputDecoration(
                          labelText: isArabic
                              ? 'أرقام الهاتف (مفصولة بفواصل)'
                              : 'Phones (comma separated)')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(isArabic ? 'مرئي (Visible)' : 'Visible'),
                    const SizedBox(width: 8),
                    Switch(
                        value: visible,
                        onChanged: (v) => setStateSB(() => visible = v)),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(isArabic ? 'إلغاء' : 'Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isArabic ? 'حفظ' : 'Save')),
            ],
          );
        });
      },
    );

    if (save != true) return;

    final phones = phonesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (titleEnCtrl.text.trim().isEmpty && titleArCtrl.text.trim().isEmpty) {
      _showSnack(
          isArabic
              ? '❌ اكتب عنوانًا بالإنجليزية أو العربية'
              : '❌ Enter a title in EN or AR',
          bg: Colors.red);
      return;
    }

    try {
      if (isEdit) {
        await _branchesCol.doc(doc!.id).set({
          'titleEn': titleEnCtrl.text.trim(),
          'titleAr': titleArCtrl.text.trim(),
          'addressEn': addressEnCtrl.text.trim(),
          'addressAr': addressArCtrl.text.trim(),
          'phones': phones,
          'visible': visible,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _showSnack(isArabic ? '✔ تم تحديث الفرع' : '✔ Branch updated',
            bg: Colors.green);
      } else {
        final newDoc = _branchesCol.doc();
        await newDoc.set({
          'id': newDoc.id,
          'titleEn': titleEnCtrl.text.trim(),
          'titleAr': titleArCtrl.text.trim(),
          'addressEn': addressEnCtrl.text.trim(),
          'addressAr': addressArCtrl.text.trim(),
          'phones': phones,
          'visible': visible,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _showSnack(isArabic ? '✔ تم إضافة الفرع' : '✔ Branch added',
            bg: Colors.green);
      }
    } catch (e) {
      _showSnack((isArabic ? 'فشل الحفظ: ' : 'Save failed: ') + e.toString(),
          bg: Colors.red);
    }
  }

  Future<void> _deleteBranch(String docId) async {
    final confirm = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف الفرع' : 'Delete branch'),
        content: Text(isArabic
            ? 'هل أنت متأكد من حذف هذا الفرع؟'
            : 'Are you sure you want to delete this branch?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isArabic ? 'حذف' : 'Delete',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _branchesCol.doc(docId).delete();
      _showSnack(isArabic ? '✔ تم حذف الفرع' : '✔ Branch deleted',
          bg: Colors.green);
    } catch (e) {
      _showSnack((isArabic ? 'فشل الحذف: ' : 'Delete failed: ') + e.toString(),
          bg: Colors.red);
    }
  }

  Future<void> _toggleBranchVisibility(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      final cur = (doc.data()?['visible'] ?? true) as bool;
      await _branchesCol.doc(doc.id).set(
          {'visible': !cur, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      _showSnack(isArabic ? '✔ تم تحديث الظهور' : '✔ Visibility updated',
          bg: Colors.green);
    } catch (e) {
      _showSnack(
          (isArabic ? 'فشل التحديث: ' : 'Update failed: ') + e.toString(),
          bg: Colors.red);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'إعدادات الأدمن' : 'Admin Settings'),
          backgroundColor: Colors.orange,
          actions: [
            // Language toggle (saves to SharedPreferences)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Text(isArabic ? 'ع' : 'EN',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Switch(
                    value: isArabic,
                    onChanged: (v) => _saveLanguagePref(v),
                    activeColor: Colors.white,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: isArabic ? 'معاينة الإعدادات' : 'Preview Settings',
              onPressed: () {
                // ensure pref saved already, then open preview
                _saveLanguagePref(isArabic).then((_) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()));
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: isArabic ? 'إغلاق' : 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: authorized ? _buildAdminPanel() : _buildAuthPanel(),
        ),
      ),
    );
  }

  Widget _buildAuthPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isArabic ? 'أدخل كلمة مرور المدير' : 'Enter master password',
            style: GoogleFonts.cairo(fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
            controller: masterPassCtrl,
            obscureText: true,
            decoration: InputDecoration(
                labelText: isArabic ? 'كلمة مرور المدير' : 'Master password')),
        const SizedBox(height: 12),
        ElevatedButton(
            onPressed: _authorize,
            child: Text(isArabic ? 'تأكيد' : 'Authorize')),
        const SizedBox(height: 12),
        Text(
            '${isArabic ? 'كلمة مرور المدير الحالية: ' : 'Current saved master password: '}$_savedMasterPass',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildAdminPanel() {
    return ListView(
      children: [
        Text(isArabic ? 'إعدادات الأدمن' : 'Admin Settings',
            style:
                GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Quick test buttons
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: addSampleBranch,
              icon: const Icon(Icons.add_box_outlined),
              label: Text(isArabic ? 'أضف فرع تجريبي' : 'Add sample branch'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: debugListBranches,
              icon: const Icon(Icons.bug_report),
              label: Text(
                  isArabic ? 'قائمة الفروع (Debug)' : 'List branches (debug)'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Change login password
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                    isArabic
                        ? 'تغيير كلمة سر الدخول'
                        : 'Change app login password',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                    controller: newLoginPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: isArabic
                            ? 'كلمة المرور الجديدة'
                            : 'New login password')),
                TextField(
                    controller: confirmLoginPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: isArabic
                            ? 'تأكيد كلمة المرور'
                            : 'Confirm password')),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: _updateLoginPassword,
                    child: Text(isArabic
                        ? 'تحديث كلمة السر'
                        : 'Update login password')),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Change master password
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                    isArabic
                        ? 'تغيير كلمة مرور المدير'
                        : 'Change master password',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                    controller: newMasterPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: isArabic
                            ? 'كلمة مرور المدير الجديدة'
                            : 'New master password')),
                TextField(
                    controller: confirmMasterPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: isArabic
                            ? 'تأكيد كلمة مرور المدير'
                            : 'Confirm master password')),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: _updateMasterPassword,
                    child: Text(isArabic ? 'تحديث' : 'Update')),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Branch management header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isArabic ? 'الفروع (قاعدة البيانات)' : 'Branches (Firestore)',
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
                onPressed: () => _showAddEditBranch(null),
                icon: const Icon(Icons.add),
                label: Text(isArabic ? 'إضافة فرع' : 'Add branch')),
          ],
        ),

        const SizedBox(height: 8),

        // Stream of branches from Firestore (ordered by createdAt)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              _branchesCol.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      (isArabic
                              ? 'خطأ في جلب الفروع: '
                              : 'Error loading branches: ') +
                          snap.error.toString(),
                      style: const TextStyle(color: Colors.red)));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child:
                      Text(isArabic ? 'لا توجد فروع بعد' : 'No branches yet'));
            }
            return Column(
              children: docs.map((d) {
                final data = d.data();
                final titleEn = (data['titleEn'] ?? '').toString();
                final titleAr = (data['titleAr'] ?? '').toString();
                final addressEn = (data['addressEn'] ?? '').toString();
                final addressAr = (data['addressAr'] ?? '').toString();
                final phones =
                    (data['phones'] as List<dynamic>?)?.cast<String>() ??
                        <String>[];
                final visible = (data['visible'] ?? true) as bool;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(titleAr.isNotEmpty ? titleAr : titleEn,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(addressAr.isNotEmpty ? addressAr : addressEn),
                        const SizedBox(height: 6),
                        Text(
                            '${isArabic ? 'الهواتف' : 'Phones'}: ${phones.join(', ')}',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(
                            '${isArabic ? 'مرئي' : 'Visible'}: ${visible ? (isArabic ? 'نعم' : 'Yes') : (isArabic ? 'لا' : 'No')}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                            icon: Icon(
                                visible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: visible ? Colors.green : Colors.grey),
                            onPressed: () => _toggleBranchVisibility(d),
                            tooltip: isArabic
                                ? 'تغيير الظهور'
                                : 'Toggle visibility'),
                        IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _showAddEditBranch(d),
                            tooltip: isArabic ? 'تعديل' : 'Edit'),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBranch(d.id),
                            tooltip: isArabic ? 'حذف' : 'Delete'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminDashboardPage()));
            },
            icon: const Icon(Icons.dashboard),
            label: Text(isArabic ? 'فتح لوحة التحكم' : 'Open Admin Dashboard')),
      ],
    );
  }
}
