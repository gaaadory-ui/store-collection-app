import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:store_collection_app/models/enums.dart'; 
import 'package:store_collection_app/models/transaction_model.dart'; 
import 'package:store_collection_app/services/database_service.dart'; // استيراد ملف السيرفس الجديد
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/services.dart';

class NewTransactionScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const NewTransactionScreen({super.key, required this.branchId, required this.branchName});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  String _selectedCurrency = 'YER'; // القيمة الافتراضية

  // دالة اختيار التاريخ
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  // دالة حفظ السند باستخدام DatabaseService
  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال المبلغ وتحديد فترة التحصيل (من - إلى)')),
      );
      return;
    }

    if (_dateTo!.isBefore(_dateFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاريخ (إلى) يجب أن يكون بعد أو يساوي تاريخ (من)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String uid = FirebaseAuth.instance.currentUser!.uid;
      // توليد معرف مستند فريد من Firestore تلقائياً
      final docRef = FirebaseFirestore.instance.collection('transactions').doc();
      
      // توليد رقم سند فريد
      final String trnNumber = 'TRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // التقاط الوقت الفعلي لحظة الحفظ
      final DateTime now = DateTime.now();

      final transaction = TransactionModel(
        id: docRef.id,
        transactionNumber: trnNumber,
        branchId: widget.branchId,
        collectorId: uid,
        amount: double.parse(_amountController.text.trim().replaceAll(',', '')),
        currency: _selectedCurrency, 
        dateFrom: _dateFrom!,
        dateTo: _dateTo!,
        transactionDate: now, 
        notes: _notesController.text.trim(),
        status: TransactionStatus.pending, 
        timestamp: now,
      );

      // استدعاء السيرفيس الجديد لحفظ البيانات
      await DatabaseService().addTransaction(transaction);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تسجيل السند رقم $trnNumber بنجاح!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء حفظ السند'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تحصيل جديد - ${widget.branchName}'),
          backgroundColor: Colors.blue,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. إدخال المبلغ والعملة
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [ThousandsSeparatorInputFormatter()], 
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'YER', child: Text('ر.ي')),
                            DropdownMenuItem(value: 'SAR', child: Text('ر.س')),
                            DropdownMenuItem(value: 'USD', child: Text('دولار')),
                          ],
                          onChanged: (value) => setState(() => _selectedCurrency = value!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. تحديد فترة التحصيل
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('فترة المبيعات المحصلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _selectDate(context, true),
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(_dateFrom == null ? 'من تاريخ' : DateFormat('yyyy-MM-dd').format(_dateFrom!)),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _selectDate(context, false),
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(_dateTo == null ? 'إلى تاريخ' : DateFormat('yyyy-MM-dd').format(_dateTo!)),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. ملاحظات
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات إضافية (اختياري)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 4. زر الحفظ
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('تسجيل واعتماد السند', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// منسق أرقام ذكي يحافظ على موقع المؤشر عند التعديل في المنتصف
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    String selectionText = newValue.text.replaceAll(',', '');
    final parts = selectionText.split('.');
    
    String formatted = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},'
    );
    
    if (parts.length > 1) {
      formatted += '.${parts[1]}';
    }

    // حساب موقع المؤشر الجديد ذكياً بناءً على الفواصل المضافة أو المحذوفة
    int commasBefore = 0;
    for (int i = 0; i < newValue.selection.end && i < newValue.text.length; i++) {
      if (newValue.text[i] == ',') commasBefore++;
    }

    int rawCharsBefore = newValue.selection.end - commasBefore;
    int newSelectionIndex = 0;
    int count = 0;
    
    while (newSelectionIndex < formatted.length && count < rawCharsBefore) {
      if (formatted[newSelectionIndex] != ',') {
        count++;
      }
      newSelectionIndex++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
  }
}