import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // لا يزال مطلوباً من أجل QuerySnapshot و Timestamp
import 'package:intl/intl.dart' hide TextDirection;
import 'package:store_collection_app/services/database_service.dart'; // استيراد ملف السيرفيس

class BranchTransactionsScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const BranchTransactionsScreen({super.key, required this.branchId, required this.branchName});

  @override
  State<BranchTransactionsScreen> createState() => _BranchTransactionsScreenState();
}

class _BranchTransactionsScreenState extends State<BranchTransactionsScreen> {
  // Filter States
  String? _selectedCurrency;
  String? _selectedStatus;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // Helper function to translate status
  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'approvedByCollector': return 'معتمد من المحصل';
      case 'approvedByManager': return 'معتمد من المدير';
      case 'approvedByAccountant': return 'معتمد من المحاسب';
      case 'reviewRequestedByAccountant': return 'مطلوب مراجعة (محاسب)';
      case 'reviewRequestedByManager': return 'مطلوب مراجعة (مدير)';
      case 'editRequestedByCollector': return 'مطلوب تعديل (محصل)';
      case 'rejectedByManager': return 'مرفوض من المدير';
      default: return 'حالة غير معروفة';
    }
  }

  // Helper function for status colors
  Color _getStatusColor(String status) {
    if (status == 'approvedByAccountant') return Colors.green;
    if (status == 'rejectedByManager') return Colors.red;
    if (status.contains('approved')) return Colors.teal;
    if (status.contains('review') || status.contains('edit')) return Colors.orange;
    return Colors.blue; // pending
  }

  // --- التعديل هنا: استخدام DatabaseService لجلب البيانات ---
  Stream<QuerySnapshot> _buildQuery() {
    return DatabaseService().getBranchTransactions(
      branchId: widget.branchId,
      currency: _selectedCurrency,
      status: _selectedStatus,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
    );
  }

  // Show the Filtering Dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تصفية السندات'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Currency Filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                      value: _selectedCurrency,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('الكل')),
                        const DropdownMenuItem(value: 'YER', child: Text('ريال يمني (YER)')),
                        const DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                        const DropdownMenuItem(value: 'USD', child: Text('دولار (USD)')),
                      ],
                      onChanged: (val) => setDialogState(() => _selectedCurrency = val),
                    ),
                    const SizedBox(height: 15),

                    // Status Filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                      value: _selectedStatus,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('الكل')),
                        const DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                        const DropdownMenuItem(value: 'approvedByCollector', child: Text('معتمد من المحصل')),
                        const DropdownMenuItem(value: 'approvedByManager', child: Text('معتمد من المدير')),
                        const DropdownMenuItem(value: 'approvedByAccountant', child: Text('معتمد من المحاسب')),
                        const DropdownMenuItem(value: 'rejectedByManager', child: Text('مرفوض من المدير')),
                      ],
                      onChanged: (val) => setDialogState(() => _selectedStatus = val),
                    ),
                    const SizedBox(height: 15),

                    // Date From Filter
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.shade400)),
                      title: Text(_filterStartDate == null ? 'من تاريخ' : DateFormat('yyyy/MM/dd').format(_filterStartDate!)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => _filterStartDate = picked);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Date To Filter
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: Colors.grey.shade400)),
                      title: Text(_filterEndDate == null ? 'إلى تاريخ' : DateFormat('yyyy/MM/dd').format(_filterEndDate!)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterEndDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => _filterEndDate = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Clear all filters
                    setState(() {
                      _selectedCurrency = null;
                      _selectedStatus = null;
                      _filterStartDate = null;
                      _filterEndDate = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('مسح الفلاتر', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Apply filters (triggers a rebuild of the stream)
                    setState(() {}); 
                    Navigator.pop(context);
                  },
                  child: const Text('تطبيق'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Active filters indicator widget
  Widget _buildActiveFiltersIndicator() {
    int activeCount = 0;
    if (_selectedCurrency != null) activeCount++;
    if (_selectedStatus != null) activeCount++;
    if (_filterStartDate != null || _filterEndDate != null) activeCount++;

    if (activeCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('توجد فلاتر نشطة ($activeCount)', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
          InkWell(
            onTap: () {
              setState(() {
                _selectedCurrency = null;
                _selectedStatus = null;
                _filterStartDate = null;
                _filterEndDate = null;
              });
            },
            child: const Icon(Icons.close, color: Colors.red),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('سجل سندات: ${widget.branchName}'),
          backgroundColor: Colors.orange,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'تصفية النتائج',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildActiveFiltersIndicator(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildQuery(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // === ERROR HANDLING FOR FIRESTORE INDEXES ===
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'خطأ في جلب البيانات.\n\nإذا قمت بتطبيق فلتر للتو، يرجى التحقق من (Debug Console) في VS Code والضغط على الرابط لإنشاء الفهرس (Index) المطلوب في Firebase.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('لا توجد سندات مطابقة لهذه الفلاتر.'));
                  }

                  final transactions = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final data = transactions[index].data() as Map<String, dynamic>;
                      
                      final double rawAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                      final String formattedAmount = NumberFormat('#,##0.##', 'en_US').format(rawAmount);
                      final String currency = data['currency'] ?? 'YER'; 
                      
                      final trnNumber = data['transaction_number'] ?? '#';
                      final status = data['status'] ?? 'pending';
                      
                      final dateFrom = (data['dateFrom'] as Timestamp?)?.toDate();
                      final dateTo = (data['dateTo'] as Timestamp?)?.toDate();
                      
                      String dateRange = 'تاريخ غير محدد';
                      if (dateFrom != null && dateTo != null) {
                        dateRange = '${DateFormat('yyyy/MM/dd').format(dateFrom)} إلى ${DateFormat('yyyy/MM/dd').format(dateTo)}';
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(status).withOpacity(0.2),
                            child: Icon(Icons.receipt_long, color: _getStatusColor(status)),
                          ),
                          title: Text(
                            'مبلغ: $formattedAmount $currency', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('رقم السند: $trnNumber', style: const TextStyle(color: Colors.grey)),
                                Text('الفترة: $dateRange', style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    _getStatusText(status),
                                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          isThreeLine: true,
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