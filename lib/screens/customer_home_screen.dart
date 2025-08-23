import 'package:flutter/material.dart';
import 'package:arti/services/auth_service.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        backgroundColor: const Color.fromARGB(255, 93, 64, 55),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              size: 100,
              color: Color.fromARGB(255, 93, 64, 55),
            ),
            SizedBox(height: 20),
            Text(
              'Welcome Customer!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 93, 64, 55),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'You have successfully logged in!',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}