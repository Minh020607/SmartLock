import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_lock/models/lock.dart';
import 'package:smart_lock/screens/home.dart';
import '../providers/lock_provider.dart';
// import'package:smart_lock/service.dart/mqtt_service.dart';
// import 'package:smart_lock/service.dart/history_service.dart';
class LockSettingsScreen extends ConsumerStatefulWidget {
  final LockModel lock;
  const LockSettingsScreen({super.key, required this.lock});

  @override
  ConsumerState<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends ConsumerState<LockSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? _role;
  bool _loadingRole = true;

  final _nameController = TextEditingController();
  final _shareController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _nameController.text = widget.lock.name;
    _fetchUserRole();
  //   mqttService.onStatusMessage = (data) {
  //   if (data["success"] == true) {
  //     saveHistory(action: data["action"]);
  //   }
  // };

  // mqttService.connect(widget.lock.id);
  }
  
//   void saveHistory({required String action}) {
//   historyService.save(widget.lock.id, action);
// }

  Future<void> _fetchUserRole() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      setState(() {
        _role = userDoc.data()?['role'] ?? 'user';
        _loadingRole = false;
      });
    } catch (e) {
      debugPrint('Lỗi khi lấy role: $e');
      setState(() {
        _role = 'user';
        _loadingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(lockProvider.notifier);
    final allLocks = ref.watch(lockProvider);

    final currentLock = allLocks.firstWhere(
      (l) => l.id == widget.lock.id,
      orElse: () => widget.lock,
    );

    // 🔁 Cập nhật text khi lock thay đổi
    if (_nameController.text != currentLock.name) {
      _nameController.text = currentLock.name;
    }

    if (_loadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = _role == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text("Cài đặt khóa")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// --- Đổi tên khóa ---
            TextField(
              controller: _nameController,
              enabled: isAdmin,
              decoration: InputDecoration(
                labelText: "Tên khóa",
                border: const OutlineInputBorder(),
                suffixIcon:
                    isAdmin ? const Icon(Icons.edit) : const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 20),
            if (isAdmin)
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await notifier.updateLock(currentLock.id, {
                      'name': _nameController.text.trim(),
                      'lastUpdated': DateTime.now(),
                    });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Đã lưu thay đổi')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ Lỗi khi lưu thay đổi: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text("Lưu thay đổi"),
              ),

            if (isAdmin) ...[
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),

              /// --- Chia sẻ khóa ---
              const Text(
                "Chia sẻ quyền truy cập",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _shareController,
                      decoration: const InputDecoration(
                        labelText: "Nhập email người dùng cần chia sẻ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.blue),
                    onPressed: () async {
                      final email = _shareController.text.trim();
                      if (email.isEmpty) return;

                      try {
                        // Kiểm tra user có tồn tại không
                        final uid = await notifier.findUserUidByEmail(email);
                        if (uid == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('⚠️ Người dùng $email chưa có tài khoản!'),
                              ),
                            );
                          }
                          return;
                        }

                        // Kiểm tra trùng email
                        if (currentLock.sharedWith.contains(email)&&context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ℹ️ $email đã được chia sẻ rồi.')),
                          );
                          return;
                        }

                        final updatedList =
                            List<String>.from(currentLock.sharedWith)..add(email);

                        await notifier.updateLock(currentLock.id, {
                          'sharedWith': updatedList,
                          'lastUpdated': DateTime.now(),
                        });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('👥 Đã chia sẻ cho $email')),
                          );
                          _shareController.clear();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Lỗi khi chia sẻ: $e')),
                          );
                        }
                      }
                    },
                  )
                ],
              ),

              const SizedBox(height: 20),
              const Text(
                "Danh sách người được chia sẻ:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (currentLock.sharedWith.isEmpty)
                const Text("Chưa có ai được chia sẻ.")
              else
                Column(
                  children: currentLock.sharedWith.map((email) {
                    return ListTile(
                      title: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () async {
                          try {
                            final updatedList =
                                List<String>.from(currentLock.sharedWith)
                                  ..remove(email);

                            await notifier.updateLock(currentLock.id, {
                              'sharedWith': updatedList,
                              'lastUpdated': DateTime.now(),
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('🚫 Đã hủy chia sẻ với $email')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ Lỗi khi hủy chia sẻ: $e')),
                              );
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 30),
              const Divider(),

              /// --- Xóa khóa ---
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    try {
                      await notifier.removeLock(currentLock.id);
                      if(context.mounted){
                        Navigator.pushAndRemoveUntil(
                          context, 
                          MaterialPageRoute(builder:(_)=>const HomeScreen()), 
                          (route)=>false,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Lỗi khi xóa khóa: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text("Xóa khóa"),
                ),
              ),
            ],

            if (!isAdmin)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    "⚠️ Bạn không có quyền chỉnh sửa cài đặt khóa này.",
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
