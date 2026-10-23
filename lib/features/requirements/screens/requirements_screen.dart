import 'package:flutter/material.dart';

import 'package:real_estate_manager/features/properties/providers/app_state.dart';

import 'add_requirement/add_requirement_shell.dart';

import 'requirement_detail_screen.dart';

class RequirementsScreen extends StatefulWidget {
  const RequirementsScreen({super.key});

  @override
  State<RequirementsScreen> createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends State<RequirementsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  String _selectedStatus = 'All';

  static const Color _primary = Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();

    appState.addListener(_update);

    appState.loadRequirements();
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

  List<Map<String, dynamic>> get _allRequirements {
    return appState.requirements
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _value(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    return value.toString().trim();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _normalise(String value) {
    return value.trim().toLowerCase().replaceAll('_', ' ');
  }

  String _displayStatus(dynamic rawStatus) {
    switch (_normalise(_value(rawStatus, 'Active'))) {
      case 'active':
      case 'waiting':
        return 'Waiting';

      case 'matched':
      case 'completed':
      case 'property found':
        return 'Property Found';

      case 'cancelled':
      case 'closed':
        return 'Cancelled';

      default:
        return 'Waiting';
    }
  }

  List<Map<String, dynamic>> get _visibleRequirements {
    final query = _searchQuery.trim().toLowerCase();

    return _allRequirements.where((req) {
      final name = _value(req['customerName']);

      final phone = _value(req['phone']);

      final location = _value(req['location']);

      final type = _value(req['propertyType']);

      final purpose = _value(req['purpose']);

      final status = _displayStatus(req['status']);

      final matchesSearch =
          query.isEmpty ||
          [
            name,

            phone,

            location,

            type,

            purpose,
          ].any((value) => value.toLowerCase().contains(query));

      final matchesStatus =
          _selectedStatus == 'All' || status == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(amount % 10000000 == 0 ? 0 : 2)} Cr';
    }

    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(amount % 100000 == 0 ? 0 : 2)} L';
    }

    if (amount <= 0) return 'Budget not specified';

    return '₹${amount.toStringAsFixed(0)}';
  }

  Future<void> _openAddRequirement() async {
    final result = await Navigator.push<bool>(
      context,

      MaterialPageRoute(builder: (_) => const AddRequirementShell()),
    );

    if (!mounted) return;

    if (result == true) {
      await appState.loadRequirements();
    }
  }

  Future<void> _openRequirementDetail(Map<String, dynamic> requirement) async {
    final result = await Navigator.push<bool>(
      context,

      MaterialPageRoute(
        builder: (_) => RequirementDetailScreen(requirement: requirement),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await appState.loadRequirements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRequirements = _allRequirements;

    final requirements = _visibleRequirements;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Requirements',
              style: TextStyle(
                color: Color(0xFF172554),
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              'Keep track of what your clients need',
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
                onTap: _openAddRequirement,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4E9F3)),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: _primary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: appState.isLoadingRequirements
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                _buildSearchBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${requirements.length} ${requirements.length == 1 ? 'requirement' : 'requirements'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF172554),
                              ),
                            ),
                            Text(
                              _searchQuery.trim().isEmpty
                                  ? 'Your client requirement list'
                                  : 'Search results',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${allRequirements.length} total',
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildStatusTabs(),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => appState.loadRequirements(),

                    child: requirements.isEmpty
                        ? _buildEmptyState(allRequirements.isEmpty)
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),

                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),

                            itemCount: requirements.length,

                            itemBuilder: (context, index) {
                              return _buildRequirementCard(requirements[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE7EBF3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF233B70).withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search by client, phone, location or property type',
            hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _primary),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildStatusTabs() {
    const statuses = ['All', 'Waiting', 'Property Found'];

    return Container(
      color: Colors.white,

      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),

      child: Row(
        children: statuses.map((status) {
          final selected = _selectedStatus == status;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),

              child: InkWell(
                borderRadius: BorderRadius.circular(10),

                onTap: () {
                  setState(() => _selectedStatus = status);
                },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),

                  padding: const EdgeInsets.symmetric(
                    vertical: 11,

                    horizontal: 5,
                  ),

                  decoration: BoxDecoration(
                    color: selected ? _primary : const Color(0xFFF3F4F8),

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: Center(
                    child: Text(
                      status,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight: FontWeight.w600,

                        color: selected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequirementCard(Map<String, dynamic> req) {
    final name = _value(req['customerName'], 'Unnamed Client');

    final phone = _value(req['phone']);

    final location = _value(req['location'], 'Location not specified');

    final type = _value(req['propertyType'], 'Property');

    final purpose = _value(req['purpose']);

    final bhk = _value(req['bhk']);

    final status = _displayStatus(req['status']);

    final minBudget = _number(req['minBudget']);

    final maxBudget = _number(req['maxBudget']);

    String budgetText;

    if (minBudget > 0 && maxBudget > 0 && minBudget != maxBudget) {
      budgetText =
          '${_formatCurrency(minBudget)} – ${_formatCurrency(maxBudget)}';
    } else if (maxBudget > 0) {
      budgetText = 'Up to ${_formatCurrency(maxBudget)}';
    } else if (minBudget > 0) {
      budgetText = 'From ${_formatCurrency(minBudget)}';
    } else {
      budgetText = 'Budget not specified';
    }

    final isFound = status == 'Property Found';

    final isCancelled = status == 'Cancelled';

    final statusColor = isFound
        ? const Color(0xFF16794B)
        : isCancelled
        ? Colors.grey.shade700
        : const Color(0xFF9A6700);

    final statusBackground = isFound
        ? const Color(0xFFE6F6ED)
        : isCancelled
        ? const Color(0xFFF0F1F4)
        : const Color(0xFFFFF4D6);

    final propertyLabel = bhk.isNotEmpty ? '$bhk BHK $type' : type;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),

      color: Colors.white,

      elevation: 0,

      clipBehavior: Clip.antiAlias,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),

        side: const BorderSide(color: Color(0xFFE9ECF3)),
      ),

      child: InkWell(
        onTap: () => _openRequirementDetail(req),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,

                    backgroundColor: const Color(0xFFE8EEFF),

                    child: Text(
                      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),

                      style: const TextStyle(
                        color: _primary,

                        fontWeight: FontWeight.w700,

                        fontSize: 17,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 16,

                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 4),

                          Text(
                            phone,

                            style: TextStyle(
                              fontSize: 13,

                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,

                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: statusBackground,

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Text(
                      status,

                      style: TextStyle(
                        fontSize: 11,

                        fontWeight: FontWeight.w700,

                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.home_work_outlined,

                          size: 17,

                          color: _primary,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            propertyLabel,

                            style: const TextStyle(
                              fontWeight: FontWeight.w600,

                              fontSize: 13,
                            ),
                          ),
                        ),

                        if (purpose.isNotEmpty)
                          Text(
                            purpose,

                            style: TextStyle(
                              fontSize: 12,

                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Icon(
                          Icons.location_on_outlined,

                          size: 17,

                          color: Colors.grey.shade600,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            location,

                            style: TextStyle(
                              fontSize: 13,

                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,

                          size: 17,

                          color: Colors.grey.shade600,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            budgetText,

                            style: const TextStyle(
                              fontSize: 13,

                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Text(
                    'View client details',

                    style: TextStyle(
                      color: _primary,

                      fontWeight: FontWeight.w600,

                      fontSize: 12,
                    ),
                  ),

                  const Spacer(),

                  const Icon(
                    Icons.arrow_forward_ios_rounded,

                    size: 14,

                    color: _primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noRequirementsAtAll) {
    final title = noRequirementsAtAll
        ? 'No client needs recorded yet'
        : 'No matching requirements';

    final subtitle = noRequirementsAtAll
        ? 'Save what a client is looking for, and check it when a suitable property becomes available.'
        : 'Try another status or search for a different client.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(30, 70, 30, 120),

      children: [
        Container(
          height: 84,

          width: 84,

          alignment: Alignment.center,

          decoration: BoxDecoration(
            color: const Color(0xFFE8EEFF),

            borderRadius: BorderRadius.circular(26),
          ),

          child: const Icon(Icons.note_add_outlined, size: 39, color: _primary),
        ),

        const SizedBox(height: 22),

        Text(
          title,

          textAlign: TextAlign.center,

          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 9),

        Text(
          subtitle,

          textAlign: TextAlign.center,

          style: TextStyle(
            height: 1.5,

            fontSize: 13,

            color: Colors.grey.shade600,
          ),
        ),

        if (!noRequirementsAtAll) ...[
          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = 'All';

                  _searchQuery = '';

                  _searchController.clear();
                });
              },

              child: const Text('Show all requirements'),
            ),
          ),
        ],
      ],
    );
  }
}
