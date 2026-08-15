import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../widgets/sunrise_design.dart';

class AdminAddEmployeeScreen extends StatefulWidget {
  const AdminAddEmployeeScreen({super.key});

  @override
  State<AdminAddEmployeeScreen> createState() => _AdminAddEmployeeScreenState();
}

class _AdminAddEmployeeScreenState extends State<AdminAddEmployeeScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _loading = false;
  String? _error;
  String? _success;
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        final frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      } catch (e) {
        setState(() => _error = 'Failed to initialize camera: $e');
      }
    } else {
      setState(() => _error = 'Camera permission denied.');
    }
  }

  Future<void> _takePictureAndRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      _capturedImage = File(picture.path);

      final name = _nameController.text.trim();
      final contact = _contactController.text.trim();

      final response = await ApiService.registerEmployeeFace(name, contact, _capturedImage!);
      
      setState(() {
        _success = response['message'] ?? 'Successfully registered $name!';
        // Reset for next
        _nameController.clear();
        _contactController.clear();
        _capturedImage = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
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
        title: Text(
          'Register Face',
          style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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

                if (_success != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _success!,
                            style: GoogleFonts.outfit(color: Colors.green[800], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.outfit(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Employee Name',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF9800)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 20),

                // Contact Number Field
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.outfit(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Contact Number (ID)',
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFFF9800)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 30),

                // Camera Preview
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFF9800), width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: _isCameraInitialized
                        ? CameraPreview(_cameraController!)
                        : const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800))),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Make sure the face is clearly visible',
                  style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
                ),

                const SizedBox(height: 30),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_loading || !_isCameraInitialized) ? null : _takePictureAndRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Capture & Register',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
