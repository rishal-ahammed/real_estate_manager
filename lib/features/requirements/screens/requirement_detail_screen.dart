import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../properties/providers/app_state.dart';
import 'add_requirement/add_requirement_shell.dart';

class RequirementDetailScreen extends StatefulWidget {
  final dynamic requirement;

  const RequirementDetailScreen({super.key, required this.requirement});

  @override
  State<RequirementDetailScreen> createState() =>
      _RequirementDetailScreenState();
}

class _RequirementDetailScreenState extends State<RequirementDetailScreen> {
  bool _isWorking = false;
  Map<String, dynamic>? _updatedRequirement;

  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _background = Color(0xFFF7F8FC);
  static const Color _border = Color(0xFFE9ECF3);
  static const Color _textColor = Color(0xFF172033);
  static const Color _secondaryText = Color(0xFF6B7280);

  static const List<String> _statuses = ['Waiting', 'Property Found'];

  Map<String, dynamic> get _req {
    if (_updatedRequirement != null) return _updatedRequirement!;
    return widget.requirement is Map
        ? Map<String, dynamic>.from(widget.requirement as Map)
        : <String, dynamic>{};
  }

  String _text(String key, [String fallback = 'N/A']) {
    final value = _req[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  double _number(String key) {
    final value = _req[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    }
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} Lakhs';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Waiting':
        return const Color(0xFFD97706); // Amber
      case 'Property Found':
        return const Color(0xFF15803D); // Green
      default:
        return _secondaryText;
    }
  }

  Future<void> _callClient(String phone) async {
    final cleanedPhone = phone.trim();
    if (cleanedPhone.isEmpty || cleanedPhone == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No client phone number is available.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleanedPhone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the phone app.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone app.')),
      );
    }
  }

  Future<void> _editRequirement() async {
    final currentRequirement = Map<String, dynamic>.from(_req);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddRequirementShell(existingRequirement: currentRequirement),
      ),
    );

    if (result != true || !mounted) return;

    final id = currentRequirement['requirementId']?.toString() ?? '';
    final updated = appState.requirements.where(
      (item) => item is Map && item['requirementId']?.toString() == id,
    );

    if (updated.isNotEmpty) {
      setState(() {
        _updatedRequirement = Map<String, dynamic>.from(updated.first as Map);
      });
    } else {
      await appState.loadRequirements();
      if (!mounted) return;
      final refreshed = appState.requirements.where(
        (item) => item is Map && item['requirementId']?.toString() == id,
      );
      if (refreshed.isNotEmpty) {
        setState(() {
          _updatedRequirement = Map<String, dynamic>.from(
            refreshed.first as Map,
          );
        });
      }
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);

    try {
      await appState.updateRequirementStatus(
        _text('requirementId', ''),
        status,
      );

      if (!mounted) return;
      setState(() {
        _updatedRequirement = {..._req, 'status': status};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status changed to $status'),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update status: $e')));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _deleteRequirement() async {
    final id = _text('requirementId', '');
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Requirement ID is missing.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Delete requirement?')),
          ],
        ),
        content: Text(
          'Delete the requirement for ${_text('customerName', 'this customer')}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted || _isWorking) return;
    setState(() => _isWorking = true);

    try {
      await appState.deleteRequirement(id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Requirement deleted successfully.'),
          backgroundColor: Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete requirement: $e')),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _req;
    final reqId = req['requirementId']?.toString() ?? 'N/A';
    final maxBudget = _number('maxBudget');
    final customerName = _text('customerName', 'Unknown Customer');
    final phone = _text('phone', '');
    final purpose = _text('purpose', 'Buy');
    final propertyType = _text('propertyType', 'Any');
    final location = _text('location', 'Any Location');
    final bhk = req['bhk']?.toString() ?? '';
    final rawStatus = req['status']?.toString() ?? 'Waiting';
    final status = _statuses.contains(rawStatus) ? rawStatus : 'Waiting';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
        ),
        title: const Text(
          'Requirement Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit requirement',
            icon: const Icon(Icons.edit_outlined, color: _primary),
            onPressed: _isWorking ? null : _editRequirement,
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              if (value == 'delete') _deleteRequirement();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete requirement'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isWorking
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(
                    maxBudget,
                    purpose,
                    bhk,
                    propertyType,
                    status,
                  ),
                  const SizedBox(height: 16),
                  _buildContactCard(customerName, phone),
                  const SizedBox(height: 16),
                  _buildInformationCard(
                    reqId,
                    propertyType,
                    bhk,
                    purpose,
                    location,
                    status,
                  ),
                  const SizedBox(height: 16),
                  _buildStatusCard(status),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _buildHeaderCard(
    double budget,
    String purpose,
    String bhk,
    String propertyType,
    String status,
  ) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'MAXIMUM BUDGET',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 12,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(budget),
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              color: _primary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Looking to $purpose',
            style: const TextStyle(
              color: _textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag(Icons.home_work_outlined, propertyType),
              if (bhk.isNotEmpty)
                _buildTag(Icons.bedroom_parent_outlined, '$bhk BHK'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(String customerName, String phone) {
    final hasPhone = phone.trim().isNotEmpty && phone != 'N/A';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.person_outline,
            title: 'Client Information',
          ),
          const SizedBox(height: 20),
          Text(
            customerName,
            style: const TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: const Color(0xFFF2F5FC),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _callClient(phone),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: _primary, size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasPhone ? phone : 'Phone number not provided',
                        style: TextStyle(
                          color: hasPhone ? _primary : _secondaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call, color: Colors.white, size: 15),
                          SizedBox(width: 5),
                          Text(
                            'Call',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
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

  Widget _buildInformationCard(
    String reqId,
    String type,
    String bhk,
    String purpose,
    String location,
    String status,
  ) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.assignment_outlined,
            title: 'Requirement Details',
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Requirement ID', reqId),
          _buildDivider(),
          _buildInfoRow('Status', status),
          _buildDivider(),
          _buildInfoRow('Purpose', purpose),
          _buildDivider(),
          _buildInfoRow('Property Type', type),
          _buildDivider(),
          _buildInfoRow(
            'Bedrooms',
            bhk.isNotEmpty ? bhk : 'Any',
            suffix: bhk.isNotEmpty ? 'BHK' : null,
          ),
          _buildDivider(),
          _buildInfoRow('Preferred Location', location),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String currentStatus) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.flag_outlined,
            title: 'Update Requirement Status',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: currentStatus,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.flag_outlined, color: _primary),
              filled: true,
              fillColor: const Color(0xFFF9FAFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: _statuses.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: _isWorking
                ? null
                : (value) {
                    if (value != null && value != currentStatus) {
                      _changeStatus(value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.circle, size: 9, color: _statusColor(currentStatus)),
              const SizedBox(width: 8),
              Text(
                'Current status: $currentStatus',
                style: TextStyle(
                  color: _statusColor(currentStatus),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: _secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                text: value,
                style: const TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                children: suffix != null
                    ? [
                        TextSpan(
                          text: ' $suffix',
                          style: const TextStyle(
                            color: _secondaryText,
                            fontWeight: FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 22, thickness: 1, color: _border);
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeading({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF1E3A8A), size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
