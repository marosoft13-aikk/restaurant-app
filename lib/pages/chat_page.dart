import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../utils/chat_utils.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final String otherName;
  final String myUid;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
    required this.myUid,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final int _pageSize = 20;

  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _messagesDocs = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _recentSub;
  bool _sendingImage = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  bool _dateInitialized = false;
  String _currentLocaleTag = 'en';

  // لتجنب التنقّل إلى الأعلى أثناء تفاعل المستخدم مع القائمة
  bool _userDragging = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar').catchError((_) {});
    _ensureChatDocExists();
    _listenRecent();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        try {
          _scroll.position.isScrollingNotifier.addListener(() {
            _userDragging = _scroll.position.isScrollingNotifier.value;
          });
        } catch (_) {}
      }
    });

    if (kDebugMode) {
      Future.delayed(
          const Duration(milliseconds: 400), () => _maybeDebugDumpChat());
    }
  }

  Future<void> _ensureChatDocExists() async {
    try {
      await getOrCreateChat(widget.myUid, widget.otherUid);
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      await chatRef.set({
        'participants': [widget.myUid, widget.otherUid],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('ensureChatDocExists failed: $e');
    }
  }

  Future<void> _maybeDebugDumpChat() async {
    try {
      await debugDumpChat(widget.chatId, limit: 20);
    } catch (_) {}
  }

  Future<void> _ensureDateFormatting() async {
    try {
      final locale = Localizations.localeOf(context).toString();
      if (!_dateInitialized || locale != _currentLocaleTag) {
        _currentLocaleTag = locale;
        await initializeDateFormatting(locale);
        if (mounted) setState(() => _dateInitialized = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _recentSub?.cancel();
    _scroll.dispose();
    _ctrl.dispose();
    _typingTimer?.cancel();
    _setTyping(false);
    super.dispose();
  }

  // الاستماع لآخر الرسائل
  void _listenRecent() {
    final q = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (kDebugMode) {
      debugPrint('ChatPage: subscribe messages chatId=${widget.chatId}');
    }

    _recentSub?.cancel();
    _recentSub = q.snapshots().listen((snap) {
      final docs = snap.docs;
      if (kDebugMode) debugPrint('ChatPage snapshot docs=${docs.length}');

      if (!mounted) return;
      setState(() {
        _messagesDocs = docs;
        _hasMore = docs.length >= _pageSize;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_userDragging) return;
        if (_scroll.hasClients) {
          try {
            _scroll.animateTo(0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          } catch (_) {
            try {
              _scroll.jumpTo(0.0);
            } catch (_) {}
          }
        }
      });

      _markMessagesReadIfNeeded(docs);
    }, onError: (e) {
      if (kDebugMode) debugPrint('recentSub error: $e');
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_messagesDocs.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final lastDoc = _messagesDocs.last;
      final qSnap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(_pageSize)
          .get();
      final newDocs = qSnap.docs;
      if (!mounted) return;
      setState(() {
        _messagesDocs.addAll(newDocs);
        _hasMore = newDocs.length >= _pageSize;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('loadMore error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markMessagesReadIfNeeded(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      var hasUpdate = false;
      for (final d in docs) {
        final data = d.data();
        final from = (data['from'] ?? '').toString();
        final status = (data['status'] ?? 'sent').toString();
        if (from != widget.myUid && status != 'read') {
          batch.update(d.reference,
              {'status': 'read', 'readAt': FieldValue.serverTimestamp()});
          hasUpdate = true;
        }
      }
      if (hasUpdate) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('mark read failed: $e');
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    final contentText = (text ?? _ctrl.text).trim();
    if ((contentText.isEmpty && (imageUrl == null)) || widget.chatId.isEmpty)
      return;

    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final coll = chatRef.collection('messages');

    final lastPreview = (imageUrl != null && contentText.isEmpty)
        ? '[صورة]'
        : (contentText.isNotEmpty ? contentText : '[صورة]');

    try {
      final msgId = const Uuid().v4();
      final msg = <String, dynamic>{
        'from': widget.myUid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'sent',
        'type': imageUrl != null ? 'image' : 'text',
      };
      if (imageUrl != null) {
        msg['imageUrl'] = imageUrl;
        if (contentText.isNotEmpty) msg['text'] = contentText;
      } else {
        msg['text'] = contentText;
      }

      if (kDebugMode) {
        debugPrint('ChatPage: sending message to chat=${widget.chatId}');
        debugPrint('ChatPage: message id=$msgId, payload=$msg');
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.set(
          chatRef,
          {
            'participants': [widget.myUid, widget.otherUid],
            'updatedAt': FieldValue.serverTimestamp(),
            'lastMessage': lastPreview,
          },
          SetOptions(merge: true));

      final newDocRef = coll.doc(msgId);
      batch.set(newDocRef, msg);

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
            'ChatPage: batch commit succeeded for chat=${widget.chatId} msgId=$msgId');
      }

      if (mounted) {
        _ctrl.clear();
        _setTyping(false);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          try {
            _scroll.animateTo(0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          } catch (_) {
            try {
              _scroll.jumpTo(0.0);
            } catch (_) {}
          }
        }
      });
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل إرسال الرسالة: $e')));
      }
      if (kDebugMode) debugPrint('ChatPage: sendMessage error: $e\n$st');
    }
  }

  Future<String?> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return null;
    if (mounted) setState(() => _sendingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final id = const Uuid().v4();
      final ref = FirebaseStorage.instance
          .ref()
          .child('chats/${widget.chatId}/images/$id.jpg');
      final snapshot =
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل رفع الصورة')));
      if (kDebugMode) debugPrint('upload image failed: $e');
      return null;
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<void> _setTyping(bool typing) async {
    if (!mounted) return;
    _typingTimer?.cancel();
    setState(() => _isTyping = typing);
    try {
      final ref =
          FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      await ref.set({
        'typing': {widget.myUid: typing}
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('setTyping failed: $e');
    }
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _setTyping(false);
      });
    }
  }

  Future<void> _deleteMessage(
      DocumentReference<Map<String, dynamic>> ref, bool canDelete) async {
    if (!canDelete) return;
    try {
      await ref.delete();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حذف الرسالة')));
    } catch (e) {
      if (kDebugMode) debugPrint('delete failed: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل حذف الرسالة')));
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (_dateInitialized) {
      try {
        return DateFormat.yMMMd(Localizations.localeOf(context).toString())
            .format(dt);
      } catch (_) {}
    }
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    if (_dateInitialized) {
      try {
        return DateFormat.Hm(Localizations.localeOf(context).toString())
            .format(dt);
      } catch (_) {}
    }
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    final text = (data['text'] ?? '').toString();
    final imageUrl = data['imageUrl']?.toString();
    final ts = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final status = (data['status'] ?? '').toString();
    final timeStr = ts != null ? _formatTime(ts) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepOrange.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (_) => Dialog(
                        child: InteractiveViewer(
                            child:
                                Image.network(imageUrl, fit: BoxFit.contain))));
              },
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl, fit: BoxFit.cover)),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty && text.isNotEmpty)
            const SizedBox(height: 8),
          if (text.isNotEmpty) Text(text, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (timeStr.isNotEmpty)
              Text(timeStr,
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
            const SizedBox(width: 6),
            if (isMe) _statusIcon(status),
          ]),
        ]),
      ),
    );
  }

  Widget _statusIcon(String status) {
    if (status == 'sending')
      return const Icon(Icons.access_time, size: 14, color: Colors.grey);
    if (status == 'sent')
      return const Icon(Icons.check, size: 14, color: Colors.grey);
    if (status == 'delivered')
      return const Icon(Icons.done_all, size: 14, color: Colors.grey);
    if (status == 'read')
      return const Icon(Icons.done_all, size: 14, color: Colors.blue);
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.otherName),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final typingMap =
                    snap.data?.data()?['typing'] as Map<String, dynamic>?;
                final isOtherTyping =
                    typingMap != null && (typingMap[widget.otherUid] == true);
                if (isOtherTyping)
                  return const Text('يكتب...', style: TextStyle(fontSize: 12));
                return const SizedBox.shrink();
              },
            ),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                await debugDumpChat(widget.chatId, limit: 50);
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تفريغ الـ debug logs')));
              },
            )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _messagesDocs.isEmpty
                    ? const Center(child: Text('لا توجد رسائل بعد'))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is OverscrollNotification) {
                            if (notification.overscroll > 0 &&
                                !_isLoadingMore &&
                                _hasMore) _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.only(
                              left: 12,
                              right: 12,
                              top: 12,
                              bottom: MediaQuery.of(context).viewInsets.bottom +
                                  80),
                          reverse: true,
                          itemCount:
                              _messagesDocs.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoadingMore &&
                                index == _messagesDocs.length) {
                              return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                      child: CircularProgressIndicator()));
                            }
                            final doc = _messagesDocs[index];
                            final data = doc.data();
                            final from = (data['from'] ?? '').toString();
                            final isMe = from == widget.myUid;
                            final ts = data['createdAt'] is Timestamp
                                ? (data['createdAt'] as Timestamp).toDate()
                                : null;

                            Widget separator = const SizedBox.shrink();
                            if (index == _messagesDocs.length - 1) {
                              if (ts != null)
                                separator = _buildDateSeparator(ts);
                            } else {
                              final nextDoc = _messagesDocs[index + 1];
                              final nextTs = nextDoc.data()['createdAt']
                                      is Timestamp
                                  ? (nextDoc.data()['createdAt'] as Timestamp)
                                      .toDate()
                                  : null;
                              if (ts != null && nextTs != null) {
                                if (!isSameDate(ts, nextTs))
                                  separator = _buildDateSeparator(ts);
                              } else if (ts != null && nextTs == null) {
                                separator = _buildDateSeparator(ts);
                              }
                            }

                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  separator,
                                  GestureDetector(
                                    onLongPress: () async {
                                      final isMine = isMe;
                                      final choice =
                                          await showModalBottomSheet<String>(
                                        context: context,
                                        builder: (_) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                  leading:
                                                      const Icon(Icons.copy),
                                                  title: const Text('نسخ'),
                                                  onTap: () => Navigator.pop(
                                                      context, 'copy')),
                                              if (isMine)
                                                ListTile(
                                                  leading: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red),
                                                  title: const Text('حذف'),
                                                  onTap: () => Navigator.pop(
                                                      context, 'delete'),
                                                ),
                                              ListTile(
                                                  leading:
                                                      const Icon(Icons.close),
                                                  title: const Text('إغلاق'),
                                                  onTap: () => Navigator.pop(
                                                      context, null)),
                                            ],
                                          ),
                                        ),
                                      );
                                      if (choice == 'copy') {
                                        final text = data['text'] ?? '';
                                        await Clipboard.setData(ClipboardData(
                                            text: text.toString()));
                                        if (mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text('تم النسخ')));
                                      } else if (choice == 'delete') {
                                        await _deleteMessage(
                                            doc.reference, isMine);
                                      }
                                    },
                                    child: _buildMessageBubble(data, isMe),
                                  ),
                                ]);
                          },
                        ),
                      ),
              ),
              if (_sendingImage) const LinearProgressIndicator(),
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.photo, color: Colors.orange),
                          onPressed: () async {
                            final url = await _pickAndUploadImage();
                            if (url != null) await _sendMessage(imageUrl: url);
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: TextField(
                              controller: _ctrl,
                              textDirection: ui.TextDirection.rtl,
                              maxLines: 5,
                              minLines: 1,
                              decoration: InputDecoration(
                                  hintText: 'اكتب رسالة...',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10)),
                              onSubmitted: (_) => _sendMessage(),
                              onChanged: (v) {
                                if (v.isNotEmpty && !_isTyping)
                                  _setTyping(true);
                                if (v.isEmpty && _isTyping) _setTyping(false);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _sendMessage,
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8)),
                            child: const Icon(Icons.send),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime dt) {
    final label = _formatDate(dt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      ),
    );
  }

  bool isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
