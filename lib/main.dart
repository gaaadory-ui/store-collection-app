import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:store_collection_app/screens/auth/auth_gate.dart'; // تأكد من استدعاء ملف البوابة

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Store Collection App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // جعلنا البوابة هي الشاشة الافتراضية للتطبيق
      home: const AuthGate(), 
    );
  }
}