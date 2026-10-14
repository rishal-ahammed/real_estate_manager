import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';

class AppState extends ChangeNotifier {
  List<dynamic> properties = []; 
  List<dynamic> requirements = []; 
  
  bool isLoadingProperties = true;
  bool isLoadingRequirements = true;

  AppState() {
    // Automatically load data when the app starts!
    loadProperties();
    loadRequirements();
  }

  Future<void> loadProperties() async {
    isLoadingProperties = true;
    notifyListeners();

    try {
      // 1. Fetch the raw Maps from Google Drive
      final List<Map<String, dynamic>> rawData = await storageService.getPropertiesIndex();
      
      // 2. Assign the data. 
      // (Note: If your PropertyIndexItem has a .fromJson() method, you can use: 
      // properties = rawData.map((e) => PropertyIndexItem.fromJson(e)).toList(); )
      properties = rawData; 

    } catch (e) {
      debugPrint("Error loading properties: $e");
    } finally {
      isLoadingProperties = false;
      notifyListeners();
    }
  }

  Future<void> loadRequirements() async {
    isLoadingRequirements = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> rawData = await storageService.getRequirementsIndex();
      requirements = rawData; 
    } catch (e) {
      debugPrint("Error loading requirements: $e");
    } finally {
      isLoadingRequirements = false;
      notifyListeners();
    }
  }

  Future<void> archiveProperty(String id) async {
    await storageService.archiveProperty(id);
    await loadProperties(); // Refresh the list after deleting!
  }
}

final appState = AppState();