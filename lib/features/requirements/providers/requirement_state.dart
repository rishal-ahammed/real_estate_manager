import 'package:flutter/material.dart';
import '../../../data/models/requirement_model.dart';

class RequirementState extends ChangeNotifier {
  List<Requirement> requirements = [];

  void addRequirement(Requirement req) {
    // Automatically generate an ID like REQ-000001
    req.requirementId =
        'REQ-${(requirements.length + 1).toString().padLeft(6, '0')}';

    // Add to the top of the list
    requirements.insert(0, req);

    notifyListeners(); // Tells the UI to update
  }
}

// Global instance so we can access it from anywhere
final requirementState = RequirementState();
