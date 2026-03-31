import 'package:flutter/material.dart';

class PaymentInstructionsPage extends StatelessWidget {
  final String method; // instapay OR vodafone
  final double amount;
  final String orderId;

  const PaymentInstructionsPage({
    super.key,
    required this.method,
    required this.amount,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    String paymentNumber =
        method == "instapay" ? "username@instapay" : "01012345678";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text("دفع أونلاين"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.payment, size: 100, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              "إتمام الدفع عبر:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              method == "instapay" ? "InstaPay" : "Vodafone Cash",
              style: TextStyle(fontSize: 20, color: Colors.orange),
            ),
            const SizedBox(height: 25),
            Text(
              "أرسل المبلغ التالي:",
              style: TextStyle(fontSize: 16),
            ),
            Text(
              "$amount جنيه",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SelectableText(
              paymentNumber,
              style: TextStyle(
                fontSize: 24,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text("اضغط على الرقم للنسخ"),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, "/uploadPaymentProof", arguments: {
                  "orderId": orderId,
                  "amount": amount,
                  "method": method,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
              ),
              child: Text("تم الدفع"),
            )
          ],
        ),
      ),
    );
  }
}
