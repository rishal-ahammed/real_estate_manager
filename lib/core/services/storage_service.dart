import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/property_model.dart';
import '../../data/models/requirement_model.dart';

abstract class StorageService {
  Future<void> saveProperty(dynamic property, {List<String>? imagePaths});

  Future<List<Map<String, dynamic>>> getPropertiesIndex();

  Future<void> archiveProperty(String id);

  Future<void> saveRequirement(dynamic requirement);

  Future<List<Map<String, dynamic>>> getRequirementsIndex();

  Future<void> deleteRequirement(String requirementId);
}

class LocalDeviceStorageService implements StorageService {
  static const String _rootFolderName = 'REAL_ESTATE_APP';

  Future<Directory> _getRootDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documentsDirectory.path, _rootFolderName));

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    return root;
  }

  Future<Directory> _getPropertiesDirectory() async {
    final root = await _getRootDirectory();
    final directory = Directory(p.join(root.path, 'Properties'));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<Directory> _getRequirementsDirectory() async {
    final root = await _getRootDirectory();
    final directory = Directory(p.join(root.path, 'Requirements'));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<void> _writeJsonAtomically(
    File file,
    Map<String, dynamic> data,
  ) async {
    await file.parent.create(recursive: true);

    final temporaryFile = File('${file.path}.tmp');
    final encoded = const JsonEncoder.withIndent('  ').convert(data);

    await temporaryFile.writeAsString(encoded, flush: true);

    if (await file.exists()) {
      await file.delete();
    }

    await temporaryFile.rename(file.path);
  }

  Future<Map<String, dynamic>> _readJson(File file) async {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is! Map) {
      throw FormatException('Expected a JSON object in ${file.path}');
    }

    return Map<String, dynamic>.from(decoded);
  }

  String _newId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _safeId(String id) {
    final cleaned = id.trim();

    if (cleaned.isEmpty ||
        cleaned == '.' ||
        cleaned == '..' ||
        cleaned.contains('/') ||
        cleaned.contains(r'\')) {
      throw ArgumentError('Invalid record ID.');
    }

    return cleaned;
  }

  @override
  Future<void> saveProperty(
    dynamic property, {
    List<String>? imagePaths,
  }) async {
    final Property model;

    if (property is Property) {
      model = property;
    } else if (property is Map<String, dynamic>) {
      model = Property.fromJson(property);
    } else {
      throw ArgumentError(
        'saveProperty expects a Property model or a JSON map.',
      );
    }

    model.propertyId ??= _newId('PROP');

    if (model.propertyId!.trim().isEmpty) {
      model.propertyId = _newId('PROP');
    }

    final id = _safeId(model.propertyId!);
    final propertiesDirectory = await _getPropertiesDirectory();
    final recordDirectory = Directory(p.join(propertiesDirectory.path, id));

    await recordDirectory.create(recursive: true);

    final imagesDirectory = Directory(p.join(recordDirectory.path, 'Images'));

    // Build the new image collection separately so existing images
    // remain intact while their copies are being prepared.
    final stagingDirectory = Directory(
      p.join(recordDirectory.path, '.Images_tmp'),
    );

    if (await stagingDirectory.exists()) {
      await stagingDirectory.delete(recursive: true);
    }

    await stagingDirectory.create(recursive: true);

    // An explicitly supplied empty list means remove all images.
    // If no list is supplied, use the model's existing images.
    final sources = imagePaths ?? model.images;
    final stagedNames = <String>[];

    try {
      for (final sourcePath in sources) {
        final source = File(sourcePath);

        if (!await source.exists()) {
          continue;
        }

        var extension = p.extension(sourcePath);
        if (extension.isEmpty) {
          extension = '.jpg';
        }

        final imageName = 'property_img_${stagedNames.length}$extension';
        final destination = File(p.join(stagingDirectory.path, imageName));

        await source.copy(destination.path);
        stagedNames.add(imageName);
      }

      // Replace the old image collection only after staging succeeds.
      if (await imagesDirectory.exists()) {
        await imagesDirectory.delete(recursive: true);
      }

      await stagingDirectory.rename(imagesDirectory.path);

      model.images = stagedNames
          .map((name) => p.join(imagesDirectory.path, name))
          .toList();

      final data = model.toJson();

      // Keep compatibility with the existing detail screen.
      data['pricing'] = {
        'budget': model.budget,
        'isNegotiable': model.isNegotiable,
        'landRate': model.landRate,
      };

      data['location'] = {
        'state': model.state,
        'city': model.city,
        'area': model.area,
        'pincode': model.pincode,
      };

      data['specifications'] = {
        'bhk': model.bhk,
        'floors': model.floors,
        'landArea': model.landArea,
        'builtUpArea': model.builtUpArea,
        'furnishedStatus': model.furnishedStatus,
        'facing': model.facing,
        'builtYear': model.builtYear,
      };

      data['coverImagePath'] = model.images.isNotEmpty
          ? model.images.first
          : null;
      data['allImagePaths'] = model.images;

      await _writeJsonAtomically(
        File(p.join(recordDirectory.path, 'property.json')),
        data,
      );
    } catch (_) {
      // Clean up unfinished staging files when possible.
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPropertiesIndex() async {
    final propertiesDirectory = await _getPropertiesDirectory();
    final records = <Map<String, dynamic>>[];

    await for (final entity in propertiesDirectory.list()) {
      if (entity is! Directory) continue;

      final file = File(p.join(entity.path, 'property.json'));
      if (!await file.exists()) continue;

      try {
        final data = await _readJson(file);

        // Reconcile the image paths with the saved Images folder.
        final imagesDirectory = Directory(p.join(entity.path, 'Images'));
        final imagePaths = <String>[];

        if (await imagesDirectory.exists()) {
          final imageFiles = <File>[];

          await for (final imageEntity in imagesDirectory.list()) {
            if (imageEntity is File) {
              final extension = p.extension(imageEntity.path).toLowerCase();
              if (['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
                imageFiles.add(imageEntity);
              }
            }
          }

          imageFiles.sort((a, b) => a.path.compareTo(b.path));
          imagePaths.addAll(imageFiles.map((file) => file.path));
        }

        data['images'] = imagePaths;
        data['allImagePaths'] = imagePaths;
        data['coverImagePath'] = imagePaths.isNotEmpty
            ? imagePaths.first
            : null;

        records.add(data);
      } catch (error) {
        // Keep other records available if one record is damaged.
        // Do not silently delete or overwrite the damaged file.
        stderr.writeln('Could not read property file ${file.path}: $error');
      }
    }

    records.sort((a, b) {
      final aId = a['propertyId']?.toString() ?? '';
      final bId = b['propertyId']?.toString() ?? '';
      return bId.compareTo(aId);
    });

    return records;
  }

  @override
  Future<void> archiveProperty(String id) async {
    final safeId = _safeId(id);
    final directory = await _getPropertiesDirectory();
    final recordDirectory = Directory(p.join(directory.path, safeId));

    if (await recordDirectory.exists()) {
      await recordDirectory.delete(recursive: true);
    }
  }

  @override
  Future<void> saveRequirement(dynamic requirement) async {
    final Requirement model;

    if (requirement is Requirement) {
      model = requirement;
    } else if (requirement is Map<String, dynamic>) {
      model = Requirement.fromJson(requirement);
    } else {
      throw ArgumentError(
        'saveRequirement expects a Requirement model or a JSON map.',
      );
    }

    if (model.requirementId.trim().isEmpty) {
      model.requirementId = _newId('REQ');
    }

    final id = _safeId(model.requirementId);
    final requirementsDirectory = await _getRequirementsDirectory();
    final recordDirectory = Directory(p.join(requirementsDirectory.path, id));

    await recordDirectory.create(recursive: true);

    await _writeJsonAtomically(
      File(p.join(recordDirectory.path, 'requirement.json')),
      model.toJson(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getRequirementsIndex() async {
    final requirementsDirectory = await _getRequirementsDirectory();
    final records = <Map<String, dynamic>>[];

    await for (final entity in requirementsDirectory.list()) {
      if (entity is! Directory) continue;

      final file = File(p.join(entity.path, 'requirement.json'));
      if (!await file.exists()) continue;

      try {
        records.add(await _readJson(file));
      } catch (error) {
        stderr.writeln('Could not read requirement file ${file.path}: $error');
      }
    }

    records.sort((a, b) {
      final aId = a['requirementId']?.toString() ?? '';
      final bId = b['requirementId']?.toString() ?? '';
      return bId.compareTo(aId);
    });

    return records;
  }

  @override
  Future<void> deleteRequirement(String requirementId) async {
    final safeId = _safeId(requirementId);
    final directory = await _getRequirementsDirectory();

    final recordDirectory = Directory(p.join(directory.path, safeId));

    if (await recordDirectory.exists()) {
      await recordDirectory.delete(recursive: true);
    }
  }
}

// One shared storage service for the whole application.
final StorageService storageService = LocalDeviceStorageService();
