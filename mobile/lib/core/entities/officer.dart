class Officer {
  final int id;
  final String? employeeNo;
  final String name;
  final String? phone;
  final String role;
  final bool isActive;
  final bool hasPassword;

  const Officer({
    required this.id,
    required this.employeeNo,
    required this.name,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.hasPassword,
  });

  bool get isSupervisor => role == 'spv';

  factory Officer.fromJson(Map<String, dynamic> json) {
    return Officer(
      id: json['id'] as int,
      employeeNo: json['employee_no'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      hasPassword: json['has_password'] as bool? ?? false,
    );
  }
}
