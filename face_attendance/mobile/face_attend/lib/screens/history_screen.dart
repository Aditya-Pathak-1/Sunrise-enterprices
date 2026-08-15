import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/attendance_record.dart';

class HistoryScreen extends StatefulWidget {
  final String employeeId;
  final String name;

  const HistoryScreen({
    super.key,
    required this.employeeId,
    required this.name,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AttendanceRecord> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getAttendanceHistory(widget.employeeId);
      final rawRecords = data['records'] as List<dynamic>;
      final records = rawRecords
          .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _records = records; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load history'; _loading = false; });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEE, MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Duration? _duration(AttendanceRecord r) {
    if (r.checkIn == null || r.checkOut == null) return null;
    try {
      final inTime = DateTime.parse(r.checkIn!);
      final outTime = DateTime.parse(r.checkOut!);
      return outTime.difference(inTime);
    } catch (_) {
      return null;
    }
  }

  String _durationStr(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance History',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.name,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF9090A0),
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Color(0xFFFF6B6B), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                            color: const Color(0xFFFF6B6B), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                          onPressed: _loadHistory,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : _records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_busy_rounded,
                              color: Color(0xFF4A4A5A), size: 60),
                          const SizedBox(height: 16),
                          Text(
                            'No attendance records yet',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9090A0),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF6C63FF),
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        itemBuilder: (_, i) => _buildCard(_records[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(AttendanceRecord r) {
    final dur = _duration(r);
    Color statusColor;
    IconData statusIcon;

    if (r.isCheckedOut) {
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle_rounded;
    } else if (r.isCheckedIn) {
      statusColor = const Color(0xFF6C63FF);
      statusIcon = Icons.access_time_rounded;
    } else {
      statusColor = const Color(0xFF9090A0);
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(r.date),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    r.statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Times row
          Row(
            children: [
              Expanded(
                child: _timeCell(
                  icon: Icons.login_rounded,
                  label: 'Check In',
                  value: _formatTime(r.checkIn),
                  color: const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeCell(
                  icon: Icons.logout_rounded,
                  label: 'Check Out',
                  value: _formatTime(r.checkOut),
                  color: const Color(0xFFFF9800),
                ),
              ),
              if (dur != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _timeCell(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _durationStr(dur),
                    color: const Color(0xFF6C63FF),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeCell({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
