import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import các màn hình
import '../ui/screens/history_screen.dart';
import '../ui/screens/meal_plan_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/exercise_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/food_scan_screen.dart'; // ✅ Đã thêm Food Scan
import '../ui/screens/calorie_tracker_screen.dart'; // ✅ Đã thêm Theo dõi Calo

// Import Services & Widgets
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'user_avatar.dart'; // ⚠️ QUAN TRỌNG: Import Widget UserAvatar bạn đã tạo

class SideMenu extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  const SideMenu({super.key, this.onProfileUpdated});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  // Không cần biến _photoData nữa vì UserAvatar tự lo
  String _displayName = "";
  String _email = "";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Chỉ cần lấy tên và email để hiển thị text
      // Ảnh thì UserAvatar tự lấy Realtime rồi
      setState(() {
        _email = user.email ?? "";
        _displayName = user.displayName ?? "Người dùng";
      });

      // Lấy tên mới nhất từ Firestore (nếu có update)
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _displayName = doc.data()?['displayName'] ?? _displayName;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = ThemeService.instance.isDarkMode;
    List<Color> headerColors = isDark
        ? [const Color(0xFF2C2C2C), const Color(0xFF1F1F1F)]
        : [const Color(0xFFFF512F), const Color(0xFFDD2476)];

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(gradient: LinearGradient(colors: headerColors)),
            accountName: Text(
              _displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(_email),
            // 👇 THAY ĐỔI LỚN NHẤT: Dùng UserAvatar thay vì CircleAvatar thủ công
            currentAccountPicture: const UserAvatar(radius: 40),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _item(context, Icons.dashboard, "Trang chủ", Colors.orange, () => Navigator.pop(context)),

                _item(context, Icons.history, "Lịch sử BMI", Colors.blue, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                }),

                const Divider(),

                _item(context, Icons.restaurant_menu, "Thực đơn", Colors.green, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlanScreen()));
                }),

                // ✅ MỤC FOOD SCAN
                _item(context, Icons.camera_alt, "Quét món ăn", Colors.teal, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodScanScreen()));
                }),

                _item(context, Icons.local_fire_department_rounded, "Theo dõi Calo", Colors.orangeAccent, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CalorieTrackerScreen()));
                }),

                _item(context, Icons.fitness_center, "Bài tập", Colors.purple, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseScreen()));
                }),

                const Divider(),

                _item(context, Icons.person, "Hồ sơ", Colors.pink, () async {
                  Navigator.pop(context);
                  // Đợi người dùng sửa hồ sơ xong thì reload lại tên
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  _loadUserInfo();
                  widget.onProfileUpdated?.call();
                }),

                _item(context, Icons.settings, "Cài đặt", Colors.grey, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }),
              ],
            ),
          ),
          ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Đăng xuất", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await AuthService().signOut();
              }
          )
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: onTap,
    );
  }
}