import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:store_collection_app/models/transaction_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // أداة مساعدة لترجمة الحالة للسجل التاريخي
  String _getStatusArabicText(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'approvedByCollector': return 'معتمد من المحصل';
      case 'approvedByManager': return 'معتمد من المدير';
      case 'approvedByAccountant': return 'تم الاعتماد النهائي (المحاسب)';
      case 'editRequestedByCollector': return 'مطلوب تعديل';
      case 'pendingApprovalOfEdit': return 'تعديلات بانتظار المدير';
      case 'rejectedByManager': return 'مرفوض من المدير';
      default: return 'غير معروف';
    }
  }

  // 1. إضافة سند جديد مع السجل التاريخي (Audit Trail)
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      // نأخذ بيانات السند كـ Map
      Map<String, dynamic> data = transaction.toJson();
      
      // إضافة السجل التاريخي الأولي عند الإنشاء
      data['history'] = [
        {
          'action': 'created',
          'message': 'تم إنشاء السند وإدخاله في النظام بواسطة المحصل',
          'timestamp': Timestamp.fromDate(transaction.timestamp),
        }
      ];

      await _firestore.collection('transactions').doc(transaction.id).set(data);
    } catch (e) {
      // طباعة الخطأ لتسهيل معرفة السبب في حال ظهور رسالة الخطأ مجدداً
      print('Database Error: $e');
      throw Exception('حدث خطأ أثناء حفظ السند في قاعدة البيانات: $e');
    }
  }

  // 2. جلب السندات مع الفلاتر
  Stream<QuerySnapshot> getBranchTransactions({
    required String branchId,
    String? currency,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore.collection('transactions').where('branchId', isEqualTo: branchId);

    if (currency != null) query = query.where('currency', isEqualTo: currency);
    if (status != null) query = query.where('status', isEqualTo: status);
    if (startDate != null) query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
    if (endDate != null) query = query.where('timestamp', isLessThanOrEqualTo: endDate.add(const Duration(days: 1)));

    return query.orderBy('timestamp', descending: true).snapshots();
  }

  // 3. تحديث حالة السند (مع تسجيل الحدث في السجل)
  Future<void> updateTransactionStatus({
    required String transactionId,
    required String newStatus,
    String? managerNotes,
  }) async {
    try {
      String noteMsg = managerNotes != null && managerNotes.isNotEmpty ? '\nملاحظة: $managerNotes' : '';
      
      Map<String, dynamic> historyEntry = {
        'action': 'status_update',
        'message': 'تغيرت حالة السند إلى: ${_getStatusArabicText(newStatus)}$noteMsg',
        'timestamp': Timestamp.now(),
      };

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'last_updated': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([historyEntry]),
      };

      if (managerNotes != null && managerNotes.isNotEmpty) {
        updateData['manager_notes'] = managerNotes;
      }

      await _firestore.collection('transactions').doc(transactionId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update transaction status: $e');
    }
  }

  // 4. تقديم طلب تعديل (تسجيل القديم مقابل الجديد)
  Future<void> submitEditedTransaction({
    required String transactionId,
    required double newAmount,
    required String newCurrency,
    required DateTime newDateFrom,
    required DateTime newDateTo,
    required String newNotes,
  }) async {
    try {
      final doc = await _firestore.collection('transactions').doc(transactionId).get();
      final oldData = doc.data() as Map<String, dynamic>;

      Map<String, dynamic> historyEntry = {
        'action': 'edit_requested',
        'message': 'قام المحصل بتعديل بيانات السند وطلب الموافقة',
        'timestamp': Timestamp.now(),
        'changes': {
          'oldAmount': oldData['amount'],
          'newAmount': newAmount,
          'oldCurrency': oldData['currency'],
          'newCurrency': newCurrency,
          'oldDateFrom': oldData['dateFrom'], 
          'newDateFrom': Timestamp.fromDate(newDateFrom),
          'oldDateTo': oldData['dateTo'],
          'newDateTo': Timestamp.fromDate(newDateTo),
        }
      };

      await _firestore.collection('transactions').doc(transactionId).update({
        'pending_edit_data': {
          'amount': newAmount,
          'currency': newCurrency,
          'dateFrom': Timestamp.fromDate(newDateFrom),
          'dateTo': Timestamp.fromDate(newDateTo),
          'notes': newNotes,
        },
        'status': 'pendingApprovalOfEdit',
        'last_updated': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([historyEntry]),
      });
    } catch (e) {
      throw Exception('Failed to submit edited transaction: $e');
    }
  }

  // 5. اعتماد التعديلات 
  Future<void> approveEditRequest({
    required String transactionId,
    required Map<String, dynamic> pendingData,
  }) async {
    try {
      Map<String, dynamic> historyEntry = {
        'action': 'edit_approved',
        'message': 'وافق المدير على التعديلات وتم تغيير البيانات الأصلية للسند',
        'timestamp': Timestamp.now(),
      };
      await _firestore.collection('transactions').doc(transactionId).update({
        'amount': pendingData['amount'],
        'currency': pendingData['currency'],
        'dateFrom': pendingData['dateFrom'],
        'dateTo': pendingData['dateTo'],
        'notes': pendingData['notes'],
        'status': 'approvedByManager',
        'pending_edit_data': FieldValue.delete(),
        'manager_notes': FieldValue.delete(),
        'last_updated': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([historyEntry]),
      });
    } catch (e) {
      throw Exception('Failed to approve edit: $e');
    }
  }

  // --- دوال المحاسب ---
  Future<void> requestEditByAccountant({required String transactionId, required String accountantNotes}) async {
    try {
      Map<String, dynamic> historyEntry = {
        'action': 'edit_requested_by_accountant',
        'message': 'طلب المحاسب تعديل السند:\n$accountantNotes',
        'timestamp': Timestamp.now(),
      };
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'editRequestedByCollector', 
        'manager_notes': 'طلب تعديل من المحاسب: $accountantNotes', 
        'previous_status': 'approvedByManager', 
        'last_updated': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([historyEntry]),
      });
    } catch (e) {
      throw Exception('Failed to request edit by accountant: $e');
    }
  }

  Future<void> approveByAccountant(String transactionId) async {
    try {
      Map<String, dynamic> historyEntry = {
        'action': 'approved_by_accountant',
        'message': 'تم الاعتماد والمراجعة النهائية للسند من قبل المحاسب',
        'timestamp': Timestamp.now(),
      };
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'approvedByAccountant',
        'last_updated': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([historyEntry]),
      });
    } catch (e) {
      throw Exception('Failed to approve by accountant: $e');
    }
  }

  Future<void> rejectEditRequestByCollector({required String transactionId, required String rejectReason, required String returnToStatus}) async {
    try {
      Map<String, dynamic> historyEntry = {
        'action': 'edit_request_rejected',
        'message': 'رفض المحصل طلب التعديل مبرراً:\n$rejectReason',
        'timestamp': Timestamp.now(),
      };
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': returnToStatus, 
        'manager_notes': 'رد المحصل (رفض التعديل): $rejectReason',
        'last_updated': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([historyEntry]),
      });
    } catch (e) {
      throw Exception('Failed to reject edit request: $e');
    }
  }
}