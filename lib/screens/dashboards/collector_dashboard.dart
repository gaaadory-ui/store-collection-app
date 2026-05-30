import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:store_collection_app/screens/transactions/new_transaction_screen.dart';
import 'package:store_collection_app/screens/transactions/branch_transactions_screen.dart';
import 'package:store_collection_app/screens/transactions/collector_edit_requests_screen.dart';

class CollectorDashboard extends StatelessWidget {
  // تمرير بيانات الفرع الخاص بالمحصل
  final String branchId;
  final String branchName;

  const CollectorDashboard({
    super.key,
    this.branchId = 'BRANCH_001', // قيمة افتراضية للتجربة
    this.branchName = 'الفرع الرئيسي',
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة المحصل'),
          backgroundColor: Colors.teal,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
              tooltip: 'تسجيل الخروج',
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              
              // الترحيب
              Text(
                'مرحباً، بطل التحصيل 💪',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'الفرع الحالي: $branchName',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 1. زر إضافة سند جديد
              _buildDashboardCard(
                context: context,
                title: 'إضافة سند تحصيل جديد',
                subtitle: 'إدخال بيانات مبلغ محصل جديد ورفعه للاعتماد',
                icon: Icons.add_circle_outline,
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewTransactionScreen(
                        branchId: branchId,
                        branchName: branchName,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),

              // 2. زر السندات التي تتطلب تعديل
              _buildDashboardCard(
                context: context,
                title: 'سندات تتطلب تعديلاً',
                subtitle: 'مراجعة وتصحيح السندات المعادة من الإدارة',
                icon: Icons.edit_notifications,
                color: Colors.orange.shade700,
                onTap: () {
                  // سنقوم بإنشاء شاشة التعديل في الخطوة القادمة
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سننتقل إلى شاشة السندات المعادة للتعديل...')),
                  );
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CollectorEditRequestsScreen(branchId: branchId, branchName: branchName),
                    ),
                  );
                  
                },
              ),

              const SizedBox(height: 20),

              // 3. زر سجل السندات
              _buildDashboardCard(
                context: context,
                title: 'سجل السندات الخاصة بي',
                subtitle: 'متابعة حالة جميع السندات التي قمت برفعها',
                icon: Icons.receipt_long,
                color: Colors.teal.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BranchTransactionsScreen(
                        branchId: branchId,
                        branchName: branchName,
                      ),
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

  // وعاء (Widget) مخصص لبناء الأزرار على شكل بطاقات
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