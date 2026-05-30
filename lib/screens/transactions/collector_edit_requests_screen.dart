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

  // دالة التقويم الذكي
  Future<void> _pickDate(BuildContext context, bool isFromDate, DateTime? currentFrom, DateTime? currentTo, Function(DateTime) onPicked) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime.now().add(const Duration(days: 365));

    if (isFromDate) {
      if (currentTo != null) lastDate = currentTo;
      initialDate = currentFrom ?? DateTime.now();
      if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    } else {
      if (currentFrom != null) firstDate = currentFrom;
      initialDate = currentTo ?? currentFrom ?? DateTime.now();
      if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onPicked(picked);
  }

  // 1. دالة تعديل السند
  void _showEditDialog(BuildContext context, String transactionId, Map<String, dynamic> currentData) {
    final TextEditingController amountController = TextEditingController(text: currentData['amount'].toString());
    final TextEditingController notesController = TextEditingController(text: currentData['notes'] ?? '');
    String selectedCurrency = currentData['currency'] ?? 'YER';
    DateTime dateFrom = (currentData['dateFrom'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime dateTo = (currentData['dateTo'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    bool isSaving = false; 

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
                    TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                      value: selectedCurrency,
                      items: const [
                        DropdownMenuItem(value: 'YER', child: Text('ريال يمني (YER)')),
                        DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                        DropdownMenuItem(value: 'USD', child: Text('دولار (USD)')),
                      ],
                      onChanged: (val) { if (val != null) setDialogState(() => selectedCurrency = val); },
                    ),
                    const SizedBox(height: 15),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.shade400)),
                      title: Text('من: ${DateFormat('yyyy/MM/dd').format(dateFrom)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _pickDate(context, true, dateFrom, dateTo, (picked) => setDialogState(() => dateFrom = picked)),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.shade400)),
                      title: Text('إلى: ${DateFormat('yyyy/MM/dd').format(dateTo)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _pickDate(context, false, dateFrom, dateTo, (picked) => setDialogState(() => dateTo = picked)),
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات المحصل', border: OutlineInputBorder())),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: isSaving ? null : () async {
                    if (amountController.text.trim().isEmpty) return;
                    
                    final double? amount = double.tryParse(amountController.text.trim());
                    if (amount == null) return;

                    if (dateTo.isBefore(dateFrom)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تاريخ (إلى) يجب أن يكون بعد أو يساوي تاريخ (من)'), backgroundColor: Colors.red));
                      return;
                    }

                    setDialogState(() => isSaving = true); 

                    try {
                      await _dbService.submitEditedTransaction(
                        transactionId: transactionId,
                        newAmount: amount,
                        newCurrency: selectedCurrency,
                        newDateFrom: dateFrom,
                        newDateTo: dateTo,
                        newNotes: notesController.text.trim(),
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(context); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل السند وإعادة إرساله بنجاح'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false); 
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء التعديل'), backgroundColor: Colors.red));
                    }
                  },
                  child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('حفظ وإرسال', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 2. دالة رفض طلب التعديل (في حال كان السند صحيحاً من وجهة نظر المحصل)
  Future<void> _rejectEditRequest(String transactionId, Map<String, dynamic> data) async {
    TextEditingController reasonController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('رفض طلب التعديل', style: TextStyle(color: Colors.red)),
              content: TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'اكتب سبب رفضك (مثلاً: السند والمبلغ صحيح)...', border: OutlineInputBorder()),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context), 
                  child: const Text('إلغاء')
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isSubmitting ? null : () async {
                    if (reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء كتابة السبب')));
                      return;
                    }
                    
                    setDialogState(() => isSubmitting = true);
                    
                    // العودة للحالة السابقة (إذا كان الطلب من المحاسب يعود للمحاسب، وإذا من المدير يعود للمدير)
                    String returnStatus = data['previous_status'] ?? 'pending'; 
                    
                    try {
                      await _dbService.rejectEditRequestByCollector(
                        transactionId: transactionId,
                        rejectReason: reasonController.text.trim(),
                        returnToStatus: returnStatus,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الرد بنجاح'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ'), backgroundColor: Colors.red));
                    }
                  },
                  child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
                )
              ]
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
        appBar: AppBar(title: const Text('سندات تتطلب تعديلاً'), backgroundColor: Colors.orange.shade700),
        body: StreamBuilder<QuerySnapshot>(
          stream: _dbService.getBranchTransactions(branchId: widget.branchId, status: 'editRequestedByCollector'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return const Center(child: Text('حدث خطأ في جلب البيانات.', style: TextStyle(color: Colors.red)));
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
                final String managerNotes = data['manager_notes'] ?? 'لا توجد ملاحظات مرفقة';
                
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade300, width: 1)),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('رقم السند: $trnNumber', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text('$formattedAmount $currency', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                                  const SizedBox(width: 8),
                                  Text('السبب / ملاحظات التعديل:', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(managerNotes, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        // أزرار الإجراءات (تعديل أو رفض)
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () => _showEditDialog(context, doc.id, data),
                                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                label: const Text('تعديل وإرسال', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: OutlinedButton.icon(
                                onPressed: () => _rejectEditRequest(doc.id, data),
                                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                label: const Text('أرفض', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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