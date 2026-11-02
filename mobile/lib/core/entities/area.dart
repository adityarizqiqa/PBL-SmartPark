class Area {
  final int id;
  final String code;
  final String name;
  final bool isActive;

  const Area({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}
