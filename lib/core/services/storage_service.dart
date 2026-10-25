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

  static const int maxImages = 10;
  static const int maxVideos = 5;

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

  Future<List<String>> _copyMediaFiles({
    required List<String> sources,
    required Directory destinationDirectory,
    required String filePrefix,
    required int maximumCount,
    required Set<String> allowedExtensions,
  }) async {
    if (sources.length > maximumCount) {
      throw ArgumentError(
        'A property can have at most $maximumCount '
        '${filePrefix == 'property_img' ? 'photos' : 'videos'}.',
      );
    }

    await destinationDirectory.create(recursive: true);

    final savedPaths = <String>[];

    for (final sourcePath in sources) {
      final source = File(sourcePath);

      if (!await source.exists()) {
        // Existing stored paths may already point to files in this folder.
        // Missing files are skipped rather than saved as invalid paths.
        continue;
      }

      var extension = p.extension(sourcePath).toLowerCase();

      if (extension.isEmpty || !allowedExtensions.contains(extension)) {
        throw ArgumentError('Unsupported media file type: $sourcePath');
      }

      final fileName = '${filePrefix}_${savedPaths.length}$extension';
      final destination = File(p.join(destinationDirectory.path, fileName));

      // Avoid copying a file onto itself when saving existing media.
      if (p.equals(source.absolute.path, destination.absolute.path)) {
        savedPaths.add(destination.path);
        continue;
      }

      await source.copy(destination.path);
      savedPaths.add(destination.path);
    }

    return savedPaths;
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
    final videosDirectory = Directory(p.join(recordDirectory.path, 'Videos'));

    final imageStagingDirectory = Directory(
      p.join(recordDirectory.path, '.Images_tmp'),
    );
    final videoStagingDirectory = Directory(
      p.join(recordDirectory.path, '.Videos_tmp'),
    );

    if (model.videos.length > maxVideos) {
      throw ArgumentError('A property can have at most 5 videos.');
    }

    final imageSources = imagePaths ?? model.images;
    if (imageSources.length > maxImages) {
      throw ArgumentError('A property can have at most 10 photos.');
    }

    // Prepare both media collections before replacing existing folders.
    for (final directory in [imageStagingDirectory, videoStagingDirectory]) {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);
    }

    try {
      final stagedImages = await _copyMediaFiles(
        sources: imageSources,
        destinationDirectory: imageStagingDirectory,
        filePrefix: 'property_img',
        maximumCount: maxImages,
        allowedExtensions: {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'},
      );

      final stagedVideos = await _copyMediaFiles(
        sources: model.videos,
        destinationDirectory: videoStagingDirectory,
        filePrefix: 'property_video',
        maximumCount: maxVideos,
        allowedExtensions: {
          '.mp4',
          '.mov',
          '.m4v',
          '.3gp',
          '.webm',
          '.mkv',
          '.avi',
        },
      );

      // Replace the old media directories after staging is complete.
      if (await imagesDirectory.exists()) {
        await imagesDirectory.delete(recursive: true);
      }

      if (await videosDirectory.exists()) {
        await videosDirectory.delete(recursive: true);
      }

      await imageStagingDirectory.rename(imagesDirectory.path);
      await videoStagingDirectory.rename(videosDirectory.path);

      model.images = stagedImages
          .map((path) => p.join(imagesDirectory.path, p.basename(path)))
          .toList();

      model.videos = stagedVideos
          .map((path) => p.join(videosDirectory.path, p.basename(path)))
          .toList();

      final data = model.toJson();

      data['images'] = model.images;
      data['videos'] = model.videos;

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
      if (await imageStagingDirectory.exists()) {
        await imageStagingDirectory.delete(recursive: true);
      }

      if (await videoStagingDirectory.exists()) {
        await videoStagingDirectory.delete(recursive: true);
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

        final imagesDirectory = Directory(p.join(entity.path, 'Images'));

        final videosDirectory = Directory(p.join(entity.path, 'Videos'));

        final imagePaths = <String>[];
        final videoPaths = <String>[];

        if (await imagesDirectory.exists()) {
          final imageFiles = <File>[];

          await for (final mediaEntity in imagesDirectory.list()) {
            if (mediaEntity is! File) continue;

            final extension = p.extension(mediaEntity.path).toLowerCase();

            if ({
              '.jpg',
              '.jpeg',
              '.png',
              '.webp',
              '.heic',
              '.heif',
            }.contains(extension)) {
              imageFiles.add(mediaEntity);
            }
          }

          imageFiles.sort((a, b) => a.path.compareTo(b.path));

          imagePaths.addAll(imageFiles.map((file) => file.path));
        }

        if (await videosDirectory.exists()) {
          final videoFiles = <File>[];

          await for (final mediaEntity in videosDirectory.list()) {
            if (mediaEntity is! File) continue;

            final extension = p.extension(mediaEntity.path).toLowerCase();

            if ({
              '.mp4',
              '.mov',
              '.m4v',
              '.3gp',
              '.webm',
              '.mkv',
              '.avi',
            }.contains(extension)) {
              videoFiles.add(mediaEntity);
            }
          }

          videoFiles.sort((a, b) => a.path.compareTo(b.path));

          videoPaths.addAll(videoFiles.map((file) => file.path));
        }

        // Reconcile saved media paths with files actually present.
        data['images'] = imagePaths;
        data['videos'] = videoPaths;
        data['allImagePaths'] = imagePaths;
        data['coverImagePath'] = imagePaths.isNotEmpty
            ? imagePaths.first
            : null;

        records.add(data);
      } catch (error) {
        // Keep other records available if one record is damaged.
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
    final propertyFile = File(p.join(recordDirectory.path, 'property.json'));

    if (!await propertyFile.exists()) {
      throw StateError('Property not found: $safeId');
    }

    final data = await _readJson(propertyFile);

    // Preserve every existing field and all media files.
    data['propertyId'] ??= safeId;
    data['status'] = PropertyStatus.archived.name;

    await _writeJsonAtomically(propertyFile, data);
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
