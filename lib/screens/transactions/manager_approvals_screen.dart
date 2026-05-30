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

  // --- دوال تبويبة الطلبات الجديدة ---
  
  Future<void> _approveNewTransaction(String transactionId, String trnNumber) async {
    _showLoadingDialog();
    try {
      await _dbService.updateTransactionStatus(
        transactionId: transactionId,
        newStatus: 'approvedByManager',
      );
      _closeLoadingAndShowSnackBar('تم اعتماد السند رقم $trnNumber بنجاح', Colors.green);
    } catch (e) {
      _closeLoadingAndShowSnackBar('حدث خطأ أثناء الاعتماد', Colors.red);
    }
  }

  Future<void> _rejectTransaction(String transactionId, String trnNumber, String actionType) async {
    TextEditingController notesController = TextEditingController();
    
    // actionType: 'reject' (رفض نهائي) أو 'edit' (طلب تعديل من المحصل)
    bool isReject = actionType == 'reject';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isReject ? 'رفض السند' : 'طلب تعديل السند', 
                      style: TextStyle(color: isReject ? Colors.red : Colors.orange)),
          content: TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isReject ? 'اكتب سبب الرفض هنا...' : 'اكتب التعديلات المطلوبة (مثال: تأكد من المبلغ)...',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isReject ? Colors.red : Colors.orange),
              onPressed: () async {
                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال السبب/الملاحظة')));
                  return;
                }
                
                Navigator.pop(context);
                _showLoadingDialog();

                try {
                  await _dbService.updateTransactionStatus(
                    transactionId: transactionId,
                    newStatus: isReject ? 'rejectedByManager' : 'editRequestedByCollector',
                    managerNotes: notesController.text.trim(),
                  );
                  _closeLoadingAndShowSnackBar(
                    isReject ? 'تم رفض السند $trnNumber' : 'تم إرسال طلب تعديل للسند $trnNumber', 
                    isReject ? Colors.red : Colors.orange
                  );
                } catch (e) {
                  _closeLoadingAndShowSnackBar('حدث خطأ أثناء تنفيذ العملية', Colors.red);
                }
              },
              child: Text(isReject ? 'تأكيد الرفض' : 'إرسال للمحصل', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- دوال تبويبة طلبات التعديل ---

  Future<void> _approveEdit(String transactionId, String trnNumber, Map<String, dynamic> pendingData) async {
    _showLoadingDialog();
    try {
      await _dbService.approveEditRequest(
        transactionId: transactionId,
        pendingData: pendingData,
      );
      _closeLoadingAndShowSnackBar('تم اعتماد التعديلات للسند $trnNumber بنجاح', Colors.green);
    } catch (e) {
      _closeLoadingAndShowSnackBar('حدث خطأ أثناء اعتماد التعديلات', Colors.red);
    }
  }

  Future<void> _rejectEdit(String transactionId, String trnNumber) async {
    // إذا رفض المدير التعديل، نعيد السند إلى المحصل ليقوم بتعديله مجدداً
    _showLoadingDialog();
    try {
      await _dbService.updateTransactionStatus(
        transactionId: transactionId,
        newStatus: 'editRequestedByCollector',
        managerNotes: 'تم رفض التعديل الأخير، يرجى مراجعة البيانات وإعادة الإرسال بدقة.',
      );
      _closeLoadingAndShowSnackBar('تم رفض التعديل وإعادته للمحصل', Colors.orange);
    } catch (e) {
      _closeLoadingAndShowSnackBar('حدث خطأ أثناء الرفض', Colors.red);
    }
  }

  // --- دوال مساعدة ---
  
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _closeLoadingAndShowSnackBar(String message, Color color) {
    if (mounted) {
      Navigator.pop(context); // إغلاق التحميل
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      // استخدام DefaultTabController لإدارة التبويبات بسهولة
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('طلبات الاعتماد - ${widget.branchName}'),
            backgroundColor: Colors.amber.shade800,
            bottom: const TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'سندات جديدة', icon: Icon(Icons.new_releases)),
                Tab(text: 'طلبات تعديل', icon: Icon(Icons.edit_notifications)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildNewTransactionsTab(),
              _buildEditRequestsTab(),
            ],
          ),
        ),
      ),
    );
  }

  // 1. تبويبة السندات الجديدة
  Widget _buildNewTransactionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getBranchTransactions(
        branchId: widget.branchId,
        status: 'pending', // السندات الجديدة
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('حدث خطأ في جلب البيانات.', style: TextStyle(color: Colors.red)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات اعتماد معلقة حالياً!', style: TextStyle(fontSize: 18, color: Colors.grey)));
        }

        final transactions = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final data = doc.data() as Map<String, dynamic>;

            final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final String currency = data['currency'] ?? 'YER';
            final String trnNumber = data['transaction_number'] ?? '#';

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 15),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('رقم السند: $trnNumber', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text('${NumberFormat('#,##0.##', 'en_US').format(amount)} $currency',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveNewTransaction(doc.id, trnNumber),
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('اعتماد', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rejectTransaction(doc.id, trnNumber, 'reject'),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('رفض', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectTransaction(doc.id, trnNumber, 'edit'),
                        icon: const Icon(Icons.edit_note, color: Colors.white),
                        label: const Text('طلب تعديل من المحصل', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. تبويبة طلبات التعديل
  Widget _buildEditRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getBranchTransactions(
        branchId: widget.branchId,
        status: 'pendingApprovalOfEdit', // السندات التي تم تعديلها وبانتظار الموافقة
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('حدث خطأ في جلب البيانات.', style: TextStyle(color: Colors.red)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات تعديل للمراجعة.', style: TextStyle(fontSize: 18, color: Colors.grey)));
        }

        final transactions = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final data = doc.data() as Map<String, dynamic>;
            final pendingData = data['pending_edit_data'] as Map<String, dynamic>? ?? {};

            final String trnNumber = data['transaction_number'] ?? '#';
            
            // البيانات القديمة
            final double oldAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final String oldCurrency = data['currency'] ?? 'YER';
            
            // البيانات الجديدة
            final double newAmount = (pendingData['amount'] as num?)?.toDouble() ?? 0.0;
            final String newCurrency = pendingData['currency'] ?? oldCurrency;
            final String newNotes = pendingData['notes'] ?? 'لا توجد ملاحظات للتعديل';

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade300, width: 2),
              ),
              margin: const EdgeInsets.only(bottom: 15),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رقم السند: $trnNumber', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    
                    // المقارنة بين القديم والجديد
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                const Text('المبلغ القديم', style: TextStyle(color: Colors.red, fontSize: 12)),
                                Text('${NumberFormat('#,##0.##', 'en_US').format(oldAmount)} $oldCurrency',
                                  style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough)),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(Icons.arrow_forward, color: Colors.grey),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                const Text('المبلغ المقترح', style: TextStyle(color: Colors.green, fontSize: 12)),
                                Text('${NumberFormat('#,##0.##', 'en_US').format(newAmount)} $newCurrency',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('ملاحظات المحصل للتعديل: $newNotes', style: const TextStyle(fontSize: 14)),
                    
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveEdit(doc.id, trnNumber, pendingData),
                            icon: const Icon(Icons.check_circle, color: Colors.white),
                            label: const Text('اعتماد التعديل', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rejectEdit(doc.id, trnNumber),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text('رفض وإعادة', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
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
    );
  }
}