import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
// إضافة استدعاء خدمة الـ PDF
import 'package:store_collection_app/services/pdf_service.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> transactionData;
  final String transactionId;

  const TransactionDetailsScreen({
    super.key,
    required this.transactionData,
    required this.transactionId,
  });

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار (سند جديد)';
      case 'approvedByCollector': return 'معتمد من المحصل';
      case 'approvedByManager': return 'تم الاعتماد من المدير';
      case 'approvedByAccountant': return 'تم الاعتماد النهائي (المحاسب)';
      case 'editRequestedByCollector': return 'معلق - مطلوب تعديله من المحصل';
      case 'pendingApprovalOfEdit': return 'تعديل بانتظار موافقة المدير';
      case 'rejectedByManager': return 'مرفوض';
      default: return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double amount = (transactionData['amount'] as num?)?.toDouble() ?? 0.0;
    final String currency = transactionData['currency'] ?? 'YER';
    final String trnNumber = transactionData['transaction_number'] ?? '#';
    final String status = transactionData['status'] ?? 'pending';
    final String notes = transactionData['notes'] ?? 'لا توجد ملاحظات';
    final String managerNotes = transactionData['manager_notes'] ?? '';
    
    final dateFrom = (transactionData['dateFrom'] as Timestamp?)?.toDate();
    final dateTo = (transactionData['dateTo'] as Timestamp?)?.toDate();
    final creationDate = (transactionData['timestamp'] as Timestamp?)?.toDate();

    // استخراج السجل التاريخي وترتيبه من الأحدث إلى الأقدم
    List<dynamic> history = transactionData['history'] ?? [];
    List<Map<String, dynamic>> sortedHistory = List<Map<String, dynamic>>.from(history);
    sortedHistory.sort((a, b) {
      final tA = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final tB = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      return tB.compareTo(tA);
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل السند'),
          backgroundColor: Colors.blueGrey,
          actions: [
            // إضافة زر الطباعة هنا
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة السند كـ PDF',
              onPressed: () async {
                // استدعاء دالة الطباعة وتمرير بيانات السند
                await PdfService.printSingleTransaction(
                  data: transactionData,
                  branchName: 'الفرع المختار', // يمكنك مستقبلاً جلب اسم الفرع الفعلي وتمريره
                );
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // البطاقة المالية
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('رقم السند: $trnNumber', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 10),
                      Text(
                        '${NumberFormat('#,##0.##', 'en_US').format(amount)} $currency',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Chip(
                        label: Text(_getStatusText(status), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: status.contains('approved') ? Colors.green : (status == 'rejectedByManager' ? Colors.red : Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // بطاقة التواريخ
              const Text('التواريخ والفترة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.date_range, color: Colors.teal),
                      title: const Text('فترة التحصيل (من - إلى)'),
                      subtitle: Text(
                        '${dateFrom != null ? DateFormat('yyyy/MM/dd').format(dateFrom) : ''}  -  ${dateTo != null ? DateFormat('yyyy/MM/dd').format(dateTo) : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Colors.grey),
                      title: const Text('تاريخ ووقت الإدخال في النظام'),
                      subtitle: Text(creationDate != null ? DateFormat('yyyy/MM/dd - hh:mm a').format(creationDate) : ''),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // بطاقة الملاحظات
              const Text('الملاحظات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ملاحظات المحصل:', style: TextStyle(color: Colors.grey)),
                      Text(notes, style: const TextStyle(fontSize: 16)),
                      if (managerNotes.isNotEmpty) ...[
                        const Divider(height: 20),
                        const Text('رد / ملاحظات الإدارة:', style: TextStyle(color: Colors.red)),
                        Text(managerNotes, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // القسم الجديد: سجل حركات السند (Audit Trail)
              const Text('سجل حركات السند (Audit Trail)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (sortedHistory.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('لا يوجد سجل حركات لهذا السند', style: TextStyle(color: Colors.grey)),
                ))
              else
                ...sortedHistory.map((item) => _buildTimelineItem(item)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // بناء عنصر واحد في السجل الزمني
  Widget _buildTimelineItem(Map<String, dynamic> item) {
    final action = item['action'] as String?;
    final message = item['message'] as String? ?? '';
    final timestamp = (item['timestamp'] as Timestamp?)?.toDate();
    final changes = item['changes'] as Map<String, dynamic>?;

    IconData icon;
    Color color;
    
    // تخصيص الألوان والأيقونات بناءً على نوع الحركة
    switch(action) {
      case 'created': icon = Icons.add_circle; color = Colors.blue; break;
      case 'status_update': icon = Icons.sync; color = Colors.orange; break;
      case 'edit_requested': icon = Icons.edit_note; color = Colors.purple; break;
      case 'edit_approved': icon = Icons.check_circle; color = Colors.green; break;
      case 'edit_requested_by_accountant': icon = Icons.assignment_return; color = Colors.redAccent; break;
      case 'approved_by_accountant': icon = Icons.verified_user; color = Colors.green.shade800; break;
      case 'edit_request_rejected': icon = Icons.cancel; color = Colors.red; break;
      default: icon = Icons.info; color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 5),
                  if (timestamp != null)
                    Text(DateFormat('yyyy/MM/dd - hh:mm a').format(timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  // إذا كان الحدث "تعديل"، نعرض المربع الذي يوضح تفاصيل التغيير
                  if (changes != null)
                    _buildChangesDetails(changes),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء مربع تفاصيل التعديل (ماذا كان -> وماذا أصبح)
  Widget _buildChangesDetails(Map<String, dynamic> changes) {
    final oldAmount = (changes['oldAmount'] as num?)?.toDouble() ?? 0.0;
    final newAmount = (changes['newAmount'] as num?)?.toDouble() ?? 0.0;
    final oldCur = changes['oldCurrency'] ?? '';
    final newCur = changes['newCurrency'] ?? '';

    final oldDateFrom = (changes['oldDateFrom'] as Timestamp?)?.toDate();
    final newDateFrom = (changes['newDateFrom'] as Timestamp?)?.toDate();
    
    final oldDateTo = (changes['oldDateTo'] as Timestamp?)?.toDate();
    final newDateTo = (changes['newDateTo'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تفاصيل التعديل المقترح:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 12)),
          const Divider(color: Colors.black12),
          
          if (oldAmount != newAmount || oldCur != newCur)
            _buildChangeRow('المبلغ:', '${NumberFormat('#,##0.##', 'en_US').format(oldAmount)} $oldCur', '${NumberFormat('#,##0.##', 'en_US').format(newAmount)} $newCur'),
          
          if (oldDateFrom != newDateFrom)
            _buildChangeRow('من تاريخ:', oldDateFrom != null ? DateFormat('yyyy/MM/dd').format(oldDateFrom) : '', newDateFrom != null ? DateFormat('yyyy/MM/dd').format(newDateFrom) : ''),
            
          if (oldDateTo != newDateTo)
            _buildChangeRow('إلى تاريخ:', oldDateTo != null ? DateFormat('yyyy/MM/dd').format(oldDateTo) : '', newDateTo != null ? DateFormat('yyyy/MM/dd').format(newDateTo) : ''),
        ],
      ),
    );
  }

  // صف يعرض القيمة القديمة مشطوبة، وسهم، ثم القيمة الجديدة
  Widget _buildChangeRow(String label, String oldVal, String newVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: Text(oldVal, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red, fontSize: 12))),
          const Icon(Icons.arrow_back, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(newVal, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }
}