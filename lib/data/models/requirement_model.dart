class Requirement {
  String requirementId;
  String customerName;
  String phone;
  String purpose; // Buy, Rent, Lease
  String priority; // Low, Medium, High
  String propertyType;
  String location;
  double minBudget;
  double maxBudget;
  int? bhk;
  String status; // Active, Matched, Closed, Cancelled
  String notes;

  Requirement({
    this.requirementId = '',
    this.customerName = '',
    this.phone = '',
    this.purpose = 'Buy',
    this.priority = 'Medium',
    this.propertyType = 'Villa',
    this.location = '',
    this.minBudget = 0,
    this.maxBudget = 0,
    this.bhk,
    this.status = 'Active',
    this.notes = '',
  });

  // Calculate a basic completion score for the UI
  int get readinessScore {
    int score = 0;
    if (customerName.isNotEmpty) score += 20;
    if (phone.isNotEmpty) score += 20;
    if (location.isNotEmpty) score += 20;
    if (maxBudget > 0) score += 20;
    if (propertyType.isNotEmpty) score += 20;
    return score;
  }
}