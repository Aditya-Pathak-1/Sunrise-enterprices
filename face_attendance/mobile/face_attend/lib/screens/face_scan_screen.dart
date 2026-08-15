import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../widgets/sunrise_design.dart';
import 'success_screen.dart';

class FaceScanScreen extends StatefulWidget {
  final String mode; // 'checkin' or 'checkout'
  final String employeeId;
  final String name;

  const FaceScanScreen({
    super.key,
    required this.mode,
    required this.employeeId,
    required this.name,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  String _status = "Align your face within the frame";
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _status = "Camera Error: $e";
        _isError = true;
      });
    }
  }

  Future<void> _scanFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = "Verifying...";
      _isError = false;
    });

    try {
      final image = await _cameraController!.takePicture();
      final imageFile = File(image.path);

      if (widget.mode == 'checkin') {
        await ApiService.checkIn(imageFile);
      } else {
        await ApiService.checkOut(imageFile);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessScreen(
              name: widget.name,
              employeeId: widget.employeeId,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = e.message;
          _isError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = "Verification failed. Try again.";
          _isError = true;
        });
      }
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Mark Attendance',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 20, color: Colors.white),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Camera View
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(color: const Color(0xFFFF9800), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: _cameraController?.value.isInitialized == true
                        ? SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _cameraController!.value.previewSize?.height ?? 1,
                                height: _cameraController!.value.previewSize?.width ?? 1,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800))),
                  ),
                ),

                const SizedBox(height: 40),

                // Status Text
                Text(
                  _status,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isError ? Colors.red : Colors.black87,
                  ),
                ),

                const SizedBox(height: 30),

                // Scan Button
                SizedBox(
                  width: 200,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: _isProcessing ? null : _scanFace,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 20),
                      label: Text(
                        _isProcessing ? 'Verifying...' : 'Scan Face',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Nav Bar
          BottomNavBar(
            activeIndex: 1, // Attendance tab
            onTap: (index) {
              if (index == 0) Navigator.pop(context); // Go back to Home
            },
          ),
        ],
      ),
    );
  }
}
