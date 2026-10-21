import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

abstract class StorageService {
  Future<void> saveProperty(dynamic property, {List<String>? imagePaths});
  Future<List<Map<String, dynamic>>> getPropertiesIndex();
  Future<void> archiveProperty(String id);
  Future<void> saveRequirement(dynamic requirement);
  Future<List<Map<String, dynamic>>> getRequirementsIndex();
}

class LocalDeviceStorageService implements StorageService {
  // Helper to get the root app directory on the device
  Future<Directory> _getRootDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final rootFolder = Directory('${directory.path}/REAL_ESTATE_APP');
    if (!await rootFolder.exists()) {
      await rootFolder.create(recursive: true);
    }
    return rootFolder;
  }

  @override
  Future<void> saveProperty(
    dynamic property, {
    List<String>? imagePaths,
  }) async {
    try {
      final rootDir = await _getRootDirectory();
      final propertyId =
          property.propertyId ??
          'PROP-${DateTime.now().millisecondsSinceEpoch}';

      // Create Property folder
      final propertyFolder = Directory(
        '${rootDir.path}/Properties/$propertyId',
      );
      if (!await propertyFolder.exists()) {
        await propertyFolder.create(recursive: true);
      }

      // Save JSON Data
      final propertyJson = {
        "propertyId": propertyId,
        "propertyName": property.propertyName,
        "propertyType": property.propertyType,
        "pricing": {"budget": property.budget},
        "location": {
          "state": property.state,
          "city": property.city,
          "area": property.area,
          "pincode": property.pincode,
        },
        "specifications": {"bhk": property.bhk},
        "status": "ACTIVE",
        "createdAt": DateTime.now().toIso8601String(),
      };

      final file = File('${propertyFolder.path}/property.json');
      await file.writeAsString(jsonEncode(propertyJson));

      // FIX 1: Generate a perfectly unique name for EVERY cropped image
      if (imagePaths != null && imagePaths.isNotEmpty) {
        final imagesFolder = Directory('${propertyFolder.path}/Images');
        if (!await imagesFolder.exists()) {
          await imagesFolder.create(recursive: true);
        }

        int index = 1;
        for (String path in imagePaths) {
          final originalFile = File(path);
          if (originalFile.existsSync()) {
            final extension = path.contains('.') ? path.split('.').last : 'jpg';
            final uniqueFileName = 'property_img_$index.$extension';
            await originalFile.copy('${imagesFolder.path}/$uniqueFileName');
            index++;
          }
        }
      }

      debugPrint('✅ Property saved locally to device!');
    } catch (e) {
      debugPrint('❌ Failed to save Property locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveRequirement(dynamic requirement) async {
    try {
      final rootDir = await _getRootDirectory();
      final reqId =
          requirement.requirementId ??
          'REQ-${DateTime.now().millisecondsSinceEpoch}';

      final reqFolder = Directory('${rootDir.path}/Requirements/$reqId');
      if (!await reqFolder.exists()) {
        await reqFolder.create(recursive: true);
      }

      final reqJson = {
        "requirementId": reqId,
        "customerName": requirement.customerName,
        "phone": requirement.phone,
        "purpose": requirement.purpose,
        "propertyType": requirement.propertyType,
        "location": requirement.location,
        "maxBudget": requirement.maxBudget,
        "bhk": requirement.bhk,
        "status": requirement.status,
      };

      final file = File('${reqFolder.path}/requirement.json');
      await file.writeAsString(jsonEncode(reqJson));

      debugPrint('✅ Requirement saved locally!');
    } catch (e) {
      debugPrint('❌ Failed to save Requirement: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPropertiesIndex() async {
    try {
      final rootDir = await _getRootDirectory();
      final propertiesFolder = Directory('${rootDir.path}/Properties');

      if (!await propertiesFolder.exists()) return [];

      List<Map<String, dynamic>> propertiesList = [];

      final entities = propertiesFolder.listSync();
      for (var entity in entities) {
        if (entity is Directory) {
          final jsonFile = File('${entity.path}/property.json');
          if (jsonFile.existsSync()) {
            final jsonString = await jsonFile.readAsString();
            final Map<String, dynamic> data = jsonDecode(jsonString);

            // FIX 2: Grab the unique images and package them into an array!
            final imagesFolder = Directory('${entity.path}/Images');
            if (imagesFolder.existsSync()) {
              final images = imagesFolder.listSync().whereType<File>().toList();
              if (images.isNotEmpty) {
                data['coverImagePath'] = images.first.path;
                // This exact line feeds the swipeable gallery:
                data['allImagePaths'] = images.map((img) => img.path).toList();
              }
            }
            propertiesList.add(data);
          }
        }
      }
      return propertiesList;
    } catch (e) {
      debugPrint('Error fetching properties: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRequirementsIndex() async {
    try {
      final rootDir = await _getRootDirectory();
      final reqFolder = Directory('${rootDir.path}/Requirements');

      if (!await reqFolder.exists()) return [];

      List<Map<String, dynamic>> reqList = [];

      final entities = reqFolder.listSync();
      for (var entity in entities) {
        if (entity is Directory) {
          final jsonFile = File('${entity.path}/requirement.json');
          if (jsonFile.existsSync()) {
            final jsonString = await jsonFile.readAsString();
            reqList.add(jsonDecode(jsonString));
          }
        }
      }
      return reqList;
    } catch (e) {
      debugPrint('Error fetching requirements: $e');
      return [];
    }
  }

  @override
  Future<void> archiveProperty(String id) async {
    try {
      final rootDir = await _getRootDirectory();
      final propertyFolder = Directory('${rootDir.path}/Properties/$id');
      if (await propertyFolder.exists()) {
        await propertyFolder.delete(recursive: true);
        debugPrint('Deleted local property: $id');
      }
    } catch (e) {
      debugPrint('Failed to delete property: $e');
    }
  }
}

// Global instance
final storageService = LocalDeviceStorageService();
