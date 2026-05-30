import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:store_collection_app/screens/branch_transactions_screen.dart';
import 'package:store_collection_app/transactions/manager_approvals_screen.dart'; // سنقوم بإنشاء هذه الشاشة في الخطوة القادمة

class ManagerDashboard extends StatelessWidget {
  // تذكر تمرير معرف واسم الفرع الخاص بهذا المدير عند الانتقال لهذه الشاشة
  final String branchId;
  final String branchName;

  const ManagerDashboard({
    super.key, 
    this.branchId = 'BRANCH_001', // قيمة افتراضية للتجربة، قم بتغييرها بما يناسبك
    this.branchName = 'الفرع الرئيسي', 
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('لوحة المدير - $branchName'),
          backgroundColor: Colors.blueGrey,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
              tooltip: 'تسجيل الخروج',
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // الترحيب بالمدير
              Text(
                'مرحباً بك مجدداً، أيها المدير 👋',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'اختر الإجراء الذي تريد القيام به لإدارة حركة السندات اليومية:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 1. زر طلبات الاعتماد والمعالجة
              _buildDashboardCard(
                context: context,
                title: 'طلبات الاعتماد المعلقة',
                subtitle: 'مراجعة، قبول، أو رفض السندات المرسلة من المحصلين',
                icon: Icons.pending_actions,
                color: Colors.amber.shade800,
                onTap: () {
                  // سنقوم بربطها بالشاشة الجديدة في الخطوة القادمة
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سنتقل الآن إلى شاشة مراجعة الطلبات المعلقة...')),
                  );
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerApprovalsScreen(branchId: branchId, branchName: branchName),
                    ),
                  );
              
                },
              ),
              
              const SizedBox(height: 20),

              // 2. زر سجل كافة السندات للفرع
              _buildDashboardCard(
                context: context,
                title: 'سجل السندات الكامل',
                subtitle: 'عرض وتصفية جميع العمليات المالية الخاصة بفرعك',
                icon: Icons.history_edu,
                color: Colors.blueGrey,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BranchTransactionsScreen(branchId: branchId, branchName: branchName),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // وعاء (Widget) مخصص لبناء الأزرار على شكل بطاقات عصرية
  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}