//// ============================================================================
// DOMAIN MODELS (lib/data/models/)
// ============================================================================

enum PropertyStatus { DRAFT, ACTIVE, RESERVED, SOLD, RENTED, INACTIVE, ARCHIVED }
enum RequirementStatus { ACTIVE, MATCHED, CLOSED, CANCELLED }

class PropertyIndexItem {
  final String propertyId;
  final String propertyName;
  final String propertyType;
  final String location;
  final double budget;
  final int? bhk;
  final PropertyStatus status;

  PropertyIndexItem({
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
    this.status = PropertyStatus.DRAFT,
    this.images = const [],
  });
  
  int get readinessScore {
    int score = 0;
    if (propertyName.isNotEmpty) score += 15;
    if (propertyType.isNotEmpty) score += 10;
    if (budget > 0) score += 20;
    if (area.isNotEmpty) score += 15;
    if (bhk != null || landArea != null) score += 20;
    if (images.isNotEmpty) score += 20;
    return score.clamp(0, 100);
  }
}
