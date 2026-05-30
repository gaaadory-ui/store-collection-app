import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:store_collection_app/screens/transactions/branch_transactions_screen.dart';
import 'package:store_collection_app/services/pdf_service.dart';

class AccountantDashboard extends StatelessWidget {
  final String branchId;
  final String branchName;

  const AccountantDashboard({super.key, required this.branchId, required this.branchName});

  // دالة لإظهار نافذة اختيار التواريخ ثم استخراج التقرير
  Future<void> _generateReportDialog(BuildContext context) async {
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();
    bool isGenerating = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('استخراج تقرير السندات', style: TextStyle(color: Colors.indigo)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('حدد الفترة الزمنية لتاريخ إدخال السندات:'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if(picked != null) setDialogState(() => startDate = picked);
                          },
                          child: Text('من: ${startDate.year}/${startDate.month}/${startDate.day}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: endDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if(picked != null) setDialogState(() => endDate = picked);
                          },
                          child: Text('إلى: ${endDate.year}/${endDate.month}/${endDate.day}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: isGenerating ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: isGenerating ? null : () async {
                    setDialogState(() => isGenerating = true);
                    try {
                      // جلب السندات لهذه الفترة من فايربيس
                      final querySnapshot = await FirebaseFirestore.instance
                          .collection('transactions')
                          .where('branchId', isEqualTo: branchId)
                          .where('timestamp', isGreaterThanOrEqualTo: startDate)
                          .where('timestamp', isLessThanOrEqualTo: endDate.add(const Duration(days: 1)))
                          .orderBy('timestamp', descending: true)
                          .get();

                      if (querySnapshot.docs.isEmpty) {
                        setDialogState(() => isGenerating = false);
                        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد سندات في هذه الفترة')));
                        return;
                      }

                      // إرسال البيانات لدالة الطباعة
                      await PdfService.printTransactionsReport(
                        transactions: querySnapshot.docs,
                        branchName: branchName,
                        startDate: startDate,
                        endDate: endDate,
                      );
                      
                      if(context.mounted) Navigator.pop(context);
                    } catch (e) {
                      setDialogState(() => isGenerating = false);
                      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                    }
                  },
                  child: isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('استخراج PDF', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('لوحة المحاسب - $branchName'),
          backgroundColor: Colors.indigo,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Text('المراجعة المالية للفرع', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo.shade800), textAlign: TextAlign.center),
              const SizedBox(height: 30),

              _buildDashboardCard(
                context,
                title: 'سجل السندات والاعتماد',
                subtitle: 'مراجعة السندات، واعتمادها نهائياً أو طلب تعديلها',
                icon: Icons.fact_check,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => BranchTransactionsScreen(branchId: branchId, branchName: branchName)));
                },
              ),
              
              const SizedBox(height: 20),

              _buildDashboardCard(
                context,
                title: 'استخراج تقارير PDF',
                subtitle: 'تحديد فترة زمنية وتصدير جدول بالسندات',
                icon: Icons.picture_as_pdf,
                color: Colors.red.shade700,
                onTap: () => _generateReportDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 35, color: color)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}