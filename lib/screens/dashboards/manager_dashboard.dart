import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// المسارات الصحيحة تم تحديثها هنا:
import 'package:store_collection_app/screens/transactions/branch_transactions_screen.dart';
import 'package:store_collection_app/screens/transactions/manager_approvals_screen.dart';

class ManagerDashboard extends StatelessWidget {
  final String branchId;
  final String branchName;

  const ManagerDashboard({
    super.key, 
    this.branchId = 'BRANCH_001', // يمكنك تمرير هذه القيم ديناميكياً لاحقاً
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
)],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // البطاقة الأولى: طلبات الاعتماد والتعديل
              _buildDashboardCard(
                context,
                title: 'طلبات الاعتماد والتعديل',
                subtitle: 'مراجعة السندات الجديدة والموافقة على التعديلات',
                icon: Icons.check_circle_outline,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManagerApprovalsScreen(
                      branchId: branchId,
                      branchName: branchName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // البطاقة الثانية: سجل العمليات
              _buildDashboardCard(
                context,
                title: 'سجل السندات والعمليات',
                subtitle: 'عرض وتصفية كافة السندات، وطلب تعديلها',
                icon: Icons.receipt_long,
                color: Colors.blueGrey,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BranchTransactionsScreen(
                      branchId: branchId,
                      branchName: branchName,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لبناء واجهة الأزرار (البطاقات) بشكل أنيق
  Widget _buildDashboardCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
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