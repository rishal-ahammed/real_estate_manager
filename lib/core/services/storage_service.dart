import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_client.dart';

abstract class StorageService {
  Future<void> saveProperty(dynamic property, {List<String>? imagePaths});
  Future<List<Map<String, dynamic>>> getPropertiesIndex();
  Future<void> archiveProperty(String id);
  Future<void> saveRequirement(dynamic requirement);
  Future<List<Map<String, dynamic>>> getRequirementsIndex();
}

class GoogleDriveStorageService implements StorageService {
  // CORRECT V6 USAGE: Use .instance here
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final List<String> _scopes = [drive.DriveApi.driveFileScope];
  drive.DriveApi? _driveApi;

  Future<void> _initDriveApi() async {
    if (_driveApi != null) return;

    // CORRECT V6 USAGE: Pass the client ID inside initialize()
    await _googleSignIn.initialize(
      serverClientId:
          '825711741679-29lbfkv06ksu0q9dgkh6stb7j7o6c6b3.apps.googleusercontent.com',
    );

    GoogleSignInAccount? account = await _googleSignIn
        .attemptLightweightAuthentication();
    account ??= await _googleSignIn.authenticate(scopeHint: _scopes);

    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
      promptIfNecessary: true,
    );

    if (headers == null) {
      throw Exception("Failed to get Google Drive Authorization Headers.");
    }

    final client = GoogleAuthClient(headers);
    _driveApi = drive.DriveApi(client);
  }

  Future<String> _getOrCreateFolder(
    String folderName, {
    String? parentId,
  }) async {
    await _initDriveApi();

    String query =
        "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    if (parentId != null) {
      query += " and '$parentId' in parents";
    }

    final folderList = await _driveApi!.files.list(q: query, spaces: 'drive');

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    }

    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = parentId != null ? [parentId] : null;

    final createdFolder = await _driveApi!.files.create(folder);
    return createdFolder.id!;
  }

  Future<void> _uploadJsonFile(
    String fileName,
    Map<String, dynamic> data,
    String parentId,
  ) async {
    await _initDriveApi();

    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final stream = Stream.value(bytes);

    final query =
        "name = '$fileName' and '$parentId' in parents and trashed = false";
    final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');

    final driveFile = drive.File()..name = fileName;

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final fileId = fileList.files!.first.id!;
      await _driveApi!.files.update(
        driveFile,
        fileId,
        uploadMedia: drive.Media(stream, bytes.length),
      );
    } else {
      driveFile.parents = [parentId];
      await _driveApi!.files.create(
        driveFile,
        uploadMedia: drive.Media(stream, bytes.length),
      );
    }
  }

  // NEW: Helper method to download and decode JSON files from Drive
  Future<Map<String, dynamic>?> _downloadJsonFile(String fileId) async {
    try {
      final drive.Media media =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final List<int> bytes = [];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      final jsonString = utf8.decode(bytes);
      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint('Failed to download file $fileId: $e');
      return null;
    }
  }

  @override
  Future<void> saveProperty(
    dynamic property, {
    List<String>? imagePaths,
  }) async {
    try {
      final rootId = await _getOrCreateFolder('REAL ESTATE APP');
      final propertiesFolderId = await _getOrCreateFolder(
        'Properties',
        parentId: rootId,
      );
      final propertyFolderId = await _getOrCreateFolder(
        property.propertyId ?? 'PROP-UNKNOWN',
        parentId: propertiesFolderId,
      );

      final imagesFolderId = await _getOrCreateFolder(
        'Images',
        parentId: propertyFolderId,
      );
      await _getOrCreateFolder('Documents', parentId: propertyFolderId);
      await _getOrCreateFolder('Videos', parentId: propertyFolderId);

      final propertyJson = {
        "propertyId": property.propertyId,
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

      await _uploadJsonFile('property.json', propertyJson, propertyFolderId);

      // Upload all selected images
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (String path in imagePaths) {
          final file = File(path);
          if (file.existsSync()) {
            final fileName = path.split('/').last;
            final bytes = await file.readAsBytes();
            final stream = Stream.value(bytes);

            final driveFile = drive.File()
              ..name = fileName
              ..parents = [imagesFolderId];

            await _driveApi!.files.create(
              driveFile,
              uploadMedia: drive.Media(stream, bytes.length),
            );
          }
        }
      }

      debugPrint('✅ Successfully saved Property and Images to Google Drive!');
    } catch (e) {
      debugPrint('❌ Failed to save Property to Drive: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveRequirement(dynamic requirement) async {
    try {
      final rootId = await _getOrCreateFolder('REAL ESTATE APP');
      final reqFolderId = await _getOrCreateFolder(
        'Requirements',
        parentId: rootId,
      );
      final specificReqFolderId = await _getOrCreateFolder(
        requirement.requirementId ?? 'REQ-UNKNOWN',
        parentId: reqFolderId,
      );

      final reqJson = {
        "requirementId": requirement.requirementId,
        "customerName": requirement.customerName,
        "phone": requirement.phone,
        "purpose": requirement.purpose,
        "propertyType": requirement.propertyType,
        "location": requirement.location,
        "maxBudget": requirement.maxBudget,
        "bhk": requirement.bhk,
        "status": requirement.status,
      };

      await _uploadJsonFile('requirement.json', reqJson, specificReqFolderId);
      debugPrint('✅ Requirement successfully saved to Google Drive!');
    } catch (e) {
      debugPrint('❌ Failed to save Requirement to Drive: $e');
      rethrow;
    }
  }

  // UPDATED: Now actually fetches the property data from Drive
  @override
  Future<List<Map<String, dynamic>>> getPropertiesIndex() async {
    try {
      await _initDriveApi();
      final query = "name = 'property.json' and trashed = false";
      final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');

      List<Map<String, dynamic>> propertiesList = [];
      if (fileList.files != null) {
        for (var file in fileList.files!) {
          if (file.id != null) {
            final data = await _downloadJsonFile(file.id!);
            if (data != null) propertiesList.add(data);
          }
        }
      }
      return propertiesList;
    } catch (e) {
      debugPrint('Error fetching properties: $e');
      return [];
    }
  }

  // NEW: Fetches the requirement data from Drive
  @override
  Future<List<Map<String, dynamic>>> getRequirementsIndex() async {
    try {
      await _initDriveApi();
      final query = "name = 'requirement.json' and trashed = false";
      final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');

      List<Map<String, dynamic>> reqList = [];
      if (fileList.files != null) {
        for (var file in fileList.files!) {
          if (file.id != null) {
            final data = await _downloadJsonFile(file.id!);
            if (data != null) reqList.add(data);
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
    debugPrint('Archived property: $id');
  }
}

final storageService = GoogleDriveStorageService();
