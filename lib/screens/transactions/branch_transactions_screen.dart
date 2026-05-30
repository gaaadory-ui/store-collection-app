import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:store_collection_app/services/database_service.dart';
import 'package:store_collection_app/screens/transactions/transaction_details_screen.dart';

class BranchTransactionsScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const BranchTransactionsScreen({super.key, required this.branchId, required this.branchName});

  @override
  State<BranchTransactionsScreen> createState() => _BranchTransactionsScreenState();
}

class _BranchTransactionsScreenState extends State<BranchTransactionsScreen> {
  final DatabaseService _dbService = DatabaseService();
  String? _currentUserRole; 
  bool _isLoadingRole = true;

  // الفلاتر الأساسية
  String? _selectedCurrency;
  String? _selectedStatus;
  
  // فلتر تاريخ الإدخال (Timestamp)
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // فلتر فترة التحصيل (DateFrom - DateTo)
  DateTime? _periodStartDate;
  DateTime? _periodEndDate;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          _currentUserRole = doc.data()?['role'];
          _isLoadingRole = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  // --- دوال التقويم الذكية للتعديل ---
  Future<void> _pickEditDate(BuildContext context, bool isFromDate, DateTime? currentFrom, DateTime? currentTo, Function(DateTime) onPicked) async {
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

    final picked = await showDatePicker(context: context, initialDate: initialDate, firstDate: firstDate, lastDate: lastDate);
    if (picked != null) onPicked(picked);
  }

  // --- طلب التعديل (المدير) ---
  Future<void> _managerRequestEdit(String transactionId, String trnNumber) async {
    TextEditingController notesController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('طلب تعديل السند', style: TextStyle(color: Colors.orange)),
          content: TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب التعديلات المطلوبة...', border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال المطلوب')));
                  return;
                }
                Navigator.pop(context);
                try {
                  await _dbService.updateTransactionStatus(transactionId: transactionId, newStatus: 'editRequestedByCollector', managerNotes: notesController.text.trim());
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم طلب التعديل للسند $trnNumber'), backgroundColor: Colors.orange));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ'), backgroundColor: Colors.red));
                }
              },
              child: const Text('إرسال للمحصل', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- دوال المحاسب ---
  Future<void> _accountantRequestEdit(String transactionId, String trnNumber) async {
    TextEditingController notesController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('طلب تعديل السند (المحاسب)', style: TextStyle(color: Colors.orange)),
          content: TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب سبب التعديل للمحصل...', border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال المطلوب')));
                  return;
                }
                Navigator.pop(context);
                try {
                  await _dbService.requestEditByAccountant(transactionId: transactionId, accountantNotes: notesController.text.trim());
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم طلب التعديل للسند $trnNumber'), backgroundColor: Colors.orange));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ'), backgroundColor: Colors.red));
                }
              },
              child: const Text('إرسال للمحصل', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _accountantApprove(String transactionId, String trnNumber) async {
    await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('اعتماد نهائي', style: TextStyle(color: Colors.green)),
         content: Text('هل أنت متأكد من الاعتماد النهائي للسند رقم $trnNumber؟ لا يمكن التراجع بعد الاعتماد.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
             onPressed: () async {
                Navigator.pop(context);
                try {
                  await _dbService.approveByAccountant(transactionId);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاعتماد النهائي بنجاح'), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ'), backgroundColor: Colors.red));
                }
             },
             child: const Text('تأكيد الاعتماد', style: TextStyle(color: Colors.white)),
           )
         ]
       )
    );
  }

  // --- التعديل المباشر (المحصل) ---
  Future<void> _collectorProposeEdit(String transactionId, Map<String, dynamic> currentData) async {
    final TextEditingController amountController = TextEditingController(text: currentData['amount'].toString());
    final TextEditingController notesController = TextEditingController(text: currentData['notes'] ?? '');
    String selectedCurrency = currentData['currency'] ?? 'YER';
    DateTime dateFrom = (currentData['dateFrom'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime dateTo = (currentData['dateTo'] as Timestamp?)?.toDate() ?? DateTime.now();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تعديل بيانات السند', style: TextStyle(color: Colors.teal)),
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
                      onTap: () => _pickEditDate(context, true, dateFrom, dateTo, (picked) => setDialogState(() => dateFrom = picked)),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.shade400)),
                      title: Text('إلى: ${DateFormat('yyyy/MM/dd').format(dateTo)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _pickEditDate(context, false, dateFrom, dateTo, (picked) => setDialogState(() => dateTo = picked)),
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
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
                        transactionId: transactionId, newAmount: amount, newCurrency: selectedCurrency, newDateFrom: dateFrom, newDateTo: dateTo, newNotes: notesController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال التعديل للمدير للموافقة'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ'), backgroundColor: Colors.red));
                    }
                  },
                  child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('حفظ وطلب موافقة', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- دوال المساعدة للواجهة ---
  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'approvedByCollector': return 'معتمد من المحصل';
      case 'approvedByManager': return 'معتمد من المدير';
      case 'approvedByAccountant': return 'معتمد من المحاسب';
      case 'editRequestedByCollector': return 'مطلوب تعديل (عند المحصل)';
      case 'pendingApprovalOfEdit': return 'تعديل بانتظار موافقة المدير';
      case 'rejectedByManager': return 'مرفوض من المدير';
      default: return 'حالة غير معروفة';
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'approvedByAccountant') return Colors.green;
    if (status == 'rejectedByManager') return Colors.red;
    if (status == 'pendingApprovalOfEdit') return Colors.purple;
    if (status.contains('approved')) return Colors.teal;
    if (status.contains('edit')) return Colors.orange;
    return Colors.blue; 
  }

  Widget? _buildTrailingAction(String status, String transactionId, String trnNumber, Map<String, dynamic> data) {
    // إذا كان معتمداً من المحاسب، تظهر علامة الصح الخضراء للجميع
    if (status == 'approvedByAccountant') {
       return const Icon(Icons.check_circle, color: Colors.green, size: 30);
    }

    // خيارات المحاسب (تظهر فقط إذا كان السند معتمداً من المدير)
    if (_currentUserRole == 'accountant' && status == 'approvedByManager') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.orange, size: 28),
            tooltip: 'طلب تعديل من المحصل',
            onPressed: () => _accountantRequestEdit(transactionId, trnNumber),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            tooltip: 'اعتماد نهائي',
            onPressed: () => _accountantApprove(transactionId, trnNumber),
          ),
        ],
      );
    }
    
    // إخفاء الأزرار أثناء معالجة التعديلات أو الرفض
    if (status == 'editRequestedByCollector' || status == 'pendingApprovalOfEdit' || status == 'rejectedByManager') return null;

    if (_currentUserRole == 'manager') {
      return IconButton(icon: const Icon(Icons.edit_note, color: Colors.orange, size: 30), tooltip: 'إرجاع للمحصل للتعديل', onPressed: () => _managerRequestEdit(transactionId, trnNumber));
    } else if (_currentUserRole == 'collector') {
      return IconButton(icon: const Icon(Icons.edit, color: Colors.teal, size: 30), tooltip: 'تعديل السند', onPressed: () => _collectorProposeEdit(transactionId, data));
    }
    return null;
  }

  // أداة لاختيار التواريخ في شاشة الفلترة
  Widget _buildDateRangeFilter({required String title, required DateTime? start, required DateTime? end, required Function(DateTime?, DateTime?) onPicked}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: start ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  onPicked(picked, end);
                },
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(start != null ? DateFormat('yyyy/MM/dd').format(start) : 'من تاريخ', style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: end ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  onPicked(start, picked);
                },
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(end != null ? DateFormat('yyyy/MM/dd').format(end) : 'إلى تاريخ', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تصفية متقدمة للسندات'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                      value: _selectedCurrency,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('الكل')),
                        DropdownMenuItem(value: 'YER', child: Text('ريال يمني (YER)')),
                        DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                        DropdownMenuItem(value: 'USD', child: Text('دولار (USD)')),
                      ],
                      onChanged: (val) => setDialogState(() => _selectedCurrency = val),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('الكل')),
                        DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                        DropdownMenuItem(value: 'pendingApprovalOfEdit', child: Text('تعديلات بانتظار المدير')),
                        DropdownMenuItem(value: 'approvedByManager', child: Text('معتمد من المدير')),
                        DropdownMenuItem(value: 'approvedByAccountant', child: Text('معتمد من المحاسب')),
                      ],
                      onChanged: (val) => setDialogState(() => _selectedStatus = val),
                    ),
                    const Divider(height: 30, thickness: 2),
                    
                    // فلاتر التواريخ
                    _buildDateRangeFilter(
                      title: 'تاريخ إدخال السند (متى تم الحفظ):', 
                      start: _filterStartDate, end: _filterEndDate, 
                      onPicked: (s, e) => setDialogState(() { _filterStartDate = s; _filterEndDate = e; })
                    ),
                    const SizedBox(height: 15),
                    _buildDateRangeFilter(
                      title: 'فترة التحصيل (المبيعات من وإلى):', 
                      start: _periodStartDate, end: _periodEndDate, 
                      onPicked: (s, e) => setDialogState(() { _periodStartDate = s; _periodEndDate = e; })
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() { 
                      _selectedCurrency = null; _selectedStatus = null; 
                      _filterStartDate = null; _filterEndDate = null; 
                      _periodStartDate = null; _periodEndDate = null; 
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('مسح الفلاتر', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () { setState(() {}); Navigator.pop(context); },
                  child: const Text('تطبيق'),
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
    if (_isLoadingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // تحديد لون الـ AppBar بناءً على الدور (المحاسب يظهر باللون Indigo)
    Color appBarColor = Colors.teal;
    if (_currentUserRole == 'manager') appBarColor = Colors.blueGrey;
    if (_currentUserRole == 'accountant') appBarColor = Colors.indigo;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('سجل سندات: ${widget.branchName}'),
          backgroundColor: appBarColor,
          actions: [
            IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterDialog),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _dbService.getBranchTransactions(
                  branchId: widget.branchId,
                  currency: _selectedCurrency,
                  status: _selectedStatus,
                  startDate: _filterStartDate, // الفلترة عبر خوادم فايربيس (تاريخ الإدخال)
                  endDate: _filterEndDate,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return const Center(child: Text('خطأ في جلب البيانات.', style: TextStyle(color: Colors.red)));
                  
                  // جلب المستندات 
                  var transactions = snapshot.data!.docs;

                  // فلترة متقدمة محلية (Client-Side) لفترة التحصيل (لأن فايربيس لا يدعم فلترة معقدة لأكثر من حقل زمني واحد)
                  if (_periodStartDate != null || _periodEndDate != null) {
                    transactions = transactions.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final dFrom = (data['dateFrom'] as Timestamp?)?.toDate();
                      final dTo = (data['dateTo'] as Timestamp?)?.toDate();
                      if (dFrom == null || dTo == null) return false;

                      bool matches = true;
                      if (_periodStartDate != null && dFrom.isBefore(_periodStartDate!)) matches = false;
                      if (_periodEndDate != null && dTo.isAfter(_periodEndDate!.add(const Duration(days: 1)))) matches = false;
                      return matches;
                    }).toList();
                  }

                  if (transactions.isEmpty) return const Center(child: Text('لا توجد سندات مطابقة لخيارات الفلترة.'));

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
                      final String status = data['status'] ?? 'pending';

                      final dateFrom = (data['dateFrom'] as Timestamp?)?.toDate();
                      final dateTo = (data['dateTo'] as Timestamp?)?.toDate();
                      String dateRange = 'غير محدد';
                      if (dateFrom != null && dateTo != null) {
                        dateRange = '${DateFormat('yyyy/MM/dd').format(dateFrom)} إلى ${DateFormat('yyyy/MM/dd').format(dateTo)}';
                      }
                      
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionDetailsScreen(transactionData: data, transactionId: doc.id)));
                          },
                          leading: CircleAvatar(backgroundColor: _getStatusColor(status).withOpacity(0.2), child: Icon(Icons.receipt_long, color: _getStatusColor(status))),
                          title: Text('مبلغ: $formattedAmount $currency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('رقم السند: $trnNumber', style: const TextStyle(color: Colors.grey)),
                                const SizedBox(height: 3),
                                Text('الفترة: $dateRange', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                  child: Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          isThreeLine: true,
                          trailing: _buildTrailingAction(status, doc.id, trnNumber, data),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}