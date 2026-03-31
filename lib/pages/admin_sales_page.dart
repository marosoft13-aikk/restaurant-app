import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Clipboard
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sales Page (bilingual EN/AR) - simplified chart (no external chart package)
/// - Shows totals (sum & count) for Today / Week / Month / Year
/// - Shows a simple bar-like chart (LinearProgressIndicator) for last N days
/// - Export CSV (copies CSV to clipboard)
/// - This version ensures Arabic date formatting & RTL direction are applied.
class AdminSalesPage extends StatefulWidget {
  const AdminSalesPage({super.key});

  @override
  State<AdminSalesPage> createState() => _AdminSalesPageState();
}

class _AdminSalesPageState extends State<AdminSalesPage> {
  final CollectionReference<Map<String, dynamic>> _salesCol =
      FirebaseFirestore.instance.collection('sales');

  bool isArabic = false;
  bool loadingLang = true;

  // Chart range (days)
  int chartDays = 30;

  // optional custom range
  DateTimeRange? customRange;

  // chart aggregated (key = yyyy-MM-dd, value = total)
  Map<String, double> chartData = {};

  @override
  void initState() {
    super.initState();
    _loadLanguagePref();
    // pre-load chart
    _loadChartData();
  }

  Future<void> _ensureDateFormatting(String locale) async {
    try {
      // try some common Arabic locale identifiers too (better chance of having symbols)
      if (locale.startsWith('ar')) {
        // initialize generic and a region-specific Arabic locale
        await initializeDateFormatting('ar', null);
        try {
          await initializeDateFormatting('ar_EG', null);
        } catch (_) {}
        Intl.defaultLocale = 'ar';
      } else {
        await initializeDateFormatting(locale, null);
        Intl.defaultLocale = locale;
      }
    } catch (_) {
      // fallback: still set defaultLocale so DateFormat uses something
      Intl.defaultLocale = locale;
    }
  }

  Future<void> _loadLanguagePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool('app_is_ar') ?? false;

      // initialize date formatting for the chosen locale
      await _ensureDateFormatting(v ? 'ar' : 'en_US');

      if (mounted)
        setState(() {
          isArabic = v;
          loadingLang = false;
        });
    } catch (_) {
      // fallback
      await _ensureDateFormatting('en_US');
      if (mounted) setState(() => loadingLang = false);
    }
  }

  // Date helpers
  DateTime _startOfDay(DateTime now) => DateTime(now.year, now.month, now.day);
  DateTime _endOfDay(DateTime start) => start.add(const Duration(days: 1));
  DateTime _startOfWeek(DateTime now) {
    // Monday start
    final weekday = now.weekday;
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
  }

  DateTime _startOfMonth(DateTime now) => DateTime(now.year, now.month, 1);
  DateTime _startOfYear(DateTime now) => DateTime(now.year, 1, 1);

  Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

  Stream<QuerySnapshot<Map<String, dynamic>>> _rangeStream(
      DateTime start, DateTime end) {
    return _salesCol
        .where('createdAt', isGreaterThanOrEqualTo: _ts(start))
        .where('createdAt', isLessThan: _ts(end))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Map<String, dynamic> _summaryFromSnap(
      QuerySnapshot<Map<String, dynamic>> snap) {
    double total = 0;
    int count = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final a = data['amount'];
      if (a is num) {
        total += a.toDouble();
        count++;
      } else if (a is String) {
        final parsed = double.tryParse(a) ?? 0.0;
        total += parsed;
        if (parsed != 0.0) count++;
      }
    }
    return {'total': total, 'count': count};
  }

  // load chart data (aggregate by day) for chartDays or customRange
  Future<void> _loadChartData() async {
    DateTime start;
    DateTime end;
    final now = DateTime.now();
    if (customRange != null) {
      start = DateTime(customRange!.start.year, customRange!.start.month,
          customRange!.start.day);
      end = customRange!.end.add(const Duration(days: 1));
    } else {
      start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: chartDays - 1));
      end = now.add(const Duration(days: 1));
    }

    try {
      final snap = await _salesCol
          .where('createdAt', isGreaterThanOrEqualTo: _ts(start))
          .where('createdAt', isLessThan: _ts(end))
          .get();

      // init keys
      final Map<String, double> map = {};
      DateTime cur = DateTime(start.year, start.month, start.day);
      while (!cur.isAfter(end)) {
        final key = DateFormat('yyyy-MM-dd').format(cur);
        map[key] = 0.0;
        cur = cur.add(const Duration(days: 1));
      }

      for (final d in snap.docs) {
        final data = d.data();
        final ts = data['createdAt'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        if (dt == null) continue;
        final key = DateFormat('yyyy-MM-dd')
            .format(DateTime(dt.year, dt.month, dt.day));
        final a = data['amount'];
        double val = 0;
        if (a is num)
          val = a.toDouble();
        else if (a is String) val = double.tryParse(a) ?? 0.0;
        map[key] = (map[key] ?? 0) + val;
      }

      if (mounted)
        setState(() {
          chartData = map;
        });
    } catch (e) {
      // if there's an error (e.g., permission-denied), keep chartData as-is and show debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${isArabic ? 'فشل تحميل المخطط: ' : 'Chart load failed: '}$e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // export CSV -> copy to clipboard (avoids extra package)
  Future<void> _exportCsv({DateTimeRange? range}) async {
    try {
      DateTime start;
      DateTime end;
      if (range != null) {
        start = range.start;
        end = range.end.add(const Duration(days: 1));
      } else {
        final now = DateTime.now();
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29));
        end = now.add(const Duration(days: 1));
      }

      final snap = await _salesCol
          .where('createdAt', isGreaterThanOrEqualTo: _ts(start))
          .where('createdAt', isLessThan: _ts(end))
          .orderBy('createdAt', descending: true)
          .get();

      final sb = StringBuffer();
      sb.writeln('id,amount,createdAt,userId,note');
      for (final d in snap.docs) {
        final data = d.data();
        final id = d.id;
        final amount = data['amount'] ?? '';
        final createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
            : '';
        final userId = data['userId'] ?? '';
        final note = (data['note'] ?? '').toString().replaceAll('\n', ' ');
        sb.writeln('$id,$amount,$createdAt,$userId,"$note"');
      }

      final csv = sb.toString();
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isArabic ? 'نسخ CSV إلى الحافظة' : 'CSV copied to clipboard')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${isArabic ? 'فشل التصدير: ' : 'Export failed: '}$e'),
            backgroundColor: Colors.red));
    }
  }

  String t(String en, String ar) => isArabic ? ar : en;

  // safe short date formatter (handles failure and falls back)
  String _formatShortDate(String ymd) {
    try {
      final date = DateTime.parse(ymd);
      final locale = Intl.defaultLocale ?? (isArabic ? 'ar' : 'en_US');
      // try DateFormat.Md with current locale
      return DateFormat.Md(locale).format(date);
    } catch (_) {
      // fallback to en_US then numeric
      try {
        final date = DateTime.parse(ymd);
        return DateFormat.Md('en_US').format(date);
      } catch (_) {
        final parts = ymd.split('-');
        if (parts.length >= 3) return '${parts[2]}/${parts[1]}';
        return ymd;
      }
    }
  }

  // safe datetime formatter for list tile subtitle
  String _formatDateTime(DateTime dt) {
    final locale = Intl.defaultLocale ?? (isArabic ? 'ar' : 'en_US');
    try {
      return DateFormat.yMd(locale).add_jm().format(dt);
    } catch (_) {
      try {
        return DateFormat.yMd('en_US').add_jm().format(dt);
      } catch (_) {
        return dt.toLocal().toString();
      }
    }
  }

  // Simple "chart" built with linear progress bars
  Widget _buildSimpleChart() {
    if (chartData.isEmpty)
      return Center(child: Text(t('No chart data', 'لا توجد بيانات للمخطط')));

    final keys = chartData.keys.toList()..sort();
    final values = chartData.values.toList();
    final maxVal = values.fold<double>(0.0, (p, n) => p > n ? p : n);

    return Column(
      children: [
        for (int i = 0; i < keys.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    // use safe formatter
                    _formatShortDate(keys[i]),
                    style: const TextStyle(fontSize: 12),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: maxVal == 0 ? 0 : (chartData[keys[i]]! / maxVal),
                        color: Colors.orange,
                        backgroundColor: Colors.orange.shade100,
                        minHeight: 10,
                      ),
                      const SizedBox(height: 4),
                      Text('${chartData[keys[i]]!.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _summaryCard(String title, double amount, int count, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 6, height: 56, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${t('Total', 'الإجمالي')}: ${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14)),
                Text('${t('Count', 'العدد')}: $count',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
        ]),
      ),
    );
  }

  Widget _saleTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final amount = (d['amount'] is num)
        ? (d['amount'] as num).toDouble()
        : double.tryParse('${d['amount']}') ?? 0.0;
    final createdAt = (d['createdAt'] is Timestamp)
        ? (d['createdAt'] as Timestamp).toDate()
        : null;
    final userId = d['userId']?.toString() ?? '';
    final note = d['note']?.toString() ?? '';
    return ListTile(
      leading: const Icon(Icons.shopping_bag, color: Colors.orange),
      title: Text('${t('Amount', 'القيمة')}: ${amount.toStringAsFixed(2)}'),
      subtitle: Text(
          '${note.isNotEmpty ? note + ' — ' : ''}${userId.isNotEmpty ? 'User: $userId' : ''}${createdAt != null ? '\n${_formatDateTime(createdAt.toLocal())}' : ''}'),
      isThreeLine: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingLang) {
      return Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Scaffold(
            appBar: AppBar(
                title: Text(t('Admin Sales', 'مبيعات الأدمن')),
                backgroundColor: Colors.orange),
            body: const Center(child: CircularProgressIndicator())),
      );
    }

    final now = DateTime.now();
    final sDay = _startOfDay(now);
    final eDay = _endOfDay(sDay);
    final sWeek = _startOfWeek(now);
    final eWeek = sWeek.add(const Duration(days: 7));
    final sMonth = _startOfMonth(now);
    final eMonth = DateTime(sMonth.year, sMonth.month + 1, 1);
    final sYear = _startOfYear(now);
    final eYear = DateTime(sYear.year + 1, 1, 1);

    final dayStream = _rangeStream(sDay, eDay);
    final weekStream = _rangeStream(sWeek, eWeek);
    final monthStream = _rangeStream(sMonth, eMonth);
    final yearStream = _rangeStream(sYear, eYear);

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('Admin Sales', 'مبيعات الأدمن')),
          backgroundColor: Colors.orange,
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadChartData()),
            IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _exportCsv(range: customRange)),
            IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: customRange ??
                          DateTimeRange(
                              start: now.subtract(const Duration(days: 29)),
                              end: now));
                  if (picked != null) {
                    setState(() {
                      customRange = picked;
                    });
                    await _loadChartData();
                  }
                }),
            // language toggle: save pref and re-init date formatting
            IconButton(
                icon: Text(isArabic ? 'ع' : 'EN'),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('app_is_ar', !isArabic);

                  // initialize symbols for new locale and set default
                  final newLocale = !isArabic ? 'ar' : 'en_US';
                  await _ensureDateFormatting(newLocale);

                  setState(() {
                    isArabic = !isArabic;
                  });
                }),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _loadChartData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: dayStream,
                  builder: (ctx, snap) {
                    final s = snap.hasData
                        ? _summaryFromSnap(snap.data!)
                        : {'total': 0.0, 'count': 0};
                    return _summaryCard(t('Today', 'اليوم'),
                        s['total'] as double, s['count'] as int, Colors.blue);
                  }),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: weekStream,
                  builder: (ctx, snap) {
                    final s = snap.hasData
                        ? _summaryFromSnap(snap.data!)
                        : {'total': 0.0, 'count': 0};
                    return _summaryCard(t('This Week', 'هذا الأسبوع'),
                        s['total'] as double, s['count'] as int, Colors.green);
                  }),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: monthStream,
                  builder: (ctx, snap) {
                    final s = snap.hasData
                        ? _summaryFromSnap(snap.data!)
                        : {'total': 0.0, 'count': 0};
                    return _summaryCard(t('This Month', 'هذا الشهر'),
                        s['total'] as double, s['count'] as int, Colors.purple);
                  }),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: yearStream,
                  builder: (ctx, snap) {
                    final s = snap.hasData
                        ? _summaryFromSnap(snap.data!)
                        : {'total': 0.0, 'count': 0};
                    return _summaryCard(
                        t('This Year', 'هذه السنة'),
                        s['total'] as double,
                        s['count'] as int,
                        Colors.redAccent);
                  }),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t('Sales chart', 'مخطط المبيعات'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [
                  Text('${t('Days', 'أيام')}: $chartDays'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                      value: chartDays,
                      items: [7, 14, 30, 60, 90]
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (v) async {
                        if (v != null) {
                          setState(() => chartDays = v);
                          customRange = null;
                          await _loadChartData();
                        }
                      })
                ]),
              ]),
              const SizedBox(height: 8),
              FutureBuilder<void>(
                  future: _loadChartData(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        chartData.isEmpty)
                      return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()));
                    return _buildSimpleChart();
                  }),
              const SizedBox(height: 16),
              Text(t('Recent sales (today)', 'المبيعات الأخيرة (اليوم)'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: dayStream,
                  builder: (ctx, snap) {
                    if (snap.hasError) return Text('Error: ${snap.error}');
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty)
                      return Text(t('No sales today', 'لا توجد مبيعات اليوم'));
                    return ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) => _saleTile(docs[i]));
                  }),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                  onPressed: () => _exportCsv(range: customRange),
                  icon: const Icon(Icons.download),
                  label: Text(t('Export CSV', 'تصدير CSV'))),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}
