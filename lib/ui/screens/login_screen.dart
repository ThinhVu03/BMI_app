import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Giả sử bạn đã có file này, nếu chưa thì comment lại để test UI
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _logoRotateAnimation;

  // --- DARK THEME COLORS ---
  // Nền tối: Đen xanh đậm -> Đen tuyền
  final List<Color> _loginBgColors = [const Color(0xFF141E30), const Color(0xFF243B55)];
  final List<Color> _signUpBgColors = [const Color(0xFF0F2027), const Color(0xFF203A43)];

  // Màu Card: Xám đen
  final Color _cardDarkColor = const Color(0xFF1E2228);

  // Màu chữ & Icon
  final Color _textWhite = const Color(0xFFEEEEEE);
  final Color _textGrey = const Color(0xFF9AA0A6);

  // Màu Accent (Nút bấm, Icon active): Xanh Neon
  final Color _accentColor = const Color(0xFF00D2FF);
  final Color _accentColor2 = const Color(0xFF3A7BD5);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );

    _logoRotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- Logic Validation ---
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email không được để trống';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Email không đúng định dạng';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }

  // --- Logic Authentication ---
  Future<void> _handleAuthAction(Future<void> Function() action, {bool checkValidation = true}) async {
    if (!mounted) return;
    if (checkValidation) {
      if (!_formKey.currentState!.validate()) return;
    }
    try {
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {}

    setState(() => _isLoading = true);

    try {
      await action();
    } on Exception catch (e) {
      if (!mounted) return;
      final errMsg = _getErrorMessage(e);
      if (!errMsg.contains('sign_in_canceled')) {
        _safeShowSnackBar(errMsg, isError: true);
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (!errStr.contains('sign_in_canceled')) {
          _safeShowSnackBar("Đã xảy ra lỗi: $errStr", isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSubmit() {
    final email = _emailController.text.trim();
    final password = _passController.text.trim();

    _handleAuthAction(() async {
      if (_isLoginMode) {
        await _authService.signIn(email: email, password: password);
      } else {
        await _authService.signUp(email: email, password: password);
      }
    }, checkValidation: true);
  }

  // --- Logic Quên Mật Khẩu (Style Tối) ---
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    if (_emailController.text.isNotEmpty) {
      resetEmailController.text = _emailController.text;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3038), // Nền dialog tối
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(
                  "Quên mật khẩu?",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textWhite),
                ),
                const SizedBox(height: 8),
                Text(
                  "Nhập email để nhận liên kết đặt lại mật khẩu.",
                  style: TextStyle(color: _textGrey, fontSize: 14),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: _textWhite),
                  decoration: InputDecoration(
                    labelText: "Email đăng ký",
                    labelStyle: TextStyle(color: _textGrey),
                    prefixIcon: Icon(Icons.email_outlined, color: _accentColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _accentColor),
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Logic gửi email...
                      Navigator.pop(context);
                      _safeShowSnackBar("Đã gửi yêu cầu (Demo)", isError: false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Gửi yêu cầu", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getErrorMessage(Exception e) {
    String msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11);
    }
    return msg;
  }

  void _safeShowSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFCF6679) : const Color(0xFF00BFA5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // --- UI Widget ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback color
      body: Stack(
        children: [
          // 1. Background Gradient Tối
          AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isLoginMode ? _loginBgColors : _signUpBgColors,
              ),
            ),
          ),

          // 2. Các hạt (Particles) mờ ảo
          ...List.generate(4, (index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 3000 + (index * 1000)),
              builder: (context, value, child) {
                return Positioned(
                  top: -50 + (index * 150) + (value * 20),
                  left: (index % 2 == 0) ? -50 : null,
                  right: (index % 2 != 0) ? -50 : null,
                  child: Opacity(
                    // Opacity thấp hơn để không bị chói trên nền đen
                    opacity: 0.05 + (value * 0.05),
                    child: Container(
                      width: 200 + (index * 50),
                      height: 200 + (index * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Gradient nhẹ cho particle
                        gradient: RadialGradient(
                          colors: [Colors.white, Colors.white.withOpacity(0.0)],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                physics: const BouncingScrollPhysics(),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: RotationTransition(
                            turns: _logoRotateAnimation,
                            child: _buildHeader(),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Main Card Dark
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.95 + (value * 0.05),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: _cardDarkColor, // Màu nền thẻ tối
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)), // Viền mờ
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5), // Bóng đổ đậm
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      Text(
                                        _isLoginMode ? "Chào mừng trở lại!" : "Tạo tài khoản mới",
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: _textWhite,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isLoginMode
                                            ? "Đăng nhập để tiếp tục theo dõi sức khỏe"
                                            : "Bắt đầu hành trình sức khỏe ngay hôm nay",
                                        style: TextStyle(
                                          color: _textGrey,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 32),

                                      _buildDarkTextField(
                                        controller: _emailController,
                                        label: "Email",
                                        hint: "name@example.com",
                                        icon: Icons.email_rounded,
                                        validator: _validateEmail,
                                      ),
                                      const SizedBox(height: 16),

                                      _buildDarkTextField(
                                        controller: _passController,
                                        label: "Mật khẩu",
                                        hint: "••••••••",
                                        icon: Icons.lock_rounded,
                                        isPassword: true,
                                        validator: _validatePassword,
                                        onSubmitted: (_) => _onSubmit(),
                                      ),

                                      if (_isLoginMode) ...[
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _showForgotPasswordDialog,
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              "Quên mật khẩu?",
                                              style: TextStyle(
                                                color: _accentColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 24),

                                      _buildMainButton(),
                                      const SizedBox(height: 24),

                                      Row(
                                        children: [
                                          Expanded(child: Divider(color: Colors.grey.shade800, thickness: 1)),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Text(
                                              "hoặc",
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Expanded(child: Divider(color: Colors.grey.shade800, thickness: 1)),
                                        ],
                                      ),
                                      const SizedBox(height: 24),

                                      // Social Buttons
                                      Row(
                                        children: [
                                          Expanded(child: _buildSocialButton(
                                            iconPath: 'https://www.svgrepo.com/show/475656/google-color.svg',
                                            label: "Google",
                                            onTap: () => _handleAuthAction(() async {
                                              await _authService.signInWithGoogle();
                                            }, checkValidation: false),
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _buildSocialButton(
                                            icon: Icons.facebook_rounded,
                                            iconColor: const Color(0xFF1877F2),
                                            label: "Facebook",
                                            onTap: () => _handleAuthAction(() async {
                                              await _authService.signInWithFacebook();
                                            }, checkValidation: false),
                                          )),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 28),

                        _buildBottomSwitch(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay (Dark)
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3038),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Đang xử lý...",
                        style: TextStyle(color: _textWhite, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2C3038), // Dark circle
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _accentColor.withOpacity(0.3), // Glow effect nhẹ
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Icon(
            Icons.health_and_safety_rounded,
            size: 50,
            color: _accentColor,
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [_accentColor, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            "BMI Tracker",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textGrey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(color: _textWhite, fontSize: 15), // Text nhập màu trắng
          cursorColor: _accentColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w400),
            prefixIcon: Icon(icon, color: _accentColor.withOpacity(0.8), size: 22),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey.shade600,
                size: 22,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
                : null,
            filled: true,
            fillColor: Colors.black.withOpacity(0.3), // Nền input tối thui
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _accentColor, width: 1.5), // Focus màu neon
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCF6679), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCF6679), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, _accentColor2], // Gradient Xanh Neon
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          _isLoginMode ? "ĐĂNG NHẬP" : "ĐĂNG KÝ NGAY",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Chữ trên nút màu trắng
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    String? iconPath,
    IconData? icon,
    Color? iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF252A34), // Nền nút social tối
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconPath != null)
                SvgPicture.network(
                  iconPath,
                  height: 22, width: 22,
                  placeholderBuilder: (_) => const SizedBox(width: 22),
                )
              else
                Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: _textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLoginMode ? "Chưa có tài khoản?" : "Đã có tài khoản?",
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _isLoginMode = !_isLoginMode;
              _formKey.currentState?.reset();
              _emailController.clear();
              _passController.clear();
            });
            _animationController.reset();
            _animationController.forward();
          },
          child: Text(
            _isLoginMode ? "Đăng ký" : "Đăng nhập",
            style: TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}