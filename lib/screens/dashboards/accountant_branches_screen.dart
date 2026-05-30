import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:store_collection_app/screens/dashboards/accountant_dashboard.dart';

class AccountantBranchesScreen extends StatelessWidget {
  const AccountantBranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختيار فرع (المحاسب)'),
          backgroundColor: Colors.indigo, // لون يميز شاشات المحاسب
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('branches').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد فروع مسجلة حتى الآن'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final branch = snapshot.data!.docs[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.account_balance, color: Colors.white),
                    ),
                    title: Text(branch['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () {
                      // عند الضغط، نرسل المحاسب إلى لوحته مع بيانات الفرع المختار
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccountantDashboard(
                            branchId: branch.id,
                            branchName: branch['name'],
                          ),
                        ),
                      );
                    },
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