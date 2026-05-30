import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final TextEditingController _branchNameController = TextEditingController();

  // إضافة فرع جديد
  Future<void> _addBranch() async {
    if (_branchNameController.text.isEmpty) return;
    
    final docRef = FirebaseFirestore.instance.collection('branches').doc(); // إنشاء ID عشوائي
    await docRef.set({
      'id': docRef.id,
      'name': _branchNameController.text.trim(),
      'branch_manager_id': '', // بدون مدير في البداية
    });
    
    _branchNameController.clear();
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الفرع بنجاح')));
  }

  // حذف فرع
  Future<void> _deleteBranch(String branchId) async {
    await FirebaseFirestore.instance.collection('branches').doc(branchId).delete();
    // تنبيه: في التطبيقات الحقيقية يفضل عمل (Soft Delete) للفروع التي تحتوي على عمليات سابقة
  }

  // نافذة تعيين مدير للفرع
  Future<void> _showAssignManagerDialog(String branchId, String currentManagerId) async {
    String? selectedManagerId = currentManagerId.isEmpty ? null : currentManagerId;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعيين مدير للفرع'),
          content: StreamBuilder<QuerySnapshot>(
            // نجلب فقط المستخدمين الذين لديهم صلاحية مدير
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'manager').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              
              final managers = snapshot.data!.docs;
              if (managers.isEmpty) return const Text('لا يوجد مدراء مسجلين في النظام. أضف مديراً أولاً.');

              return DropdownButtonFormField<String>(
                value: selectedManagerId,
                decoration: const InputDecoration(labelText: 'اختر المدير', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون مدير (إزالة)')),
                  ...managers.map((manager) {
                    final data = manager.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: manager.id,
                      child: Text(data['name'] ?? 'بدون اسم'),
                    );
                  })
                ],
                onChanged: (value) => selectedManagerId = value,
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                // استخدام Batch لتحديث الفرع والمدير في نفس الوقت
                WriteBatch batch = FirebaseFirestore.instance.batch();
                
                DocumentReference branchRef = FirebaseFirestore.instance.collection('branches').doc(branchId);
                
                if (selectedManagerId == null) {
                  // إزالة المدير من الفرع
                  batch.update(branchRef, {'branch_manager_id': ''});
                  if (currentManagerId.isNotEmpty) {
                    DocumentReference oldManagerRef = FirebaseFirestore.instance.collection('users').doc(currentManagerId);
                    batch.update(oldManagerRef, {'branchId': FieldValue.delete()});
                  }
                } else {
                  // تعيين المدير الجديد
                  batch.update(branchRef, {'branch_manager_id': selectedManagerId});
                  DocumentReference newManagerRef = FirebaseFirestore.instance.collection('users').doc(selectedManagerId);
                  batch.update(newManagerRef, {'branchId': branchId});
                }

                await batch.commit();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث إدارة الفرع')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  // نافذة إضافة فرع
  void _showAddBranchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فرع جديد'),
        content: TextField(
          controller: _branchNameController,
          decoration: const InputDecoration(hintText: 'اسم الفرع (مثل: فرع سيئون)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: _addBranch, child: const Text('إضافة')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إدارة الفروع'), backgroundColor: Colors.teal),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddBranchDialog,
          icon: const Icon(Icons.add),
          label: const Text('فرع جديد'),
          backgroundColor: Colors.teal,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('branches').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد فروع'));

            final branches = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final doc = branches[index];
                final data = doc.data() as Map<String, dynamic>;
                final managerId = data['branch_manager_id'] ?? '';

                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.store, color: Colors.white)),
                    title: Text(data['name'] ?? 'فرع غير مسمى', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: managerId.isEmpty
                        ? const Text('لا يوجد مدير حالياً', style: TextStyle(color: Colors.red))
                        : FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(managerId).get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) return const Text('جاري جلب المدير...', style: TextStyle(fontSize: 12));
                              if (!userSnapshot.data!.exists) return const Text('المدير غير موجود/محذوف', style: TextStyle(color: Colors.red));
                              final managerName = (userSnapshot.data!.data() as Map<String, dynamic>?)?['name'] ?? 'مجهول';
                              return Text('المدير: $managerName', style: const TextStyle(color: Colors.green));
                            },
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.manage_accounts, color: Colors.blue),
                          tooltip: 'تعيين مدير',
                          onPressed: () => _showAssignManagerDialog(doc.id, managerId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteBranch(doc.id),
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