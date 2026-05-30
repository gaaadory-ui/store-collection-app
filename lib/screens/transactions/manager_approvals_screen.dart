import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:store_collection_app/services/database_service.dart';

class ManagerApprovalsScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const ManagerApprovalsScreen({super.key, required this.branchId, required this.branchName});

  @override
  State<ManagerApprovalsScreen> createState() => _ManagerApprovalsScreenState();
}

class _ManagerApprovalsScreenState extends State<ManagerApprovalsScreen> {
  final DatabaseService _dbService = DatabaseService();

  // 1. دالة اعتماد السند
  Future<void> _approveTransaction(String transactionId, String trnNumber) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _dbService.updateTransactionStatus(
        transactionId: transactionId,
        newStatus: 'approvedByManager',
      );

      if (mounted) {
        Navigator.pop(context); // إغلاق التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم اعتماد السند رقم $trnNumber بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاعتماد: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 2. دالة رفض السند
  Future<void> _rejectTransaction(String transactionId, String trnNumber) async {
    TextEditingController notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('رفض السند', style: TextStyle(color: Colors.red)),
          content: TextField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب الرفض هنا ليراه المحصل...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يجب إدخال سبب الرفض')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  await _dbService.updateTransactionStatus(
                    transactionId: transactionId,
                    newStatus: 'rejectedByManager',
                    managerNotes: notesController.text.trim(),
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم رفض السند $trnNumber'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('حدث خطأ أثناء الرفض'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 3. دالة طلب تعديل من المحصل (الجديدة)
  Future<void> _requestEditTransaction(String transactionId, String trnNumber) async {
    TextEditingController notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('طلب تعديل السند', style: TextStyle(color: Colors.orange)),
          content: TextField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب التعديلات المطلوبة (مثال: يرجى التأكد من المبلغ المدخل)...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يجب إدخال التعديلات المطلوبة ليقرأها المحصل')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  // تحديث الحالة إلى "مطلوب تعديل من المحصل"
                  await _dbService.updateTransactionStatus(
                    transactionId: transactionId,
                    newStatus: 'editRequestedByCollector',
                    managerNotes: notesController.text.trim(),
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم إرسال طلب تعديل للسند $trnNumber'), backgroundColor: Colors.orange),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('حدث خطأ أثناء إرسال طلب التعديل'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('إرسال للمحصل', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('طلبات الاعتماد - ${widget.branchName}'),
          backgroundColor: Colors.amber.shade800,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _dbService.getBranchTransactions(
            branchId: widget.branchId,
            status: 'pending',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ في جلب البيانات، تأكد من الفهارس (Indexes).', style: TextStyle(color: Colors.red)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                    const SizedBox(height: 15),
                    const Text('لا توجد طلبات اعتماد معلقة حالياً!', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }

            final transactions = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final doc = transactions[index];
                final data = doc.data() as Map<String, dynamic>;

                final double rawAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final String formattedAmount = NumberFormat('#,##0.##', 'en_US').format(rawAmount);
                final String currency = data['currency'] ?? 'YER';
                final String trnNumber = data['transaction_number'] ?? '#';
                final String notes = data['notes'] ?? 'لا توجد ملاحظات';
                
                final dateFrom = (data['dateFrom'] as Timestamp?)?.toDate();
                final dateTo = (data['dateTo'] as Timestamp?)?.toDate();
                
                String dateRange = 'غير محدد';
                if (dateFrom != null && dateTo != null) {
                  dateRange = '${DateFormat('yyyy/MM/dd').format(dateFrom)} إلى ${DateFormat('yyyy/MM/dd').format(dateTo)}';
                }

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('رقم السند: $trnNumber', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(
                              '$formattedAmount $currency',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('الفترة: $dateRange', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text('ملاحظات المحصل: $notes', style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // أزرار الإجراءات بعد التعديل
                        Column(
                          children: [
                            // الصف الأول: قبول ورفض
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approveTransaction(doc.id, trnNumber),
                                    icon: const Icon(Icons.check, color: Colors.white),
                                    label: const Text('اعتماد', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _rejectTransaction(doc.id, trnNumber),
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    label: const Text('رفض', style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // الصف الثاني: طلب التعديل
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: () => _requestEditTransaction(doc.id, trnNumber),
                                icon: const Icon(Icons.edit_note, color: Colors.white),
                                label: const Text('طلب تعديل من المحصل', style: TextStyle(color: Colors.white, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}