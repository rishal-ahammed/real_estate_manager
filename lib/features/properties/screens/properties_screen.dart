import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import '../providers/app_state.dart';

import 'add_property/add_property_shell.dart';

import 'property_detail_screen.dart';

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _showPropertyIds = true;

  bool _preferencesLoaded = false;

  String _sortBy = 'Newest first';

  String _defaultSortPreference = 'Newest First';

  static const Color _primaryColor = Color(0xFF1E3A8A);

  static const List<String> _sortOptions = [
    'Newest first',

    'Oldest first',

    'Budget: Low to High',

    'Budget: High to Low',

    'Name: A to Z',

    'Name: Z to A',
  ];

  @override
  void initState() {
    super.initState();

    appState.addListener(_update);

    _loadPreferences();

    appState.loadProperties();
  }

  @override
  void dispose() {
    appState.removeListener(_update);

    _searchController.dispose();

    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  Future<File> _getSettingsFile() async {
    final directory = await getApplicationDocumentsDirectory();

    final appDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}REAL_ESTATE_APP',
    );

    if (!await appDirectory.exists()) {
      await appDirectory.create(recursive: true);
    }

    return File(
      '${appDirectory.path}${Platform.pathSeparator}account_settings.json',
    );
  }

  Future<void> _loadPreferences() async {
    try {
      final file = await _getSettingsFile();

      if (await file.exists()) {
        final contents = await file.readAsString();

        if (contents.trim().isNotEmpty) {
          final decoded = jsonDecode(contents);

          if (decoded is Map) {
            final showIds = decoded['showPropertyIds'];

            final defaultSort = decoded['defaultSort']?.toString();

            if (!mounted) return;

            setState(() {
              if (showIds is bool) {
                _showPropertyIds = showIds;
              }

              if (defaultSort != null && defaultSort.trim().isNotEmpty) {
                _defaultSortPreference = defaultSort;
              }

              _sortBy = _mapDefaultSort(_defaultSortPreference);

              _preferencesLoaded = true;
            });

            return;
          }
        }
      }
    } catch (error) {
      debugPrint('Unable to load property preferences: $error');
    }

    if (!mounted) return;

    setState(() {
      _sortBy = _mapDefaultSort(_defaultSortPreference);

      _preferencesLoaded = true;
    });
  }

  String _mapDefaultSort(String preference) {
    switch (preference.trim().toLowerCase()) {
      case 'oldest first':
        return 'Oldest first';

      case 'name a–z':
      case 'name a-z':
      case 'name: a to z':
        return 'Name: A to Z';

      case 'name z–a':
      case 'name z-a':
      case 'name: z to a':
        return 'Name: Z to A';

      case 'newest first':
      default:
        return 'Newest first';
    }
  }

  String _normalize(dynamic value) {
    return (value ?? '').toString().split('.').last.trim().toLowerCase();
  }

  String _text(Map<String, dynamic> item, String key, {String nestedKey = ''}) {
    dynamic value = item[key];

    if (nestedKey.isNotEmpty && item[key] is Map) {
      value = item[key][nestedKey];
    }

    return (value ?? '').toString().trim();
  }

  String _propertyName(Map<String, dynamic> prop) {
    final name = _text(prop, 'propertyName');

    return name.isEmpty ? 'Unnamed Property' : name;
  }

  String _propertyType(Map<String, dynamic> prop) {
    final type = _text(prop, 'propertyType');

    return type.isEmpty ? 'Property' : type;
  }

  String _status(Map<String, dynamic> prop) {
    final status = _text(prop, 'status');

    return status.isEmpty ? 'Active' : status;
  }

  String _documentStatus(Map<String, dynamic> prop) {
    return _text(prop, 'documentStatus');
  }

  double _budget(Map<String, dynamic> prop) {
    final dynamic nestedBudget = prop['pricing'] is Map
        ? prop['pricing']['budget']
        : null;

    final dynamic value = nestedBudget ?? prop['budget'] ?? 0;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }

  String _location(Map<String, dynamic> prop) {
    final dynamic locationData = prop['location'];

    if (locationData is Map) {
      final parts =
          [locationData['area'], locationData['city'], locationData['state']]
              .map((value) => (value ?? '').toString().trim())
              .where((value) => value.isNotEmpty)
              .toList();

      return parts.toSet().join(', ');
    }

    return [prop['area'], prop['city'], prop['state']]
        .map((value) => (value ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(', ');
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    }

    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} Lakh';
    }

    return '₹${amount.toStringAsFixed(0)}';
  }

  List<Map<String, dynamic>> get _filteredProperties {
    final query = _searchController.text.trim().toLowerCase();

    final results = appState.properties
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((prop) {
          if (query.isEmpty) return true;

          final searchableText = [
            _propertyName(prop),
            _propertyType(prop),
            _location(prop),
            _text(prop, 'propertyId'),
            _text(prop, 'contactName'),
            _text(prop, 'contactPhone'),
            _text(prop, 'city', nestedKey: 'city'),
            _text(prop, 'pincode'),
          ].join(' ').toLowerCase();

          return searchableText.contains(query);
        })
        .toList();

    results.sort((a, b) {
      switch (_sortBy) {
        case 'Budget: Low to High':
          return _budget(a).compareTo(_budget(b));
        case 'Budget: High to Low':
          return _budget(b).compareTo(_budget(a));
        case 'Name: A to Z':
          return _propertyName(
            a,
          ).toLowerCase().compareTo(_propertyName(b).toLowerCase());
        case 'Name: Z to A':
          return _propertyName(
            b,
          ).toLowerCase().compareTo(_propertyName(a).toLowerCase());
        case 'Oldest first':
          return _compareDates(a, b);
        case 'Newest first':
        default:
          return _compareDates(b, a);
      }
    });

    return results;
  }

  int _compareDates(Map<String, dynamic> a, Map<String, dynamic> b) {
    DateTime? dateFor(Map<String, dynamic> item) {
      for (final key in ['createdAt', 'createdOn', 'dateAdded', 'updatedAt']) {
        final value = item[key];

        if (value == null) continue;

        if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }

        final parsed = DateTime.tryParse(value.toString());

        if (parsed != null) return parsed;
      }

      final id = _text(item, 'propertyId');

      final digits = id.replaceAll(RegExp(r'\D'), '');

      if (digits.length >= 13) {
        final timestamp = int.tryParse(digits.substring(0, 13));

        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }

      return null;
    }

    final dateA = dateFor(a);

    final dateB = dateFor(b);

    if (dateA != null && dateB != null) {
      return dateA.compareTo(dateB);
    }

    if (dateA != null) return 1;

    if (dateB != null) return -1;

    return _text(a, 'propertyId').compareTo(_text(b, 'propertyId'));
  }

  @override
  Widget build(BuildContext context) {
    final allProperties = appState.properties;
    final properties = _filteredProperties;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Properties',
              style: TextStyle(
                color: Color(0xFF172554),
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              'Manage your property listings',
              style: TextStyle(
                color: Colors.blueGrey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddPropertyShell()),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4E9F3)),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: _primaryColor,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: appState.isLoadingProperties || !_preferencesLoaded
          ? const Center(child: CircularProgressIndicator())
          : allProperties.isEmpty
          ? _buildEmptyState(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: const Color(0xFFE7EBF3)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF233B70,
                          ).withValues(alpha: 0.035),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by name, location, phone or ID',
                        hintStyle: TextStyle(
                          color: Colors.blueGrey.shade300,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: _primaryColor,
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, size: 19),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: const BorderSide(
                            color: Color(0xFF9BB5F5),
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${properties.length} ${properties.length == 1 ? 'property' : 'properties'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF172554),
                              ),
                            ),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? 'Your complete property collection'
                                  : 'Search results',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3E8F2)),
                        ),
                        child: PopupMenuButton<String>(
                          tooltip: 'Sort properties',
                          initialValue: _sortBy,
                          onSelected: (value) =>
                              setState(() => _sortBy = value),
                          itemBuilder: (context) => _sortOptions
                              .map(
                                (option) => PopupMenuItem<String>(
                                  value: option,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _sortBy == option
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 17,
                                        color: _sortBy == option
                                            ? _primaryColor
                                            : Colors.blueGrey.shade300,
                                      ),
                                      const SizedBox(width: 9),
                                      Text(
                                        option,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.swap_vert_rounded,
                                  size: 18,
                                  color: _primaryColor,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Sort',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryColor,
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
                Expanded(
                  child: properties.isEmpty
                      ? _buildNoResultsState()
                      : RefreshIndicator(
                          onRefresh: () => appState.loadProperties(),
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 2, 14, 120),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.66,
                                ),
                            itemCount: properties.length,
                            itemBuilder: (context, index) =>
                                _buildPropertyCard(context, properties[index]),
                          ),
                        ),
                ),
              ],
            ),
      // floatingActionButton: Padding(
      //   padding: const EdgeInsets.only(bottom: 86, right: 4),
      //   child: FloatingActionButton.extended(
      //     heroTag: 'addPropertyFab',
      //     onPressed: () {
      //       Navigator.push(
      //         context,
      //         MaterialPageRoute(builder: (_) => const AddPropertyShell()),
      //       );
      //     },
      //     backgroundColor: _primaryColor,
      //     foregroundColor: Colors.white,
      //     elevation: 5,
      //     icon: const Icon(Icons.add_rounded),
      //     label: const Text(
      //       'Add property',
      //       style: TextStyle(fontWeight: FontWeight.w700),
      //     ),
      //   ),
      // ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Map<String, dynamic> prop) {
    final budget = _budget(prop);

    final locationText = _location(prop).isEmpty
        ? 'Unknown Location'
        : _location(prop);

    final type = _propertyType(prop);

    final dynamic specifications = prop['specifications'];

    final dynamic bhkValue = specifications is Map
        ? specifications['bhk']
        : prop['bhk'];

    final bhk = bhkValue?.toString() ?? '-';

    final parsedBhk = int.tryParse(bhk);

    final baths = parsedBhk != null ? '${parsedBhk + 1}' : '-';

    final imagePath = (prop['coverImagePath'] ?? '').toString();

    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();

    final propertyId = _text(prop, 'propertyId');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: const Color(0xFFE6EAF2)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),

            blurRadius: 12,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(20),

        onTap: () {
          Navigator.push(
            context,

            MaterialPageRoute(
              builder: (_) => PropertyDetailScreen(property: prop),
            ),
          );
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,

                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),

                    child: hasImage
                        ? Image.file(
                            File(imagePath),

                            fit: BoxFit.cover,

                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),

                  Positioned(
                    top: 8,

                    left: 8,

                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,

                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          const Icon(
                            Icons.verified,

                            size: 12,

                            color: Colors.blue,
                          ),

                          const SizedBox(width: 4),

                          Text(
                            type,

                            style: const TextStyle(
                              fontSize: 10,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(11, 12, 11, 11),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    _formatCurrency(budget),

                    style: const TextStyle(
                      fontSize: 15,

                      fontWeight: FontWeight.w900,

                      color: _primaryColor,
                    ),

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  Text(
                    _propertyName(prop),

                    style: const TextStyle(
                      fontSize: 13,

                      fontWeight: FontWeight.bold,

                      color: Colors.black87,
                    ),

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,
                  ),

                  if (_showPropertyIds && propertyId.isNotEmpty) ...[
                    const SizedBox(height: 3),

                    Text(
                      'ID: $propertyId',

                      style: TextStyle(
                        fontSize: 10,

                        color: Colors.grey.shade600,
                      ),

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,

                        size: 12,

                        color: Colors.grey,
                      ),

                      const SizedBox(width: 2),

                      Expanded(
                        child: Text(
                          locationText,

                          style: const TextStyle(
                            color: Colors.grey,

                            fontSize: 11,
                          ),

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),

                    child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      Flexible(
                        child: _buildSpecItem(
                          Icons.king_bed_outlined,

                          '$bhk Beds',
                        ),
                      ),

                      const SizedBox(width: 4),

                      Flexible(
                        child: _buildSpecItem(
                          Icons.bathtub_outlined,

                          '$baths Baths',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEDF2FA),

      child: const Center(
        child: Icon(
          Icons.home_work_outlined,
          size: 38,
          color: Color(0xFF9AAAC7),
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),

        const SizedBox(width: 4),

        Flexible(
          child: Text(
            label,

            style: TextStyle(
              color: Colors.grey.shade800,

              fontWeight: FontWeight.w600,

              fontSize: 10,
            ),

            maxLines: 1,

            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => appState.loadProperties(),

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,

            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.real_estate_agent,

                    size: 80,

                    color: Colors.grey.shade300,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'No properties yet',

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Tap the + button to add your first property.',

                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 36,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No properties found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172554),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Try a different name, location, phone number or property ID.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade500, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}
