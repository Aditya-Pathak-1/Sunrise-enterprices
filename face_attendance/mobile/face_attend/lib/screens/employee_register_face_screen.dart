import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../widgets/sunrise_design.dart';
import 'home_screen.dart';

class EmployeeRegisterFaceScreen extends StatefulWidget {
  final String name;
  final String employeeId;

  const EmployeeRegisterFaceScreen({
    super.key,
    required this.name,
    required this.employeeId,
  });

  @override
  State<EmployeeRegisterFaceScreen> createState() => _EmployeeRegisterFaceScreenState();
}

class _EmployeeRegisterFaceScreenState extends State<EmployeeRegisterFaceScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _loading = false;
  String? _error;

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
      setState(() => _error = 'Camera permission denied. Please enable it in settings.');
    }
  }

  Future<void> _takePictureAndRegister() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      final capturedImage = File(picture.path);

      await ApiService.registerEmployeeFace(widget.name, widget.employeeId, capturedImage);
      
      if (mounted) {
        // Registration successful! Navigate to Home Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              name: widget.name,
              employeeId: widget.employeeId,
            ),
          ),
        );
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SunriseLogo(size: 65),
                    const SizedBox(height: 30),

                    Text(
                      'Welcome, ${widget.name.split(' ')[0]}!',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let\'s set up your face profile for attendance.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You will only have to do this once.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFFFF9800),
                        fontWeight: FontWeight.bold,
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
                      'Look directly at the camera in good lighting.',
                      style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
                    ),

                    const SizedBox(height: 40),

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
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Capture & Complete Setup',
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
            
            // Wavy Footer
            const SunriseFooter(text: 'Sunrise Equipments v2.0'),
          ],
        ),
      ),
    );
  }
}
