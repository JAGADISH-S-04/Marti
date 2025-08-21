import 'package:flutter/material.dart';

class BuyerScreen extends StatelessWidget {
  const BuyerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Page'),
      ),
      body: const Center(
        child: Text('Welcome, Buyer!'),
      ),
    );
  }
}
