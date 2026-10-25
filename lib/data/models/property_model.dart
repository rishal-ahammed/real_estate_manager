enum PropertyStatus {
  draft,
  active,
  reserved,
  sold,
  rented,
  inactive,
  archived,
}

enum RequirementStatus { active, matched, closed, cancelled }

class PropertyIndexItem {
  final String propertyId;
  final String propertyName;
  final String propertyType;
  final String location;
  final double budget;
  final int? bhk;
  final PropertyStatus status;

  const PropertyIndexItem({
    required this.propertyId,
    required this.propertyName,
    required this.propertyType,
    required this.location,
    required this.budget,
    this.bhk,
    required this.status,
  });
}

class Property {
  String? propertyId;
  String propertyName;
  String contactName;
  String contactPhone;
  String contactType;
  String documentStatus;
  String propertyType;

  double budget;
  bool isNegotiable;
  double? landRate;
  double? landArea;
  double? builtUpArea;

  int? bhk;
  int? floors;
  String? furnishedStatus;
  String? facing;
  int? builtYear;

  String manualNotes;
  String aiGeneratedNotes;

  String state;
  String city;
  String area;
  String pincode;

  PropertyStatus status;
  List<String> images;
  List<String> videos;

  Property({
    this.propertyId,
    this.propertyName = '',
    this.contactName = '',
    this.contactPhone = '',
    this.contactType = 'Owner',
    this.documentStatus = 'Available',
    this.propertyType = 'Villa',
    this.budget = 0.0,
    this.isNegotiable = true,
    this.landRate,
    this.landArea,
    this.builtUpArea,
    this.bhk,
    this.floors,
    this.furnishedStatus = 'Unfurnished',
    this.facing,
    this.builtYear,
    this.manualNotes = '',
    this.aiGeneratedNotes = '',
    this.state = '',
    this.city = '',
    this.area = '',
    this.pincode = '',
    this.status = PropertyStatus.draft,
    List<String>? images,
    List<String>? videos,
  }) : images = images ?? [],
       videos = videos ?? [];

  Map<String, dynamic> toJson() {
    return {
      'propertyId': propertyId,
      'propertyName': propertyName,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactType': contactType,
      'documentStatus': documentStatus,
      'propertyType': propertyType,
      'budget': budget,
      'isNegotiable': isNegotiable,
      'landRate': landRate,
      'landArea': landArea,
      'builtUpArea': builtUpArea,
      'bhk': bhk,
      'floors': floors,
      'furnishedStatus': furnishedStatus,
      'facing': facing,
      'builtYear': builtYear,
      'manualNotes': manualNotes,
      'aiGeneratedNotes': aiGeneratedNotes,
      'state': state,
      'city': city,
      'area': area,
      'pincode': pincode,
      'status': status.name,
      'images': images,
      'videos': videos,
    };
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      propertyId: json['propertyId']?.toString(),
      propertyName: _readString(json['propertyName']),
      contactName: _readString(json['contactName']),
      contactPhone: _readString(json['contactPhone']),
      contactType: _readString(json['contactType'], 'Owner'),
      documentStatus: _readString(json['documentStatus'], 'Available'),
      propertyType: _readString(json['propertyType'], 'Villa'),
      budget: _readDouble(
        json['budget'] ?? _nestedValue(json, 'pricing', 'budget'),
      ),
      isNegotiable: _readBool(json['isNegotiable'], true),
      landRate: _readNullableDouble(json['landRate']),
      landArea: _readNullableDouble(json['landArea']),
      builtUpArea: _readNullableDouble(json['builtUpArea']),
      bhk: _readNullableInt(
        json['bhk'] ?? _nestedValue(json, 'specifications', 'bhk'),
      ),
      floors: _readNullableInt(json['floors']),
      furnishedStatus: json['furnishedStatus']?.toString() ?? 'Unfurnished',
      facing: json['facing']?.toString(),
      builtYear: _readNullableInt(json['builtYear']),
      manualNotes: _readString(json['manualNotes']),
      aiGeneratedNotes: _readString(json['aiGeneratedNotes']),
      state: _readString(
        json['state'] ?? _nestedValue(json, 'location', 'state'),
      ),
      city: _readString(json['city'] ?? _nestedValue(json, 'location', 'city')),
      area: _readString(json['area'] ?? _nestedValue(json, 'location', 'area')),
      pincode: _readString(
        json['pincode'] ?? _nestedValue(json, 'location', 'pincode'),
      ),
      status: _readStatus(json['status']),
      images: _readStringList(json['images'] ?? json['allImagePaths']),
      videos: _readStringList(json['videos']),
    );
  }

  static dynamic _nestedValue(
    Map<String, dynamic> json,
    String parent,
    String child,
  ) {
    final value = json[parent];
    if (value is Map) return value[child];
    return null;
  }

  static String _readString(dynamic value, [String fallback = '']) {
    return value?.toString() ?? fallback;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return _readDouble(value);
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _readBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return [];
  }

  static PropertyStatus _readStatus(dynamic value) {
    final text = value?.toString().split('.').last;

    for (final status in PropertyStatus.values) {
      if (status.name.toLowerCase() == text?.toLowerCase()) {
        return status;
      }
    }

    return PropertyStatus.draft;
  }

  int get readinessScore {
    int score = 0;

    if (propertyName.trim().isNotEmpty) score += 20;
    if (propertyType.trim().isNotEmpty) score += 20;
    if (budget > 0) score += 20;
    if (area.trim().isNotEmpty) score += 20;

    if ((bhk != null && bhk! > 0) || (landArea != null && landArea! > 0)) {
      score += 10;
    }

    if (images.isNotEmpty) score += 10;

    return score;
  }
}
