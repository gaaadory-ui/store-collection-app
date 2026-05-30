import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedRole = 'collector';
  String? _selectedBranchId; // لتخزين الفرع المختار

  final List<String> _roles = ['collector', 'manager', 'accountant'];

  // 1. الإضافة (Create)
  Future<void> _createNewUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة جميع الحقول')));
      return;
    }

    // إذا كان مديراً يجب أن يختار فرعاً
    if (_selectedRole == 'manager' && _selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار فرع للمدير')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'TemporaryRegisterApp',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          // حفظ الفرع إذا كان مديراً، وإلا نتركه فارغاً
          'branchId': _selectedRole == 'manager' ? _selectedBranchId : null,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true, 
        });
      }

      await tempApp.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح!'), backgroundColor: Colors.green));
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        setState(() { _selectedBranchId = null; }); // تفريغ الفرع
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'خطأ أثناء الإنشاء'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. تحديث الدور (إذا تم سحب الإدارة، يتم إزالة الفرع)
  Future<void> _updateUserRole(String uid, String newRole) async {
    Map<String, dynamic> updates = {'role': newRole};
    
    // إذا تغير دوره ولم يعد مديراً، نقوم بفك ارتباطه بالفرع
    if (newRole != 'manager') {
      updates['branchId'] = FieldValue.delete(); // يحذف حقل branchId من المستند
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصلاحية بنجاح')));
  }

  // 3. الإيقاف والتفعيل
  Future<void> _toggleUserStatus(String uid, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'isActive': !currentStatus});
  }

  // 4. نافذة تعديل الفرع (نقل الموظف)
  Future<void> _showAssignBranchDialog(String uid, String currentBranchId) async {
    String? newBranchId = currentBranchId.isEmpty ? null : currentBranchId;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعيين / نقل لفرع آخر'),
          content: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('branches').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              
              final branches = snapshot.data!.docs;
              return DropdownButtonFormField<String>(
                value: newBranchId,
                decoration: const InputDecoration(labelText: 'اختر الفرع', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون فرع (إزالة)')), // خيار لإزالة الفرع
                  ...branches.map((branch) {
                    return DropdownMenuItem(
                      value: branch.id,
                      child: Text(branch['name']),
                    );
                  })
                ],
                onChanged: (value) => newBranchId = value,
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (newBranchId == null) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({'branchId': FieldValue.delete()});
                } else {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({'branchId': newBranchId});
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الفرع بنجاح')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إدارة المستخدمين والصلاحيات'), backgroundColor: Colors.blueGrey),
        body: Column(
          children: [
            ExpansionTile(
              title: const Text('إضافة مستخدم جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              leading: const Icon(Icons.person_add, color: Colors.blueGrey),
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم الموظف', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
                      const SizedBox(height: 10),
                      TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
                      const SizedBox(height: 10),
                      TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(labelText: 'الصلاحية (الدور)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.admin_panel_settings)),
                        items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role == 'manager' ? 'مدير فرع' : role == 'accountant' ? 'محاسب' : 'محصل'))).toList(),
                        onChanged: (value) => setState(() { _selectedRole = value!; }),
                      ),
                      const SizedBox(height: 10),
                      
                     // جلب الفروع وعرضها فقط إذا كان الدور 'manager'
                    if (_selectedRole == 'manager')
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('branches').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const LinearProgressIndicator();
                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBranchId,
                                  decoration: const InputDecoration(labelText: 'تعيين فرع للمدير', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)),
                                  items: snapshot.data!.docs.map((branch) => DropdownMenuItem(value: branch.id, child: Text(branch['name']))).toList(),
                                  onChanged: (value) => setState(() { _selectedBranchId = value; }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // زر إضافة فرع جديد مباشرة من هنا
                              Container(
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                                child: IconButton(
                                  icon: const Icon(Icons.add_business, color: Colors.teal),
                                  tooltip: 'إنشاء فرع جديد',
                                  onPressed: () async {
                                    // فتح نافذة سريعة لإنشاء فرع
                                    TextEditingController quickBranchController = TextEditingController();
                                    await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('فرع جديد سريع'),
                                        content: TextField(
                                          controller: quickBranchController,
                                          decoration: const InputDecoration(hintText: 'اسم الفرع'),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                          ElevatedButton(
                                            onPressed: () async {
                                              if (quickBranchController.text.isNotEmpty) {
                                                final newDoc = FirebaseFirestore.instance.collection('branches').doc();
                                                await newDoc.set({
                                                  'id': newDoc.id,
                                                  'name': quickBranchController.text.trim(),
                                                  'branch_manager_id': '', // سيتم تعيينه عند حفظ المستخدم
                                                });
                                                setState(() { _selectedBranchId = newDoc.id; }); // اختياره تلقائياً
                                                if (mounted) Navigator.pop(context);
                                              }
                                            },
                                            child: const Text('حفظ'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 15),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: _isLoading ? null : _createNewUser,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إنشاء الحساب', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(thickness: 2),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('لا يوجد مستخدمين مسجلين'));

                  final users = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final doc = users[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isActive = data['isActive'] ?? true;
                      final role = data['role'] ?? 'غير محدد';
                      final branchId = data['branchId'] ?? ''; // جلب معرف الفرع إن وجد

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        color: isActive ? Colors.white : Colors.red.shade50,
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: isActive ? Colors.blueGrey : Colors.grey, child: Icon(Icons.person, color: isActive ? Colors.white : Colors.red)),
                          title: Text(data['name'] ?? 'بدون اسم', style: TextStyle(decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough, fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['email']),
                              Text('الدور: ${role == 'manager' ? 'مدير فرع' : role == 'accountant' ? 'محاسب' : 'محصل'}', style: const TextStyle(color: Colors.blue)),
                              // عرض الفرع المرتبط فقط إذا كان مديراً ولديه فرع
                              if (role == 'manager' && branchId.isNotEmpty)
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('branches').doc(branchId).get(),
                                  builder: (context, branchSnapshot) {
                                    if (!branchSnapshot.hasData) return const Text('جاري جلب الفرع...', style: TextStyle(fontSize: 12));
                                    final branchName = (branchSnapshot.data!.data() as Map<String, dynamic>?)?['name'] ?? 'فرع محذوف';
                                    return Text('الفرع: $branchName', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                                  },
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'toggle') {
                                _toggleUserStatus(doc.id, isActive);
                              } else if (value == 'edit_branch') {
                                _showAssignBranchDialog(doc.id, branchId);
                              } else {
                                _updateUserRole(doc.id, value);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'manager', child: Text('ترقية لمدير فرع')),
                              const PopupMenuItem(value: 'collector', child: Text('تغيير لمحصل')),
                              const PopupMenuItem(value: 'accountant', child: Text('تغيير لمحاسب')),
                              const PopupMenuDivider(),
                              if (role == 'manager') // إظهار خيار تعديل الفرع فقط للمدراء
                                const PopupMenuItem(value: 'edit_branch', child: Text('نقل/تعيين فرع للمدير', style: TextStyle(color: Colors.blue))),
                              PopupMenuItem(value: 'toggle', child: Text(isActive ? 'إيقاف الحساب' : 'تفعيل الحساب', style: TextStyle(color: isActive ? Colors.red : Colors.green))),
                            ],
                          ),
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