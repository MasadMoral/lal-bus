import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _emailMode = false;
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    final error = await AuthService.signInWithGoogle();
    if (!mounted) return;
    if (error != null) {
      setState(() { _error = error; _loading = false; });
    } else {
      _goHome();
    }
  }

  Future<void> _emailSignIn() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Enter email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final error = await AuthService.signInWithEmail(
        _emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() { _error = error; _loading = false; });
    } else {
      _goHome();
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCC0000), Color(0xFFE53935)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCC0000).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🚌', style: TextStyle(fontSize: 44)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Lal Bus',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFCC0000))),
                const SizedBox(height: 4),
                Text('Dhaka University',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text(
                  'Track your campus buses in real-time',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 48),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _emailMode ? _buildEmailForm(isDark) : _buildGoogleForm(isDark),
                ),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: CircularProgressIndicator(color: Color(0xFFCC0000)),
                  ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCC0000).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFCC0000), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: Color(0xFFCC0000), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Only @du.ac.bd emails are allowed.\nContact admin for manual access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleForm(bool isDark) {
    return Column(
      key: const ValueKey('google'),
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _googleSignIn,
            icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => setState(() { _emailMode = true; _error = null; }),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Login with Email & Password',
                style: TextStyle(color: Color(0xFFCC0000), fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(bool isDark) {
    final fieldColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    return Column(
      key: const ValueKey('email'),
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFCC0000)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            filled: true,
            fillColor: fieldColor,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFCC0000)),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            filled: true,
            fillColor: fieldColor,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _emailSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC0000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => setState(() { _emailMode = false; _error = null; }),
          icon: const Icon(Icons.arrow_back, size: 18, color: Colors.grey),
          label: const Text('Back to Google Sign In', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
