import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountantDashboard extends StatelessWidget {
  const AccountantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة المحاسب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            )
          ],
        ),
        body: const Center(
          child: Text('شاشة إدخال الإيرادات ورفع الإشعارات ستكون هنا', 
            style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}