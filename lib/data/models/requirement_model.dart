class Requirement {
  String requirementId;
  String customerName;
  String phone;
  String purpose;
  String priority;
  String propertyType;
  String location;
  double minBudget;
  double maxBudget;
  int? bhk;
  String status;
  String notes;

  Requirement({
    this.requirementId = '',
    this.customerName = '',
    this.phone = '',
    this.purpose = 'Buy',
    this.priority = 'Medium',
    this.propertyType = 'Villa',
    this.location = '',
    this.minBudget = 0.0,
    this.maxBudget = 0.0,
    this.bhk,
    this.status = 'Active',
    this.notes = '',
  });

  /// Converts this requirement into data that can be saved as JSON.
  Map<String, dynamic> toJson() {
    return {
      'requirementId': requirementId,
      'customerName': customerName,
      'phone': phone,
      'purpose': purpose,
      'priority': priority,
      'propertyType': propertyType,
      'location': location,
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'bhk': bhk,
      'status': status,
      'notes': notes,
    };
  }

  /// Rebuilds a requirement from saved JSON data.
  factory Requirement.fromJson(Map<String, dynamic> json) {
    return Requirement(
      requirementId: json['requirementId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'Buy',
      priority: json['priority']?.toString() ?? 'Medium',
      propertyType: json['propertyType']?.toString() ?? 'Villa',
      location: json['location']?.toString() ?? '',
      minBudget: _readDouble(json['minBudget']),
      maxBudget: _readDouble(json['maxBudget']),
      bhk: _readInt(json['bhk']),
      status: json['status']?.toString() ?? 'Active',
      notes: json['notes']?.toString() ?? '',
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Calculates how complete the requirement information is.
  int get readinessScore {
    int score = 0;

    if (customerName.trim().isNotEmpty) score += 20;
    if (phone.trim().isNotEmpty) score += 20;
    if (location.trim().isNotEmpty) score += 20;
    if (maxBudget > 0) score += 20;
    if (propertyType.trim().isNotEmpty) score += 20;

    return score;
  }
}
