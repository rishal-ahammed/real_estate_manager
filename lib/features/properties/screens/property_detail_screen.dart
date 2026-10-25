import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/storage_service.dart';
import '../../../data/models/property_model.dart';
import '../providers/app_state.dart';
import 'add_property/add_property_shell.dart';

class PropertyDetailScreen extends StatefulWidget {
  final dynamic property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _background = Color(0xFFF7F8FC);
  static const Color _border = Color(0xFFE9ECF3);

  int _currentImageIndex = 0;
  late Map<String, dynamic> _propertyData;

  @override
  void initState() {
    super.initState();
    _propertyData = widget.property is Map
        ? Map<String, dynamic>.from(widget.property as Map)
        : <String, dynamic>{};
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    }
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(0)} Lakhs';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _getImages(Map<String, dynamic> prop) {
    final images = <String>[];
    final dynamic allImages = prop['allImagePaths'] ?? prop['images'];

    if (allImages is List) {
      images.addAll(
        allImages.map((e) => e.toString()).where((e) => e.isNotEmpty),
      );
    }

    if (images.isEmpty && prop['coverImagePath'] != null) {
      final cover = prop['coverImagePath'].toString();
      if (cover.isNotEmpty) images.add(cover);
    }

    return images;
  }

  List<String> _getVideos(Map<String, dynamic> prop) {
    final dynamic rawVideos = prop['videos'];
    if (rawVideos is! List) return [];

    return rawVideos
        .map((item) => item.toString())
        .where((path) => path.trim().isNotEmpty)
        .toList();
  }

  Future<void> _editProperty(String propertyId) async {
    if (propertyId.isEmpty || propertyId == 'N/A') {
      _message('Unable to edit: Property ID is missing.');
      return;
    }

    try {
      final model = Property.fromJson(Map<String, dynamic>.from(_propertyData));

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddPropertyShell(propertyToEdit: model),
        ),
      );

      if (!mounted || result != true) return;

      await appState.loadProperties();
      final saved = await storageService.getPropertiesIndex();

      Map<String, dynamic>? updated;

      for (final item in saved) {
        final map = Map<String, dynamic>.from(item);
        if (map['propertyId']?.toString() == propertyId) {
          updated = map;
          break;
        }
      }

      if (!mounted) return;

      if (updated != null) {
        setState(() {
          _propertyData = updated!;
          _currentImageIndex = 0;
        });
        _message('Property updated successfully');
      } else {
        _message(
          'Changes saved, but the updated property could not be loaded.',
        );
      }
    } catch (error) {
      if (mounted) {
        _message('Unable to edit property: $error', error: true);
      }
    }
  }

  Future<void> _confirmDelete(String propertyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Expanded(child: Text('Delete Property')),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this property? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await storageService.archiveProperty(propertyId);
      await appState.loadProperties();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Property deleted successfully'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        _message('Unable to delete property: $error', error: true);
      }
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prop = _propertyData;
    final pricing = prop['pricing'];
    final specifications = prop['specifications'];
    final location = prop['location'];

    final budget = _toDouble(
      pricing is Map ? pricing['budget'] : prop['budget'],
    );

    final name = prop['propertyName']?.toString() ?? 'Property Details';
    final type = prop['propertyType']?.toString() ?? '';
    final id = prop['propertyId']?.toString() ?? 'N/A';

    final bhk = specifications is Map
        ? (specifications['bhk'] ?? prop['bhk'] ?? '—').toString()
        : (prop['bhk'] ?? '—').toString();

    final loc = location is Map ? Map<String, dynamic>.from(location) : null;

    final area = loc?['area']?.toString() ?? prop['area']?.toString() ?? '';
    final city = loc?['city']?.toString() ?? prop['city']?.toString() ?? '';

    final locationText = [
      area,
      city,
    ].where((e) => e.trim().isNotEmpty).join(', ');

    final images = _getImages(prop);
    final videos = _getVideos(prop);

    final negotiable = pricing is Map
        ? (pricing['isNegotiable'] ?? prop['isNegotiable'] ?? true) == true
        : prop['isNegotiable'] == true;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF172033),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit property',
            onPressed: () => _editProperty(id),
            icon: const Icon(Icons.edit_outlined, color: _primary),
          ),
          IconButton(
            tooltip: 'Delete property',
            onPressed: () => _confirmDelete(id),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _buildMediaGallery(images, videos),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(
                  budget,
                  name,
                  bhk,
                  type,
                  negotiable,
                  locationText,
                ),
                const SizedBox(height: 16),
                _buildInformationCard(prop, id, type, bhk),
                const SizedBox(height: 16),
                _buildContactCard(prop),
                const SizedBox(height: 16),
                _buildLocationCard(
                  locationText.isEmpty ? 'Location not provided' : locationText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGallery(List<String> images, List<String> videos) {
    final photoPaths = images.where((path) => File(path).existsSync()).toList();
    final videoPaths = videos.where((path) => File(path).existsSync()).toList();

    final totalItems = photoPaths.length + videoPaths.length;

    if (totalItems == 0) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          color: const Color(0xFFE9ECF3),
          child: const Center(
            child: Icon(
              Icons.home_work_outlined,
              size: 64,
              color: Color(0xFF8791A5),
            ),
          ),
        ),
      );
    }

    final safeIndex = _currentImageIndex.clamp(0, totalItems - 1);

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: totalItems,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              if (index < photoPaths.length) {
                return Image.file(
                  File(photoPaths[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => _brokenImage(),
                );
              }

              final videoIndex = index - photoPaths.length;
              final videoPath = videoPaths[videoIndex];

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FullScreenPropertyVideo(videoPath: videoPath),
                    ),
                  );
                },
                child: _AutoPlayVideoPage(
                  key: ValueKey(videoPath),
                  path: videoPath,
                  isActive: safeIndex == index,
                ),
              );
            },
          ),
          Positioned(
            left: 16,
            top: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      photoPaths.isNotEmpty && videoPaths.isNotEmpty
                          ? 'Photos & Videos'
                          : photoPaths.isNotEmpty
                          ? 'Property photos'
                          : 'Property videos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (totalItems > 1)
            Positioned(
              right: 16,
              bottom: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '${safeIndex + 1} / $totalItems',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _brokenImage() {
    return Container(
      color: const Color(0xFFE9ECF3),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 60,
          color: Color(0xFF8791A5),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    double budget,
    String name,
    String bhk,
    String type,
    bool negotiable,
    String location,
  ) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _formatCurrency(budget),
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  negotiable ? 'Negotiable' : 'Fixed price',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (type.isNotEmpty) _chip(Icons.home_work_outlined, type),
              if (bhk.isNotEmpty && bhk != '—' && bhk != '0')
                _chip(Icons.bedroom_parent_outlined, '$bhk BHK'),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: _primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      color: Color(0xFF657087),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInformationCard(
    Map<String, dynamic> prop,
    String propertyId,
    String type,
    String bhk,
  ) {
    final pricing = prop['pricing'];
    final specifications = prop['specifications'];
    final location = prop['location'];

    dynamic valueFrom(String key, {dynamic fallback = '—'}) {
      if (prop[key] != null) return prop[key];
      if (specifications is Map && specifications[key] != null) {
        return specifications[key];
      }
      if (pricing is Map && pricing[key] != null) {
        return pricing[key];
      }
      if (location is Map && location[key] != null) {
        return location[key];
      }
      return fallback;
    }

    final rows = <List<String>>[
      [
        'Property document',
        valueFrom('documentStatus', fallback: 'Available').toString(),
      ],
      ['Property ID', propertyId],
      ['Property type', type.isEmpty ? 'N/A' : type],
      ['Width', valueFrom('width').toString()],
      ['Length', valueFrom('length').toString()],
      ['Land area', '${valueFrom('landArea')} cent'],
      ['Land rate / cent', valueFrom('landRate').toString()],
      ['Built-up area', '${valueFrom('builtUpArea')} sq.ft'],
      ['Bedrooms', bhk],
      ['Number of floors', valueFrom('floors').toString()],
      ['Furnished', valueFrom('furnishedStatus').toString()],
      ['Built year', valueFrom('builtYear').toString()],
      ['Parking', valueFrom('parking').toString()],
      ['Direction', valueFrom('facing').toString()],
      ['Status', valueFrom('status', fallback: 'ACTIVE').toString()],
    ];

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.info_outline,
            'Property information',
            'Key details about this listing',
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++) ...[
            _buildInfoRow(rows[i][0], rows[i][1]),
            if (i != rows.length - 1) const Divider(height: 20, color: _border),
          ],
        ],
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final number = phone.trim();

    if (number.isEmpty || number == 'Not provided' || number == 'N/A') {
      _message('No phone number is available for this contact.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: number);

    try {
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        _message('Unable to open the phone app.');
      }
    } catch (_) {
      if (mounted) _message('Unable to open the phone app.');
    }
  }

  Widget _buildContactCard(Map<String, dynamic> prop) {
    final contactName = prop['contactName']?.toString() ?? 'Not provided';
    final contactType = prop['contactType']?.toString() ?? '';

    final phone =
        prop['contactPhone']?.toString() ??
        prop['phoneNumber']?.toString() ??
        prop['phone']?.toString() ??
        'Not provided';

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.person_outline,
            'Contact information',
            'Owner, broker, or listing contact',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_outline, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172033),
                      ),
                    ),
                    if (contactType.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        contactType,
                        style: const TextStyle(
                          color: Color(0xFF657087),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _callPhone(phone),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 19, color: _primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        phone,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.call_rounded, size: 19, color: _primary),
                    const SizedBox(width: 6),
                    const Text(
                      'Call',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(String location) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.location_on_outlined,
            'Location',
            'Where this property is situated',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on, color: _primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      location,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172033),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A8498)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF3C465B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A8498),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF263248),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gallery video preview. Opens the full-screen player when tapped.
/// Automatically plays when active and pauses when another page is selected.
class _AutoPlayVideoPage extends StatefulWidget {
  final String path;
  final bool isActive;

  const _AutoPlayVideoPage({
    super.key,
    required this.path,
    required this.isActive,
  });

  @override
  State<_AutoPlayVideoPage> createState() => _AutoPlayVideoPageState();
}

class _AutoPlayVideoPageState extends State<_AutoPlayVideoPage> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _muted = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _AutoPlayVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.path != widget.path) {
      _disposeController();
      _error = null;
      _initializing = false;

      if (widget.isActive) _initializeVideo();
      return;
    }

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        if (_controller == null && !_initializing) {
          _initializeVideo();
        } else {
          _playVideo();
        }
      } else {
        _controller?.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (_initializing || _controller != null) return;

    _initializing = true;

    final controller = VideoPlayerController.file(File(widget.path));
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);

      if (!mounted || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }

      setState(() => _initializing = false);

      if (widget.isActive) {
        await controller.play();
      }
    } catch (_) {
      if (!mounted || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }

      setState(() {
        _initializing = false;
        _error = 'Unable to load this video';
      });
    }
  }

  Future<void> _playVideo() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.setVolume(_muted ? 0 : 1);

      if (widget.isActive && mounted) {
        await controller.play();
      }
    } catch (_) {
      // Controller may have been disposed during a page transition.
    }
  }

  Future<void> _toggleSound() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    final nextMuted = !_muted;
    setState(() => _muted = nextMuted);

    try {
      await controller.setVolume(nextMuted ? 0 : 1);
    } catch (_) {
      // Ignore changes during disposal.
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;

    if (controller != null) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_error != null) {
      return Container(
        color: const Color(0xFF111827),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'Unable to load this video',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return Container(
        color: const Color(0xFF111827),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
          // Positioned(
          //   top: 35,
          //   left: 16,
          //   child: IgnorePointer(
          //     child: Container(
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 10,
          //         vertical: 6,
          //       ),
          //       decoration: BoxDecoration(
          //         color: Colors.black54,
          //         borderRadius: BorderRadius.circular(20),
          //       ),
          //       child: const Row(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           Icon(
          //             Icons.play_circle_outline,
          //             color: Colors.white,
          //             size: 16,
          //           ),
          //           SizedBox(width: 5),
          //           Text(
          //             'PROPERTY VIDEO',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 11,
          //               fontWeight: FontWeight.w700,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          Positioned(
            left: 16,
            bottom: 12,
            child: IconButton.filled(
              tooltip: _muted ? 'Turn sound on' : 'Mute video',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              onPressed: _toggleSound,
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen video player with playback controls and seek bar.
class FullScreenPropertyVideo extends StatefulWidget {
  final String videoPath;

  const FullScreenPropertyVideo({super.key, required this.videoPath});

  @override
  State<FullScreenPropertyVideo> createState() =>
      _FullScreenPropertyVideoState();
}

class _FullScreenPropertyVideoState extends State<FullScreenPropertyVideo> {
  late final VideoPlayerController _controller;

  bool _ready = false;
  bool _muted = true;
  bool _showControls = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.file(File(widget.videoPath));

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);

      if (!mounted) return;

      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load this video.';
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_ready) return;

    try {
      if (_controller.value.isPlaying) {
        await _controller.pause();
      } else {
        if (_controller.value.position >= _controller.value.duration) {
          await _controller.seekTo(Duration.zero);
        }
        await _controller.play();
      }

      if (mounted) setState(() {});
    } catch (_) {
      // Ignore controller errors during shutdown.
    }
  }

  Future<void> _toggleMute() async {
    if (!_ready) return;

    final nextMuted = !_muted;

    try {
      await _controller.setVolume(nextMuted ? 0 : 1);

      if (mounted) {
        setState(() => _muted = nextMuted);
      }
    } catch (_) {
      // Ignore controller errors during shutdown.
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Property Video'),
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            )
          : !_ready
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                final durationMs = value.duration.inMilliseconds;
                final maxMs = durationMs > 0 ? durationMs : 1;

                final positionMs = value.position.inMilliseconds
                    .clamp(0, maxMs)
                    .toDouble();

                return SizedBox.expand(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _showControls = !_showControls;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: value.aspectRatio > 0
                                ? value.aspectRatio
                                : 16 / 9,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                        if (_showControls)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: Stack(
                                children: [
                                  Center(
                                    child: IconButton(
                                      onPressed: _togglePlayPause,
                                      iconSize: 68,
                                      color: Colors.white,
                                      icon: Icon(
                                        value.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_fill,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    bottom: 12,
                                    child: SafeArea(
                                      top: false,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              _formatDuration(value.position),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Expanded(
                                              child: Slider(
                                                min: 0,
                                                max: maxMs.toDouble(),
                                                value: positionMs,
                                                onChanged: (newValue) {
                                                  _controller.seekTo(
                                                    Duration(
                                                      milliseconds: newValue
                                                          .round(),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(value.duration),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: _muted
                                                  ? 'Unmute'
                                                  : 'Mute',
                                              color: Colors.white,
                                              onPressed: _toggleMute,
                                              icon: Icon(
                                                _muted
                                                    ? Icons.volume_off
                                                    : Icons.volume_up,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
