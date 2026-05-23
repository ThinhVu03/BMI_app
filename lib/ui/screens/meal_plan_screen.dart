import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/firestore_service.dart';
import '../../services/theme_service.dart'; // Import ThemeService

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> with TickerProviderStateMixin {
  // Lưu ý: Nên bảo mật API Key này ở phía Server nếu phát hành thật
  final String _groqApiKey = "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";

  final TextEditingController _preferenceController = TextEditingController();
  bool _isLoading = false;
  String? _aiResponse;
  bool _isJsonResponse = false;
  Map<String, dynamic>? _parsedMealPlan;
  final Set<String> _addedMeals = {};

  Map<String, dynamic>? _userData;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Quick suggestions
  final List<String> _quickSuggestions = [
    "Ít calo, nhiều protein",
    "Ăn chay, healthy",
    "Giảm cân nhanh",
    "Tăng cơ bắp",
    "Không gluten",
    "Ăn kiêng Keto",
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _preferenceController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final service = FirestoreService(uid: uid);
      final data = await service.getUserProfile();
      if (mounted) {
        setState(() {
          _userData = data;
        });
      }
    }
  }

  Future<void> _generateMealPlan() async {
    if (_groqApiKey.isEmpty) {
      _showSnackBar("Bạn chưa thêm API Key Groq!", isError: true);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _aiResponse = null;
      _isJsonResponse = false;
      _parsedMealPlan = null;
      _addedMeals.clear();
    });

    try {
      String height = _userData?['height']?.toString() ?? "chưa rõ";
      String weight = _userData?['weight']?.toString() ?? "chưa rõ";
      String age = _userData?['age']?.toString() ?? "chưa rõ";
      String gender = _userData?['gender'] == "Male" ? "Nam" : "Nữ";

      String userRequest = _preferenceController.text.trim();
      if (userRequest.isEmpty) userRequest = "Không có yêu cầu đặc biệt";

      String targetCalText = "";
      if (_userData?['calorieGoal'] != null) {
        targetCalText = "• Mục tiêu Calo hàng ngày: ${_userData!['calorieGoal'].toInt()} kcal\n";
      }

      final prompt = """
Hãy đóng vai một chuyên gia dinh dưỡng Việt Nam.
Tạo thực đơn dinh dưỡng 1 ngày gồm 3 bữa: Bữa sáng, Bữa trưa, Bữa tối.

Dữ liệu người dùng:
• Giới tính: $gender
• Tuổi: $age
• Chiều cao: $height cm
• Cân nặng: $weight kg
$targetCalText• Yêu cầu đặc biệt: $userRequest

BẮT BUỘC: Bạn phải trả về một JSON object duy nhất có cấu trúc chính xác sau (không kèm lời chào hay bất kỳ văn bản nào khác ngoài JSON):
{
  "meals": [
    {
      "type": "Bữa sáng",
      "name": "Tên món ăn sáng Việt Nam",
      "calories": 350,
      "description": "Chi tiết nguyên liệu và hướng dẫn làm ngắn gọn"
    },
    {
      "type": "Bữa trưa",
      "name": "Tên món ăn trưa Việt Nam",
      "calories": 550,
      "description": "Mô tả ngắn"
    },
    {
      "type": "Bữa tối",
      "name": "Tên món ăn tối Việt Nam",
      "calories": 450,
      "description": "Mô tả ngắn"
    }
  ],
  "total_calories": 1350,
  "advice": "Lời khuyên dinh dưỡng tổng quát bằng Tiếng Việt (sử dụng Markdown định dạng đẹp)..."
}
""";

      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_groqApiKey",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "response_format": {"type": "json_object"},
          "messages": [
            {"role": "user", "content": prompt}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Mã hóa lại utf8 để tránh lỗi font nếu có
        String content = data["choices"][0]["message"]["content"];
        try {
          content = utf8.decode(content.runes.toList());
        } catch (_) {}

        // Trích xuất JSON từ phản hồi
        String cleanJson = content.trim();
        int startIndex = cleanJson.indexOf('{');
        int endIndex = cleanJson.lastIndexOf('}');
        
        bool parsedSuccess = false;
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          cleanJson = cleanJson.substring(startIndex, endIndex + 1);
          try {
            final Map<String, dynamic> parsed = jsonDecode(cleanJson);
            if (parsed.containsKey('meals') && parsed['meals'] is List) {
              setState(() {
                _parsedMealPlan = parsed;
                _isJsonResponse = true;
                _aiResponse = content;
              });
              parsedSuccess = true;
            }
          } catch (e) {
            print("Lỗi parse JSON thực đơn: $e");
          }
        }

        if (!parsedSuccess) {
          setState(() {
            _aiResponse = content;
            _isJsonResponse = false;
            _parsedMealPlan = null;
          });
        }
        _showSnackBar("✨ Thực đơn đã sẵn sàng!", isError: false);
      } else {
        setState(() {
          _aiResponse = "Lỗi API: ${response.body}";
        });
        _showSnackBar("Không thể tạo thực đơn", isError: true);
      }
    } catch (e) {
      setState(() {
        _aiResponse = "⚠️ Lỗi kết nối AI: $e";
      });
      _showSnackBar("Lỗi kết nối: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    // Lấy trạng thái Dark Mode
    final bool isDark = ThemeService.instance.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(isDark),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(isDark),
              const SizedBox(height: 24),
              _buildUserInfoCard(isDark),
              const SizedBox(height: 24),
              _buildInputSection(isDark),
              const SizedBox(height: 20),
              _buildQuickSuggestions(isDark),
              const SizedBox(height: 24),
              _buildGenerateButton(),
              const SizedBox(height: 30),
              if (_isJsonResponse && _parsedMealPlan != null)
                _buildStructuredResult(isDark)
              else if (_aiResponse != null)
                _buildResultCard(isDark),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AI Trợ Lý Dinh Dưỡng",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            "",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF667eea),
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2C2C2C), const Color(0xFF1F1F1F)] // Gradient tối
                : [const Color(0xFF667eea), const Color(0xFF764ba2)], // Gradient sáng
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : const Color(0xFF667eea).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Thực đơn cá nhân hóa",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Được thiết kế dựa trên chỉ số BMI và sở thích của bạn",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(bool isDark) {
    if (_userData == null) return const SizedBox.shrink();

    String height = _userData?['height']?.toString() ?? "--";
    String weight = _userData?['weight']?.toString() ?? "--";
    String age = _userData?['age']?.toString() ?? "--";
    String gender = _userData?['gender'] == "Male" ? "Nam" : "Nữ";

    Color cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF667eea),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Thông tin của bạn",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem("Giới tính", gender, Icons.wc, isDark)),
              Expanded(child: _buildInfoItem("Tuổi", "$age tuổi", Icons.cake_outlined, isDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoItem("Chiều cao", "$height cm", Icons.height_rounded, isDark)),
              Expanded(child: _buildInfoItem("Cân nặng", "$weight kg", Icons.monitor_weight_outlined, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF667eea), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(bool isDark) {
    Color cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color inputFill = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F7FA);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF52BE80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF52BE80),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Bạn muốn ăn gì hôm nay?",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _preferenceController,
            style: TextStyle(fontSize: 15, color: textColor),
            decoration: InputDecoration(
              hintText: "VD: Ít calo, thích ăn thịt gà, không ăn hải sản...",
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              filled: true,
              fillColor: inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: Icon(
                Icons.restaurant_rounded,
                color: Colors.grey.shade400,
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions(bool isDark) {
    Color chipBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color chipBorder = isDark ? Colors.white24 : const Color(0xFF667eea).withOpacity(0.3);
    Color textColor = const Color(0xFF667eea); // Giữ màu tím cho nổi bật

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: isDark ? Colors.grey : Colors.grey.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "Gợi ý nhanh:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickSuggestions.map((suggestion) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _preferenceController.text = suggestion;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: chipBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: textColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      suggestion,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF52BE80), Color(0xFF27AE60)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF52BE80).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generateMealPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(width: 12),
            Text(
              "AI đang suy nghĩ...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Text(
              "Tạo thực đơn ngay",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    Color cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF52BE80).withOpacity(0.2),
                    const Color(0xFF27AE60).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF52BE80),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Thực đơn của bạn",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF52BE80).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified,
                    color: Color(0xFF52BE80),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "AI Generated",
                    style: TextStyle(
                      color: Color(0xFF52BE80),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF52BE80).withOpacity(0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: MarkdownBody(
            data: _aiResponse!,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: textColor,
              ),
              strong: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF52BE80),
              ),
              h1: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
              h2: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF52BE80),
              ),
              h3: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              listBullet: const TextStyle(
                color: Color(0xFF667eea),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addMealFromAI(String type, String name, double calories) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final String mealKey = "$type:$name";
    if (_addedMeals.contains(mealKey)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = FirestoreService(uid: uid);
      await service.addMeal(name, calories, type);
      setState(() {
        _addedMeals.add(mealKey);
      });
      _showSnackBar("Đã thêm '$name' vào Nhật ký ($type)!", isError: false);
    } catch (e) {
      _showSnackBar("Lỗi khi ghi nhận món ăn: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStructuredResult(bool isDark) {
    Color cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;
    
    final meals = _parsedMealPlan?['meals'] as List? ?? [];
    final totalCalories = _parsedMealPlan?['total_calories'] ?? 0;
    final advice = _parsedMealPlan?['advice'] ?? "";
    final double userGoal = (_userData?['calorieGoal'] as num?)?.toDouble() ?? 2000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF52BE80).withOpacity(0.2),
                    const Color(0xFF27AE60).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF52BE80),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Gợi ý thực đơn hôm nay",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Card Tóm tắt lượng Calo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF52BE80).withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    "Calo gợi ý",
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${totalCalories} kcal",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF52BE80)),
                  ),
                ],
              ),
              Container(width: 1, height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),
              Column(
                children: [
                  Text(
                    "Mục tiêu của bạn",
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${userGoal.toInt()} kcal",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Danh sách bữa ăn chính
        ...meals.map((mealData) {
          final meal = mealData as Map<String, dynamic>;
          final type = meal['type']?.toString() ?? "Bữa chính";
          final name = meal['name']?.toString() ?? "";
          final double calories = (meal['calories'] as num?)?.toDouble() ?? 0.0;
          final description = meal['description']?.toString() ?? "";
          final String mealKey = "$type:$name";
          final bool isAdded = _addedMeals.contains(mealKey);

          IconData typeIcon = Icons.restaurant;
          Color iconColor = Colors.orange;
          if (type.toLowerCase().contains("sáng")) {
            typeIcon = Icons.wb_sunny_outlined;
            iconColor = Colors.amber;
          } else if (type.toLowerCase().contains("trưa")) {
            typeIcon = Icons.light_mode;
            iconColor = Colors.orange;
          } else if (type.toLowerCase().contains("tối")) {
            typeIcon = Icons.nights_stay_outlined;
            iconColor = Colors.indigo;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(15),
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
                Row(
                  children: [
                    Icon(typeIcon, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      type,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: iconColor),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${calories.toInt()} kcal",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ),
                    const SizedBox(width: 8),
                    isAdded
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 14),
                          )
                        : IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF52BE80), size: 22),
                            onPressed: () => _addMealFromAI(type, name, calories),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 12),
        // Thẻ Lời khuyên
        if (advice.isNotEmpty) ...[
          Text(
            "Lời khuyên dinh dưỡng",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: MarkdownBody(
              data: advice,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 14, height: 1.5, color: textColor),
                strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF667eea)),
                listBullet: const TextStyle(color: Color(0xFF667eea)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}