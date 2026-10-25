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

  // Applied filters
  final Set<String> _selectedTypes = {};
  String? _selectedBhk;
  String? _selectedDocumentStatus;
  String? _selectedListingStatus;
  double? _minBudget;
  double? _maxBudget;
  String _locationFilter = '';

  static const Color _primaryColor = Color(0xFF1E3A8A);
  static const Color _pageColor = Color(0xFFF7F8FC);

  static const List<String> _propertyTypes = [
    'Vacant Land',
    'Building',
    'Apartment',
    'Commercial',
    'Villa',
    'Agri Land',
  ];

  static const List<String> _bhkOptions = [
    '1 BHK',
    '2 BHK',
    '3 BHK',
    '4 BHK',
    '5+ BHK',
  ];

  static const List<String> _documentStatuses = ['Available', 'In Bank'];

  static const List<String> _listingStatuses = [
    'Draft',
    'Active',
    'Reserved',
    'Sold',
    'Rented',
    'Inactive',
    'Archived',
  ];

  static const List<String> _sortOptions = [
    'Newest first',
    'Oldest first',
    'Budget: Low to High',
    'Budget: High to Low',
    'Name: A to Z',
    'Name: Z to A',
  ];

  bool get _hasActiveFilters =>
      _selectedTypes.isNotEmpty ||
      _selectedBhk != null ||
      _selectedDocumentStatus != null ||
      _selectedListingStatus != null ||
      _minBudget != null ||
      _maxBudget != null ||
      _locationFilter.trim().isNotEmpty;

  int get _activeFilterCount {
    int count = _selectedTypes.length;
    if (_selectedBhk != null) count++;
    if (_selectedDocumentStatus != null) count++;
    if (_selectedListingStatus != null) count++;
    if (_minBudget != null) count++;
    if (_maxBudget != null) count++;
    if (_locationFilter.trim().isNotEmpty) count++;
    return count;
  }

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
      case 'budget: low to high':
        return 'Budget: Low to High';
      case 'budget: high to low':
        return 'Budget: High to Low';
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
    return (value ?? '')
        .toString()
        .split('.')
        .last
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
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

  String _documentStatus(Map<String, dynamic> prop) {
    dynamic value = prop['documentStatus'];

    // Support older records that store the value inside nested maps.
    if (value == null || value.toString().trim().isEmpty) {
      for (final key in ['specifications', 'pricing', 'location']) {
        final nested = prop[key];

        if (nested is Map &&
            nested['documentStatus'] != null &&
            nested['documentStatus'].toString().trim().isNotEmpty) {
          value = nested['documentStatus'];
          break;
        }
      }
    }

    final status = (value?.toString() ?? '').trim().toLowerCase();

    // Treat all bank/pledged/mortgaged labels as the same filter value.
    if (status.contains('bank') ||
        status.contains('pledged') ||
        status.contains('mortgaged')) {
      return 'In Bank';
    }

    if (status.isEmpty || status == 'available') {
      return 'Available';
    }

    return value.toString().trim();
  }

  String _listingStatus(Map<String, dynamic> prop) {
    final status = _normalize(prop['status']);
    return status.isEmpty ? 'active' : status;
  }

  String _bhk(Map<String, dynamic> prop) {
    final specifications = prop['specifications'];

    final dynamic value = specifications is Map
        ? specifications['bhk'] ?? prop['bhk']
        : prop['bhk'];

    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    final parsed = int.tryParse(value.toString().trim());
    if (parsed != null) {
      return parsed >= 5 ? '5+ bhk' : '$parsed bhk';
    }

    return '${_normalize(value).replaceAll('bhk', '').trim()} bhk';
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

  bool _matchesFilters(Map<String, dynamic> prop) {
    if (_selectedTypes.isNotEmpty) {
      final type = _normalize(_propertyType(prop));
      if (!_selectedTypes.any((item) => _normalize(item) == type)) {
        return false;
      }
    }

    if (_selectedBhk != null) {
      if (_bhk(prop) != _normalize(_selectedBhk)) {
        return false;
      }
    }

    final budget = _budget(prop);

    if (_minBudget != null && budget < _minBudget!) return false;
    if (_maxBudget != null && budget > _maxBudget!) return false;

    if (_locationFilter.trim().isNotEmpty) {
      final searchableLocation = [
        _location(prop),
        _text(prop, 'area'),
        _text(prop, 'city'),
        _text(prop, 'state'),
        _text(prop, 'pincode'),
      ].join(' ').toLowerCase();

      if (!searchableLocation.contains(_locationFilter.trim().toLowerCase())) {
        return false;
      }
    }

    if (_selectedDocumentStatus != null) {
      if (_normalize(_documentStatus(prop)) !=
          _normalize(_selectedDocumentStatus)) {
        return false;
      }
    }

    if (_selectedListingStatus != null) {
      if (_listingStatus(prop) != _normalize(_selectedListingStatus)) {
        return false;
      }
    }

    return true;
  }

  List<Map<String, dynamic>> get _filteredProperties {
    final query = _searchController.text.trim().toLowerCase();

    final results = appState.properties
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((prop) {
          if (!_matchesFilters(prop)) return false;
          if (query.isEmpty) return true;

          final searchableText = [
            _propertyName(prop),
            _propertyType(prop),
            _location(prop),
            _text(prop, 'propertyId'),
            _text(prop, 'contactName'),
            _text(prop, 'contactPhone'),
            _text(prop, 'city'),
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

  void _resetFilters() {
    setState(() {
      _selectedTypes.clear();
      _selectedBhk = null;
      _selectedDocumentStatus = null;
      _selectedListingStatus = null;
      _minBudget = null;
      _maxBudget = null;
      _locationFilter = '';
    });
  }

  void _toggleQuickType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  Future<void> _showFilterDialog() async {
    final minController = TextEditingController(
      text: _minBudget?.toStringAsFixed(0) ?? '',
    );
    final maxController = TextEditingController(
      text: _maxBudget?.toStringAsFixed(0) ?? '',
    );
    final locationController = TextEditingController(text: _locationFilter);

    final temporaryTypes = Set<String>.from(_selectedTypes);
    String? temporaryBhk = _selectedBhk;
    String? temporaryDocumentStatus = _selectedDocumentStatus;
    String? temporaryListingStatus = _selectedListingStatus;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget sectionTitle(String title, {String? subtitle}) {
              return Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172554),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            Widget choiceChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return FilterChip(
                label: Text(label),
                selected: selected,
                showCheckmark: true,
                onSelected: (_) => onTap(),
                selectedColor: const Color(0xFFE5ECFF),
                checkmarkColor: _primaryColor,
                labelStyle: TextStyle(
                  color: selected ? _primaryColor : Colors.blueGrey.shade700,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF9BB5F5)
                      : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }

            InputDecoration inputDecoration(String label) {
              return InputDecoration(
                labelText: label,
                prefixText: '₹ ',
                filled: true,
                fillColor: const Color(0xFFF8FAFF),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              );
            }

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEFF),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter Properties',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF172554),
                                  ),
                                ),
                                Text(
                                  'Choose the criteria you need',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                temporaryTypes.clear();
                                temporaryBhk = null;
                                temporaryDocumentStatus = null;
                                temporaryListingStatus = null;
                                minController.clear();
                                maxController.clear();
                                locationController.clear();
                              });
                            },
                            child: const Text('Reset'),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          sectionTitle(
                            'Property Type',
                            subtitle: 'Select one or more types',
                          ),
                          Wrap(
                            spacing: 7,
                            runSpacing: 0,
                            children: _propertyTypes.map((type) {
                              return choiceChip(
                                label: type,
                                selected: temporaryTypes.contains(type),
                                onTap: () {
                                  setSheetState(() {
                                    if (temporaryTypes.contains(type)) {
                                      temporaryTypes.remove(type);
                                    } else {
                                      temporaryTypes.add(type);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          sectionTitle(
                            'BHK',
                            subtitle: 'Applies to residential properties',
                          ),
                          Wrap(
                            spacing: 7,
                            runSpacing: 0,
                            children: _bhkOptions.map((bhk) {
                              return choiceChip(
                                label: bhk,
                                selected: temporaryBhk == bhk,
                                onTap: () {
                                  setSheetState(() {
                                    temporaryBhk = temporaryBhk == bhk
                                        ? null
                                        : bhk;
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          sectionTitle(
                            'Budget Range',
                            subtitle: 'Leave either field empty for no limit',
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: inputDecoration('Minimum'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: maxController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: inputDecoration('Maximum'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter the full amount in rupees. Example: 2500000 for ₹25 lakh.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey.shade500,
                            ),
                          ),

                          sectionTitle('Location'),
                          TextField(
                            controller: locationController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Area, city, state or pincode',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                color: _primaryColor,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),

                          sectionTitle('Document Status'),
                          Wrap(
                            spacing: 7,
                            children: _documentStatuses.map((status) {
                              return choiceChip(
                                label: status,
                                selected: temporaryDocumentStatus == status,
                                onTap: () {
                                  setSheetState(() {
                                    temporaryDocumentStatus =
                                        temporaryDocumentStatus == status
                                        ? null
                                        : status;
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 12),
                            title: const Text(
                              'More Filters',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF172554),
                              ),
                            ),
                            subtitle: const Text(
                              'Listing status',
                              style: TextStyle(fontSize: 11),
                            ),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 7,
                                  children: _listingStatuses.map((status) {
                                    return choiceChip(
                                      label: status,
                                      selected:
                                          temporaryListingStatus == status,
                                      onTap: () {
                                        setSheetState(() {
                                          temporaryListingStatus =
                                              temporaryListingStatus == status
                                              ? null
                                              : status;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        12 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE8ECF3)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTypes.clear();
                                  _selectedBhk = null;
                                  _selectedDocumentStatus = null;
                                  _selectedListingStatus = null;
                                  _minBudget = null;
                                  _maxBudget = null;
                                  _locationFilter = '';
                                });
                                Navigator.pop(sheetContext);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                foregroundColor: _primaryColor,
                                side: const BorderSide(
                                  color: Color(0xFFD6DEED),
                                ),
                              ),
                              child: const Text('Clear All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final min = minController.text.trim().isEmpty
                                    ? null
                                    : double.tryParse(
                                        minController.text.trim().replaceAll(
                                          ',',
                                          '',
                                        ),
                                      );

                                final max = maxController.text.trim().isEmpty
                                    ? null
                                    : double.tryParse(
                                        maxController.text.trim().replaceAll(
                                          ',',
                                          '',
                                        ),
                                      );

                                if (minController.text.trim().isNotEmpty &&
                                    min == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter a valid minimum budget.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (maxController.text.trim().isNotEmpty &&
                                    max == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter a valid maximum budget.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (min != null && max != null && min > max) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Minimum budget cannot exceed maximum budget.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setState(() {
                                  _selectedTypes
                                    ..clear()
                                    ..addAll(temporaryTypes);
                                  _selectedBhk = temporaryBhk;
                                  _selectedDocumentStatus =
                                      temporaryDocumentStatus;
                                  _selectedListingStatus =
                                      temporaryListingStatus;
                                  _minBudget = min;
                                  _maxBudget = max;
                                  _locationFilter = locationController.text
                                      .trim();
                                });

                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Apply Filters'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    minController.dispose();
    maxController.dispose();
    locationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allProperties = appState.properties;
    final properties = _filteredProperties;

    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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

                // Quick property-type filters
                SizedBox(
                  height: 43,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: const Text('All types'),
                          selected: _selectedTypes.isEmpty,
                          onSelected: (_) {
                            setState(() => _selectedTypes.clear());
                          },
                          selectedColor: const Color(0xFFE5ECFF),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: _selectedTypes.isEmpty
                                ? _primaryColor
                                : Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ..._propertyTypes.map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: _selectedTypes.contains(type),
                            onSelected: (_) => _toggleQuickType(type),
                            selectedColor: const Color(0xFFE5ECFF),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: _selectedTypes.contains(type)
                                  ? _primaryColor
                                  : Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 16, 12),
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
                              _hasActiveFilters ||
                                      _searchController.text.trim().isNotEmpty
                                  ? 'Filtered results from ${allProperties.length} listings'
                                  : 'Your complete property collection',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _actionMenu(),
                      const SizedBox(width: 8),
                      _filterButton(),
                    ],
                  ),
                ),

                if (_hasActiveFilters) _activeFilterSummary(),

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
    );
  }

  Widget _actionMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Sort properties',
        initialValue: _sortBy,
        onSelected: (value) => setState(() => _sortBy = value),
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
                    Text(option, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            )
            .toList(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert_rounded, size: 18, color: _primaryColor),
              SizedBox(width: 4),
              Text(
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
    );
  }

  Widget _filterButton() {
    return Material(
      color: _hasActiveFilters ? _primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showFilterDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasActiveFilters
                  ? _primaryColor
                  : const Color(0xFFE3E8F2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 17,
                color: _hasActiveFilters ? Colors.white : _primaryColor,
              ),
              const SizedBox(width: 5),
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _hasActiveFilters ? Colors.white : _primaryColor,
                ),
              ),
              if (_activeFilterCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters ? Colors.white : _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_activeFilterCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _hasActiveFilters ? _primaryColor : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeFilterSummary() {
    final labels = <String>[
      ..._selectedTypes,
      if (_selectedBhk != null) _selectedBhk!,
      if (_minBudget != null) 'Min ${_formatCurrency(_minBudget!)}',
      if (_maxBudget != null) 'Max ${_formatCurrency(_maxBudget!)}',
      if (_locationFilter.isNotEmpty) _locationFilter,
      if (_selectedDocumentStatus != null) _selectedDocumentStatus!,
      if (_selectedListingStatus != null) _selectedListingStatus!,
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...labels.map(
            (label) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Chip(
                label: Text(label, style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFFE8EEFF),
                side: BorderSide.none,
              ),
            ),
          ),
          TextButton(
            onPressed: _resetFilters,
            child: const Text('Clear all', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
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
        ? specifications['bhk'] ?? prop['bhk']
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
              'Try changing your search or filter criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade500, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                _resetFilters();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Clear search and filters'),
            ),
          ],
        ),
      ),
    );
  }
}
