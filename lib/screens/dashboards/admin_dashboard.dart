import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:store_collection_app/screens/admin/branch_management_screen.dart';
import 'package:store_collection_app/screens/admin/user_management_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة تحكم النظام (Admin)'),
          backgroundColor: Colors.purple.shade700,
          actions: [IconButton(
  icon: const Icon(Icons.logout),
  tooltip: 'تسجيل الخروج',
  onPressed: () async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      // هذا السطر السحري يقوم بإغلاق جميع الشاشات المتراكمة والعودة للشاشة الرئيسية (AuthGate)
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  },
)
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAdminCard(
                context,
                title: 'إدارة الفروع',
                icon: Icons.store_mall_directory,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementScreen())),
              ),
              const SizedBox(height: 20),
              _buildAdminCard(
                context,
                title: 'إدارة المستخدمين والصلاحيات',
                icon: Icons.manage_accounts,
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 45, color: color),
            const SizedBox(width: 20),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color),
          ],
        ),
      ),
    );
  }
}