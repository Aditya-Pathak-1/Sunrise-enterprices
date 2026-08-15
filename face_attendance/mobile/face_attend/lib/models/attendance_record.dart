// models/attendance_record.dart

class AttendanceRecord {
  final int id;
  final String personId;
  final String employeeId;
  final String name;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final String status;

  const AttendanceRecord({
    required this.id,
    required this.personId,
    required this.employeeId,
    required this.name,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int,
      personId: json['person_id'] as String,
      employeeId: json['employee_id'] as String,
      name: json['name'] as String,
      date: json['date'] as String,
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      status: json['status'] as String,
    );
  }

  bool get isCheckedIn => checkIn != null;
  bool get isCheckedOut => checkOut != null;

  String get statusLabel {
    if (isCheckedOut) return 'Completed';
    if (isCheckedIn) return 'Present';
    return 'Absent';
  }
}
