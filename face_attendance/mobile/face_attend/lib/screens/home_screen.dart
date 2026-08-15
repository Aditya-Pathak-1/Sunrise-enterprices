import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/attendance_record.dart';
import '../widgets/sunrise_design.dart';
import 'face_scan_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String name;
  final String employeeId;

  const HomeScreen({
    super.key,
    required this.name,
    required this.employeeId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AttendanceRecord? _todayRecord;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
  }

  Future<void> _loadTodayAttendance() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await ApiService.getTodayAttendance();
      final myRecord = records.where(
        (r) => r.employeeId == widget.employeeId,
      ).firstOrNull;
      if (mounted) setState(() { _todayRecord = myRecord; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load attendance'; _loading = false; });
    }
  }

  Future<void> _openFaceScan(String mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FaceScanScreen(
          mode: mode,
          employeeId: widget.employeeId,
          name: widget.name,
        ),
      ),
    );
    _loadTodayAttendance();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '--:--';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${widget.name.split(' ').first} 👋',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            Text(
              widget.employeeId,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.black54),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, color: Colors.grey),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFFF9800),
              onRefresh: _loadTodayAttendance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Date Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Error Display
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_off_rounded, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.outfit(color: Colors.red[800], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Actions Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            title: 'Check In',
                            icon: Icons.fingerprint_rounded,
                            color: const Color(0xFF4CAF50),
                            time: _formatTime(_todayRecord?.checkIn),
                            enabled: _todayRecord == null,
                            onTap: () => _openFaceScan('checkin'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionCard(
                            title: 'Check Out',
                            icon: Icons.exit_to_app_rounded,
                            color: const Color(0xFFFF9800),
                            time: _formatTime(_todayRecord?.checkOut),
                            enabled: _todayRecord != null && !_todayRecord!.isCheckedOut,
                            onTap: () => _openFaceScan('checkout'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          BottomNavBar(
            activeIndex: 0, // Home
            onTap: (index) {
              if (index == 1) _openFaceScan('checkin');
              if (index == 2) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => HistoryScreen(employeeId: widget.employeeId, name: widget.name),
                ));
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String time,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled ? color.withOpacity(0.5) : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: enabled ? [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ] : [],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: enabled ? color.withOpacity(0.1) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: enabled ? color : Colors.grey[400], size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.black87 : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
