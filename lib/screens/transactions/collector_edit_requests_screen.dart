import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:store_collection_app/services/database_service.dart';

class CollectorEditRequestsScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const CollectorEditRequestsScreen({super.key, required this.branchId, required this.branchName});

  @override
  State<CollectorEditRequestsScreen> createState() => _CollectorEditRequestsScreenState();
}

class _CollectorEditRequestsScreenState extends State<CollectorEditRequestsScreen> {
  final DatabaseService _dbService = DatabaseService();

  // دالة لإظهار نافذة التعديل وإعادة الإرسال
  void _showEditDialog(BuildContext context, String transactionId, Map<String, dynamic> currentData) {
    // تجهيز البيانات الحالية في الحقول
    final TextEditingController amountController = TextEditingController(text: currentData['amount'].toString());
    final TextEditingController notesController = TextEditingController(text: currentData['notes'] ?? '');
    String selectedCurrency = currentData['currency'] ?? 'YER';
    DateTime dateFrom = (currentData['dateFrom'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime dateTo = (currentData['dateTo'] as Timestamp?)?.toDate() ?? DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تعديل السند وإعادة إرساله', style: TextStyle(color: Colors.teal)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // حقل المبلغ
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),

                    // اختيار العملة
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                      value: selectedCurrency,
                      items: const [
                        DropdownMenuItem(value: 'YER', child: Text('ريال يمني (YER)')),
                        DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                        DropdownMenuItem(value: 'USD', child: Text('دولار (USD)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCurrency = val);
                      },
                    ),
                    const SizedBox(height: 15),

                    // تاريخ البداية
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.shade400)),
                      title: Text('من: ${DateFormat('yyyy/MM/dd').format(dateFrom)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dateFrom,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => dateFrom = picked);
                      },
                    ),
                    const SizedBox(height: 10),

                    // تاريخ النهاية
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.shade400)),
                      title: Text('إلى: ${DateFormat('yyyy/MM/dd').format(dateTo)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dateTo,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => dateTo = picked);
                      },
                    ),
                    const SizedBox(height: 15),

                    // حقل الملاحظات
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ملاحظات المحصل', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    if (amountController.text.trim().isEmpty) return;
                    
                    final double? amount = double.tryParse(amountController.text.trim());
                    if (amount == null) return;

                    Navigator.pop(context); // إغلاق نافذة التعديل
                    
                    // عرض مؤشر التحميل
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      // استبدل استدعاء resubmitTransaction بهذا الاستدعاء الجديد:
                        await _dbService.submitEditedTransaction(
                          transactionId: transactionId,
                          newAmount: amount,
                          newCurrency: selectedCurrency,
                          newDateFrom: dateFrom,
                          newDateTo: dateTo,
                          newNotes: notesController.text.trim(),
                        );
                      
                      if (context.mounted) {
                        Navigator.pop(context); // إغلاق التحميل
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تعديل السند وإعادة إرساله للمدير بنجاح'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('حدث خطأ أثناء التعديل'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ وإرسال', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
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
          title: const Text('سندات تتطلب تعديلاً'),
          backgroundColor: Colors.orange.shade700,
        ),
        body: StreamBuilder<QuerySnapshot>(
          // نجلب السندات التي طُلب تعديلها فقط
          stream: _dbService.getBranchTransactions(
            branchId: widget.branchId,
            status: 'editRequestedByCollector',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ في جلب البيانات.', style: TextStyle(color: Colors.red)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.thumb_up_alt_outlined, size: 80, color: Colors.green.shade300),
                    const SizedBox(height: 15),
                    const Text('عمل ممتاز! لا توجد أي سندات تتطلب التعديل.', style: TextStyle(fontSize: 18, color: Colors.grey)),
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
                final String managerNotes = data['manager_notes'] ?? 'لا توجد ملاحظات من المدير';
                
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange.shade300, width: 1),
                  ),
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
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        
                        // عرض رسالة المدير (سبب طلب التعديل)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                                  const SizedBox(width: 8),
                                  Text('مطلوب تعديل من الإدارة:', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(managerNotes, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // زر فتح شاشة التعديل
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showEditDialog(context, doc.id, data),
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text('تعديل وإعادة إرسال', style: TextStyle(color: Colors.white, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
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