import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SalesChartPage extends StatelessWidget {
  const SalesChartPage({super.key});

  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final now = DateTime.now();
    final last7 = now.subtract(const Duration(days: 6));

    final snapshot = await FirebaseFirestore.instance
        .collection("sales")
        .where("timestamp", isGreaterThanOrEqualTo: last7)
        .orderBy("timestamp")
        .get();

    return snapshot.docs.map((doc) {
      return {
        "date": doc["timestamp"].toDate(),
        "totalSales": (doc["totalSales"] ?? 0).toDouble(),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("📊 تقرير المبيعات", style: GoogleFonts.cairo()),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder(
        future: getWeeklySales(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      "مبيعات آخر 7 أيام",
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= data.length) {
                                    return const SizedBox();
                                  }
                                  final date = data[index]["date"];
                                  return Text(
                                    "${date.day}/${date.month}",
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                          ),

                          // DATA POINTS
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              barWidth: 4,
                              color: Colors.orange,
                              spots: [
                                for (int i = 0; i < data.length; i++)
                                  FlSpot(
                                    i.toDouble(),
                                    data[i]["totalSales"],
                                  )
                              ],
                              dotData: const FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
