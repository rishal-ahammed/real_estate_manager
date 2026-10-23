import 'package:flutter/foundation.dart';

import '../../../core/services/storage_service.dart';
import '../../../data/models/requirement_model.dart';

class AppState extends ChangeNotifier {
  AppState() {
    loadProperties();
    loadRequirements();
  }

  List<dynamic> properties = [];
  List<dynamic> requirements = [];

  bool isLoadingProperties = true;
  bool isLoadingRequirements = true;

  String? propertiesError;
  String? requirementsError;

  // Load saved properties from local device storage.
  Future<void> loadProperties() async {
    isLoadingProperties = true;
    propertiesError = null;
    notifyListeners();

    try {
      final loadedProperties = await storageService.getPropertiesIndex();
      properties = loadedProperties;
    } catch (e, stackTrace) {
      propertiesError = 'Could not load properties: $e';
      debugPrint(propertiesError);
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isLoadingProperties = false;
      notifyListeners();
    }
  }

  // Load saved requirements from local device storage.
  Future<void> loadRequirements() async {
    isLoadingRequirements = true;
    requirementsError = null;
    notifyListeners();

    try {
      final loadedRequirements = await storageService.getRequirementsIndex();
      requirements = loadedRequirements;
    } catch (e, stackTrace) {
      requirementsError = 'Could not load requirements: $e';
      debugPrint(requirementsError);
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isLoadingRequirements = false;
      notifyListeners();
    }
  }

  // Save a new requirement or update an existing requirement.
  Future<void> saveRequirement(Requirement requirement) async {
    await storageService.saveRequirement(requirement);
    await loadRequirements();
  }

  // Update only the status of an existing requirement.
  Future<void> updateRequirementStatus(
    String requirementId,
    String status,
  ) async {
    final index = requirements.indexWhere(
      (item) =>
          item is Map && item['requirementId']?.toString() == requirementId,
    );

    if (index == -1) {
      throw StateError('Requirement not found.');
    }

    final requirement = Requirement.fromJson(
      Map<String, dynamic>.from(requirements[index] as Map),
    );

    requirement.status = status;

    await saveRequirement(requirement);
  }

  // Delete a requirement from local storage.
  Future<void> deleteRequirement(String requirementId) async {
    await storageService.deleteRequirement(requirementId);
    await loadRequirements();
  }

  // Archive a property and refresh the displayed list.
  Future<void> archiveProperty(String propertyId) async {
    await storageService.archiveProperty(propertyId);
    await loadProperties();
  }

  // Refresh both lists when needed.
  Future<void> refreshAll() async {
    await Future.wait([loadProperties(), loadRequirements()]);
  }
}

// One shared app state for the whole application.
final AppState appState = AppState();
