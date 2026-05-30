import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:store_collection_app/models/transaction_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. دالة إضافة سند جديد
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toJson());
    } catch (e) {
      print('Error adding transaction: $e');
      throw e; // إعادة رمي الخطأ ليتم التقاطه في الواجهة
    }
  }

  // 2. دالة جلب السندات مع تطبيق الفلاتر ديناميكياً
  Stream<QuerySnapshot> getBranchTransactions({
    required String branchId,
    String? currency,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('transactions')
        .where('branchId', isEqualTo: branchId);

    if (currency != null) {
      query = query.where('currency', isEqualTo: currency);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      // إضافة يوم لضمان شمول نهاية اليوم المحدد (حتى 23:59:59)
      query = query.where('timestamp', isLessThanOrEqualTo: endDate.add(const Duration(days: 1)));
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }
}

// دالة لتحديث حالة السند (اعتماد، رفض، طلب مراجعة) مع إضافة ملاحظات المدير إن وجدت
Future<void> updateTransactionStatus({
  required String transactionId,
  required String newStatus,
  String? managerNotes,
}) async {
  try {
    Map<String, dynamic> updateData = {
      'status': newStatus,
      'last_updated': FieldValue.serverTimestamp(),
    };

    if (managerNotes != null && managerNotes.isNotEmpty) {
      updateData['manager_notes'] = managerNotes;
    }

    await _db.collection('transactions').doc(transactionId).update(updateData);
  } catch (e) {
    throw Exception('Failed to update transaction status: $e');
  }
}

// دالة لتعديل بيانات السند وإعادة إرساله (تغيير حالته إلى pending)
  Future<void> resubmitTransaction({
    required String transactionId,
    required double newAmount,
    required String newCurrency,
    required DateTime newDateFrom,
    required DateTime newDateTo,
    required String newNotes,
  }) async {
    try {
      await _db.collection('transactions').doc(transactionId).update({
        'amount': newAmount,
        'currency': newCurrency,
        'dateFrom': Timestamp.fromDate(newDateFrom),
        'dateTo': Timestamp.fromDate(newDateTo),
        'notes': newNotes,
        'status': 'pending', // إعادة الحالة لقيد الانتظار ليراجعها المدير
        'last_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to resubmit transaction: $e');
    }
  }

  // دالة لإعادة إرسال السند بعد التعديل لانتظار موافقة المدير
Future<void> submitEditedTransaction({
  required String transactionId,
  required double newAmount,
  required String newCurrency,
  required DateTime newDateFrom,
  required DateTime newDateTo,
  required String newNotes,
}) async {
  try {
    await _db.collection('transactions').doc(transactionId).update({
      'amount': newAmount,
      'currency': newCurrency,
      'dateFrom': Timestamp.fromDate(newDateFrom),
      'dateTo': Timestamp.fromDate(newDateTo),
      'notes': newNotes,
      'status': 'pendingApprovalOfEdit', // الحالة الجديدة المقترحة
      'last_updated': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    throw Exception('Failed to submit edited transaction: $e');
  }
}