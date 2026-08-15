import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sunrise_design.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'employee_register_face_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _contactController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final designation = _designationController.text.trim();
    final contact = _contactController.text.trim();

    try {
      await ApiService.authSignup(name, designation, contact);
      
      // Save session immediately after signup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('contact_number', contact);
      await prefs.setString('employee_id', contact);

      if (mounted) {
        // Since they just signed up, they don't have a face registered yet.
        // Take them straight to the Face Registration screen.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeRegisterFaceScreen(
              name: name,
              employeeId: contact,
            ),
          ),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _contactController.dispose();
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SunriseLogo(size: 55),
                      const SizedBox(height: 30),

                      Text(
                        'New Employee',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to access the attendance system.',
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

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.outfit(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF9800)),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),

                      const SizedBox(height: 20),
                      
                      // Designation Field
                      TextFormField(
                        controller: _designationController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.outfit(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Designation',
                          labelStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.work_outline, color: Color(0xFFFF9800)),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Designation is required' : null,
                      ),

                      const SizedBox(height: 20),

                      // Contact Number Field
                      TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.outfit(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Contact Number',
                          labelStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFFF9800)),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact Number is required' : null,
                      ),

                      const SizedBox(height: 30),

                      // Signup Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
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
                                  'Sign Up & Login',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            
            // Wavy Footer
            const SunriseFooter(text: 'Sunrise Equipments v2.0'),
          ],
        ),
      ),
    );
  }
}
