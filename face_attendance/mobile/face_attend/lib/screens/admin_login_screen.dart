import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/sunrise_design.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  static const Map<String, String> _admins = {
    'RASHMI NAIK': 'sunrise@123',
    'SHILPA BHOIR': 'sunrise@123',
    'AYUSH': 'sunrise@123',
    'AHANA': 'sunrise@123',
    'ADITYA': 'sunrise@123',
  };

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _usernameController.text.trim().toUpperCase();
    final password = _passwordController.text;

    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      
      setState(() => _loading = false);

      if (_admins.containsKey(username) && _admins[username] == password) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(adminName: username),
          ),
        );
      } else {
        setState(() => _error = 'Invalid Admin credentials.');
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SunriseLogo(size: 55),
                      const SizedBox(height: 30),

                      Text(
                        'Admin Portal',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Authorized access only.',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),
                      
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Text(
                            _error!,
                            style: GoogleFonts.outfit(color: Colors.red[800], fontSize: 13),
                          ),
                        ),

                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.outfit(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Admin Username',
                          labelStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFFF9800)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                      ),

                      const SizedBox(height: 20),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.outfit(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFF9800)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Password is required' : null,
                      ),

                      const SizedBox(height: 30),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E), // Darker button for admin
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Login as Admin',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Wavy Footer
            const SunriseFooter(text: 'Sunrise Admin Portal'),
          ],
        ),
      ),
    );
  }
}
