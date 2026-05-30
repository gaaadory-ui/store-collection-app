import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// استدعاء النماذج
import 'package:store_collection_app/models/user_model.dart';
import 'package:store_collection_app/models/enums.dart';

// مسارات الشاشات الجديدة بعد الترتيب
import 'package:store_collection_app/screens/auth/login_screen.dart';
import 'package:store_collection_app/screens/dashboards/collector_dashboard.dart';
import 'package:store_collection_app/screens/dashboards/manager_dashboard.dart';
import 'package:store_collection_app/screens/dashboards/accountant_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // أثناء التحقق من حالة المستخدم
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // إذا كان المستخدم مسجلاً للدخول بالفعل
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                // هنا نستخدم UserModel الذي قمت أنت ببرمجته!
                UserModel user = UserModel.fromJson(roleSnapshot.data!.data() as Map<String, dynamic>);
                
                // التوجيه الذكي بناءً على الـ enum
                switch (user.role) {
                  case UserRole.collector:
                    return CollectorDashboard();
                  case UserRole.manager:
                    return ManagerDashboard();
                  case UserRole.accountant:
                    return AccountantDashboard();
                }
              }

              // في حال وجود حساب مسجل ولكن بلا بيانات في Firestore
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('لا توجد بيانات لهذا المستخدم أو تم حذفها.'),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('تسجيل الخروج'),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        }

        // إذا لم يكن مسجلاً للدخول
        return const LoginScreen();
      },
    );
  }
}