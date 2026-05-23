import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../services/theme_service.dart';

class CalorieTrackerScreen extends StatefulWidget {
  const CalorieTrackerScreen({super.key});

  @override
  State<CalorieTrackerScreen> createState() => _CalorieTrackerScreenState();
}

class _CalorieTrackerScreenState extends State<CalorieTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  
  // Controllers cho phần Planner
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  
  String _gender = "Male";
  String _activityLevel = "sedentary";
  String _weightGoal = "maintain";
  
  double _calculatedBmr = 0;
  double _calculatedTdee = 0;
  double _targetCalories = 0;
  
  bool _isProfileLoaded = false;

  // Lựa chọn mức độ vận động
  final List<Map<String, String>> _activityOptions = [
    {
      "value": "sedentary",
      "title": "Ít vận động",
      "desc": "Văn phòng, ngồi nhiều, không tập thể thao"
    },
    {
      "value": "light",
      "title": "Vận động nhẹ",
      "desc": "Tập nhẹ nhàng 1 - 3 buổi/tuần"
    },
    {
      "value": "moderate",
      "title": "Vận động vừa",
      "desc": "Tập cường độ trung bình 3 - 5 buổi/tuần"
    },
    {
      "value": "active",
      "title": "Vận động nhiều",
      "desc": "Tập nặng hoặc lao động chân tay 6 - 7 buổi/tuần"
    },
  ];

  // Lựa chọn mục tiêu cân nặng
  final List<Map<String, String>> _goalOptions = [
    {
      "value": "lose",
      "title": "Giảm cân",
      "desc": "Thâm hụt calo (-500 kcal/ngày)"
    },
    {
      "value": "maintain",
      "title": "Duy trì cân nặng",
      "desc": "Giữ nguyên mức năng lượng TDEE"
    },
    {
      "value": "gain",
      "title": "Tăng cân",
      "desc": "Thặng dư calo (+500 kcal/ngày)"
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final firestoreService = FirestoreService(uid: uid);
      final profile = await firestoreService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _gender = profile['gender'] ?? "Male";
          _ageController.text = profile['age']?.toString() ?? "";
          _heightController.text = profile['height']?.toString() ?? "";
          _weightController.text = profile['weight']?.toString() ?? "";
          _activityLevel = profile['activityLevel'] ?? "sedentary";
          _weightGoal = profile['weightGoal'] ?? "maintain";
          _targetCalories = (profile['calorieGoal'] as num?)?.toDouble() ?? 2000.0;
          _isProfileLoaded = true;
          
          // Tính toán mặc định
          _calculateBmrAndTdee();
        });
      } else {
        if (mounted) {
          setState(() {
            _isProfileLoaded = true;
          });
        }
      }
    }
  }

  void _calculateBmrAndTdee() {
    final double? weight = double.tryParse(_weightController.text);
    final double? height = double.tryParse(_heightController.text);
    final int? age = int.tryParse(_ageController.text);

    if (weight == null || height == null || age == null) return;

    // 1. Tính BMR (Mifflin-St Jeor hoặc Harris-Benedict)
    // Dùng Harris-Benedict cải tiến
    double bmr = 0;
    if (_gender == "Male") {
      bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    }

    // 2. Tính TDEE dựa trên mức độ hoạt động
    double activityMultiplier = 1.2;
    switch (_activityLevel) {
      case "sedentary":
        activityMultiplier = 1.2;
        break;
      case "light":
        activityMultiplier = 1.375;
        break;
      case "moderate":
        activityMultiplier = 1.55;
        break;
      case "active":
        activityMultiplier = 1.725;
        break;
    }
    double tdee = bmr * activityMultiplier;

    // 3. Tính lượng calo mục tiêu dựa trên mục tiêu cân nặng
    double target = tdee;
    if (_weightGoal == "lose") {
      target = tdee - 500;
    } else if (_weightGoal == "gain") {
      target = tdee + 500;
    }

    // Calo mục tiêu tối thiểu an toàn là 1200 kcal đối với Nữ và 1500 kcal đối với Nam
    double minSafeCal = _gender == "Male" ? 1500 : 1200;
    if (target < minSafeCal) {
      target = minSafeCal;
    }

    setState(() {
      _calculatedBmr = bmr;
      _calculatedTdee = tdee;
      _targetCalories = target;
    });
  }

  Future<void> _saveCalorieGoal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _calculateBmrAndTdee();
    
    if (_targetCalories <= 0) {
      _showSnackBar("Vui lòng điền đầy đủ chiều cao, cân nặng và tuổi!", isError: true);
      return;
    }

    try {
      final firestoreService = FirestoreService(uid: uid);
      await firestoreService.updateCalorieGoal(_targetCalories, _activityLevel, _weightGoal);
      _showSnackBar("🎉 Đã lưu mục tiêu calo hàng ngày: ${_targetCalories.toInt()} kcal", isError: false);
      
      // Chuyển về tab Nhật ký sau khi lưu thành công
      _tabController.animateTo(0);
    } catch (e) {
      _showSnackBar("Lỗi lưu mục tiêu: $e", isError: true);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Hộp thoại thêm món ăn thủ công
  Future<void> _showAddMealDialog({String? defaultMealType}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final nameController = TextEditingController();
    final calorieController = TextEditingController();
    String selectedMealType = defaultMealType ?? "Bữa sáng";

    final mealTypes = ["Bữa sáng", "Bữa trưa", "Bữa tối", "Bữa phụ"];

    await showDialog(
      context: context,
      builder: (context) {
        final bool isDark = ThemeService.instance.isDarkMode;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: isDark ? Colors.greenAccent : const Color(0xFF52BE80)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Thêm món ăn thủ công",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: "Tên món ăn/thực phẩm",
                        hintText: "Ví dụ: Phở bò, Sữa chua...",
                        labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: calorieController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: "Lượng Calo (kcal)",
                        hintText: "Ví dụ: 350",
                        labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMealType,
                      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: "Loại bữa ăn",
                        labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: mealTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedMealType = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final double? calVal = double.tryParse(calorieController.text);

                    if (name.isEmpty || calVal == null || calVal <= 0) {
                      _showSnackBar("Vui lòng nhập tên và lượng calo hợp lệ!", isError: true);
                      return;
                    }

                    try {
                      final service = FirestoreService(uid: uid);
                      await service.addMeal(name, calVal, selectedMealType);
                      Navigator.pop(context);
                      _showSnackBar("Đã thêm '$name' vào $selectedMealType!", isError: false);
                    } catch (e) {
                      _showSnackBar("Không thể thêm: $e", isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF52BE80),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Thêm"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMeal(String mealId, String mealName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final service = FirestoreService(uid: uid);
      await service.deleteMeal(mealId);
      _showSnackBar("Đã xóa '$mealName'", isError: false);
    } catch (e) {
      _showSnackBar("Lỗi khi xóa: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeService.instance.isDarkMode;
    Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Theo Dõi Calo Dinh Dưỡng", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF667eea),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
          indicatorColor: const Color(0xFF667eea),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_rounded), text: "Nhật ký ăn uống"),
            Tab(icon: Icon(Icons.calculate_rounded), text: "Lập kế hoạch Calo"),
          ],
        ),
      ),
      body: !_isProfileLoaded
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildDiaryTab(isDark),
          _buildPlannerTab(isDark),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
        onPressed: () => _showAddMealDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Ghi món ăn", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF52BE80),
      )
          : null,
    );
  }

  // ============ TAB 1: NHẬT KÝ ĂN UỐNG ============
  Widget _buildDiaryTab(bool isDark) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Vui lòng đăng nhập!"));

    final firestoreService = FirestoreService(uid: uid);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: firestoreService.getUserProfileStream(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final double calorieGoal = (profile?['calorieGoal'] as num?)?.toDouble() ?? 2000.0;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestoreService.getDailyMealsStream(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<Map<String, dynamic>> meals = snapshot.data ?? [];
            double totalConsumed = 0;
            for (var m in meals) {
              totalConsumed += (m['calories'] as num?)?.toDouble() ?? 0.0;
            }

            // Phân nhóm bữa ăn
            final breakfastMeals = meals.where((m) => m['mealType'] == "Bữa sáng").toList();
            final lunchMeals = meals.where((m) => m['mealType'] == "Bữa trưa").toList();
            final dinnerMeals = meals.where((m) => m['mealType'] == "Bữa tối").toList();
            final snackMeals = meals.where((m) => m['mealType'] == "Bữa phụ").toList();

            return RefreshIndicator(
              onRefresh: () async => _loadUserProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Thanh chọn ngày
                    _buildDateSelector(isDark),
                    const SizedBox(height: 20),

                    // Vòng tròn calo
                    _buildCalorieCard(totalConsumed, calorieGoal, isDark),
                    const SizedBox(height: 24),

                    // Các bữa ăn trong ngày
                    _buildMealSection("Bữa sáng", breakfastMeals, Icons.wb_sunny_outlined, Colors.amber, isDark),
                    const SizedBox(height: 16),
                    _buildMealSection("Bữa trưa", lunchMeals, Icons.light_mode, Colors.orange, isDark),
                    const SizedBox(height: 16),
                    _buildMealSection("Bữa tối", dinnerMeals, Icons.nights_stay_outlined, Colors.indigo, isDark),
                    const SizedBox(height: 16),
                    _buildMealSection("Bữa phụ", snackMeals, Icons.cookie_outlined, Colors.brown, isDark),
                    const SizedBox(height: 80), // Chừa khoảng trống cho FAB
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateSelector(bool isDark) {
    String formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final today = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    String dayLabel = "";
    if (_selectedDate.year == today.year && _selectedDate.month == today.month && _selectedDate.day == today.day) {
      dayLabel = " (Hôm nay)";
    } else if (_selectedDate.year == yesterday.year && _selectedDate.month == yesterday.month && _selectedDate.day == yesterday.day) {
      dayLabel = " (Hôm qua)";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Expanded(
            child: InkWell(
              onTap: _selectDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, color: const Color(0xFF667eea), size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "$formattedDate$dayLabel",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _selectedDate.isAfter(today.subtract(const Duration(days: 1))) && 
                _selectedDate.year == today.year && _selectedDate.month == today.month && _selectedDate.day == today.day
                ? null
                : () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(double consumed, double goal, bool isDark) {
    double pct = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    double remaining = goal - consumed;
    Color gaugeColor = pct >= 1.0 ? Colors.redAccent : const Color(0xFF52BE80);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 14,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${consumed.toInt()}",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "đã nạp (kcal)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      remaining >= 0 ? "Còn lại: ${remaining.toInt()}" : "Vượt quá: ${remaining.abs().toInt()}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: remaining >= 0
                            ? (isDark ? Colors.greenAccent : const Color(0xFF27AE60))
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatsItem("Mục tiêu", "${goal.toInt()} kcal", Icons.flag_rounded, Colors.blue, isDark),
              Container(width: 1, height: 35, color: isDark ? Colors.white10 : Colors.grey[300]),
              _buildStatsItem("Đã nạp", "${consumed.toInt()} kcal", Icons.local_fire_department_rounded, Colors.orange, isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatsItem(String label, String val, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSection(
      String title,
      List<Map<String, dynamic>> mealsList,
      IconData icon,
      Color color,
      bool isDark,
      ) {
    double totalCalories = 0;
    for (var m in mealsList) {
      totalCalories += (m['calories'] as num?)?.toDouble() ?? 0.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề phần bữa ăn
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  "${totalCalories.toInt()} kcal",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, color: Colors.grey.shade400, size: 20),
                  onPressed: () => _showAddMealDialog(defaultMealType: title),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Danh sách món ăn
          if (mealsList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  "Chưa có món ăn nào",
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.grey.shade400, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mealsList.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final meal = mealsList[index];
                final mealName = meal['name'] ?? "";
                final mealCalories = (meal['calories'] as num?)?.toDouble() ?? 0.0;
                final mealId = meal['id'] ?? "";

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  title: Text(
                    mealName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${mealCalories.toInt()} kcal",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 18),
                        onPressed: () => _deleteMeal(mealId, mealName),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============ TAB 2: LẬP KẾ HOẠCH CALO (PLANNER) ============
  Widget _buildPlannerTab(bool isDark) {
    Color cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bảng tính chỉ số BMR/TDEE
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate_rounded, color: Color(0xFF667eea), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      "Công cụ tính BMR & TDEE",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Giới tính
                Row(
                  children: [
                    Text(
                      "Giới tính: ",
                      style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        Radio<String>(
                          value: "Male",
                          groupValue: _gender,
                          activeColor: const Color(0xFF667eea),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _gender = val;
                              });
                              _calculateBmrAndTdee();
                            }
                          },
                        ),
                        Text("Nam", style: TextStyle(color: textColor)),
                        const SizedBox(width: 16),
                        Radio<String>(
                          value: "Female",
                          groupValue: _gender,
                          activeColor: const Color(0xFF667eea),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _gender = val;
                              });
                              _calculateBmrAndTdee();
                            }
                          },
                        ),
                        Text("Nữ", style: TextStyle(color: textColor)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tuổi, Chiều cao, Cân nặng
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: "Tuổi",
                          suffixText: "tuổi",
                        ),
                        onChanged: (v) => _calculateBmrAndTdee(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: "Chiều cao",
                          suffixText: "cm",
                        ),
                        onChanged: (v) => _calculateBmrAndTdee(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: "Cân nặng",
                          suffixText: "kg",
                        ),
                        onChanged: (v) => _calculateBmrAndTdee(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tần suất hoạt động
                Text(
                  "Tần suất vận động:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _activityLevel,
                  dropdownColor: cardBg,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  items: _activityOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt['value']!,
                      child: Text(opt['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _activityLevel = val;
                      });
                      _calculateBmrAndTdee();
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _activityOptions.firstWhere((element) => element['value'] == _activityLevel)['desc']!,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Mục tiêu cân nặng
                Text(
                  "Mục tiêu cân nặng:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _weightGoal,
                  dropdownColor: cardBg,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  items: _goalOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt['value']!,
                      child: Text(opt['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _weightGoal = val;
                      });
                      _calculateBmrAndTdee();
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _goalOptions.firstWhere((element) => element['value'] == _weightGoal)['desc']!,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Kết quả tính toán
          if (_targetCalories > 0) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E3A2F), const Color(0xFF11221A)]
                      : [const Color(0xFFE8F8F5), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF275A43) : const Color(0xFFA3E4D7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, color: Color(0xFF52BE80), size: 24),
                      const SizedBox(width: 10),
                      Text(
                        "Kết quả phân tích",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "BMR (Năng lượng nền):",
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_calculatedBmr.toInt()} kcal",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "TDEE (Năng lượng tiêu thụ):",
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_calculatedTdee.toInt()} kcal",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Lượng Calo khuyến nghị hàng ngày:",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${_targetCalories.toInt()} kcal/ngày",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.greenAccent : const Color(0xFF27AE60),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveCalorieGoal,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text(
                        "Áp dụng mục tiêu này",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF52BE80),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
