import 'package:flutter/material.dart';

import '../../../../data/models/requirement_model.dart';
import '../../../properties/providers/app_state.dart';

const Color _primary = Color(0xFF1E3A8A);
const Color _background = Color(0xFFF7F8FC);
const Color _border = Color(0xFFE9ECF3);
const Color _muted = Color(0xFF6B7280);

class RequirementDraftProvider extends ChangeNotifier {
  Requirement draft;
  int currentStep = 0;

  RequirementDraftProvider({Requirement? initialRequirement})
    : draft = initialRequirement ?? Requirement();

  void updateDraft(void Function(Requirement) update) {
    update(draft);
    notifyListeners();
  }

  void nextStep() {
    if (currentStep < 3) {
      currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }
}

class AddRequirementShell extends StatefulWidget {
  final Map<String, dynamic>? existingRequirement;

  const AddRequirementShell({super.key, this.existingRequirement});

  bool get isEditing => existingRequirement != null;

  @override
  State<AddRequirementShell> createState() => _AddRequirementShellState();
}

class _AddRequirementShellState extends State<AddRequirementShell> {
  late final RequirementDraftProvider _draftProvider;
  bool _isSaving = false;

  final List<String> _stepTitles = [
    'Client Info',
    'Property Specs',
    'Budget & Location',
    'Review',
  ];

  final List<IconData> _stepIcons = [
    Icons.person_outline,
    Icons.home_work_outlined,
    Icons.location_on_outlined,
    Icons.fact_check_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _draftProvider = RequirementDraftProvider(
      initialRequirement: widget.existingRequirement == null
          ? null
          : Requirement.fromJson(widget.existingRequirement!),
    );
    _draftProvider.addListener(_update);
  }

  @override
  void dispose() {
    _draftProvider.removeListener(_update);
    _draftProvider.dispose();
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  Future<void> _saveRequirement() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final draft = _draftProvider.draft;

      if (draft.requirementId.trim().isEmpty) {
        draft.requirementId = 'REQ-${DateTime.now().microsecondsSinceEpoch}';
      }

      await appState.saveRequirement(draft);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Requirement updated successfully!'
                : 'Requirement saved successfully!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving requirement: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _draftProvider.currentStep;
    final draft = _draftProvider.draft;
    final progress = (currentStep + 1) / _stepTitles.length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isSaving ? null : () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEditing ? 'Edit Requirement' : 'Add Requirement',
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Step ${currentStep + 1} of 4',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${draft.readinessScore}% complete',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: _border,
                    valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: List.generate(_stepTitles.length, (index) {
                    final active = index == currentStep;
                    final completed = index < currentStep;

                    return Expanded(
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: active || completed
                                  ? _primary
                                  : _background,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: active || completed ? _primary : _border,
                              ),
                            ),
                            child: Icon(
                              completed
                                  ? Icons.check_rounded
                                  : _stepIcons[index],
                              size: 19,
                              color: active || completed
                                  ? Colors.white
                                  : _muted,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _stepTitles[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active ? _primary : _muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              14 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: _border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _draftProvider.previousStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Text(
                      'Required details',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (currentStep < 3) {
                              _draftProvider.nextStep();
                            } else {
                              _saveRequirement();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentStep == 3
                                    ? (widget.isEditing
                                          ? 'Update Requirement'
                                          : 'Save Requirement')
                                    : 'Continue',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                currentStep == 3
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
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

  Widget _buildCurrentStep() {
    switch (_draftProvider.currentStep) {
      case 0:
        return _Step1ClientInfo(provider: _draftProvider);
      case 1:
        return _Step2Specs(provider: _draftProvider);
      case 2:
        return _Step3BudgetLocation(provider: _draftProvider);
      case 3:
        return _Step4Review(provider: _draftProvider);
      default:
        return const SizedBox.shrink();
    }
  }
}

// -----------------------------------------------------------------------------
// Reusable UI components
// -----------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _primary, size: 22),
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
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final String? hint;

  const _FieldLabel(this.text, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Text(hint!, style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  String? prefixText,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20, color: _muted),
    prefixText: prefixText,
    filled: true,
    fillColor: const Color(0xFFFAFBFE),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
  );
}

// -----------------------------------------------------------------------------
// Step 1: Client information
// -----------------------------------------------------------------------------

class _Step1ClientInfo extends StatelessWidget {
  final RequirementDraftProvider provider;

  const _Step1ClientInfo({required this.provider});

  @override
  Widget build(BuildContext context) {
    final draft = provider.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who are we helping?',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Start with the customer’s contact details.',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 22),
        _SectionCard(
          title: 'Client Information',
          subtitle: 'Contact details for this requirement',
          icon: Icons.person_outline,
          children: [
            const _FieldLabel('Customer Name'),
            TextFormField(
              key: ValueKey('customer_${draft.requirementId}'),
              initialValue: draft.customerName,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hint: 'Enter customer name',
                icon: Icons.badge_outlined,
              ),
              onChanged: (value) =>
                  provider.updateDraft((d) => d.customerName = value),
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Phone Number'),
            TextFormField(
              key: ValueKey('phone_${draft.requirementId}'),
              initialValue: draft.phone,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                hint: 'Enter contact number',
                icon: Icons.phone_outlined,
              ),
              onChanged: (value) =>
                  provider.updateDraft((d) => d.phone = value),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Purpose',
          subtitle: 'What does the customer want to do?',
          icon: Icons.handshake_outlined,
          children: [_PurposeSelector(provider: provider)],
        ),
      ],
    );
  }
}

class _PurposeSelector extends StatelessWidget {
  final RequirementDraftProvider provider;

  const _PurposeSelector({required this.provider});

  @override
  Widget build(BuildContext context) {
    final purposes = [
      ('Buy', Icons.shopping_bag_outlined),
      ('Rent', Icons.key_outlined),
      ('Lease', Icons.assignment_outlined),
    ];

    return Row(
      children: purposes.map((item) {
        final selected = provider.draft.purpose == item.$1;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item.$1 == 'Lease' ? 0 : 9),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                provider.updateDraft((d) => d.purpose = item.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  vertical: 17,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEFF3FF)
                      : const Color(0xFFFAFBFE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? _primary : _border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      item.$2,
                      color: selected ? _primary : _muted,
                      size: 23,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.$1,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? _primary : const Color(0xFF374151),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// -----------------------------------------------------------------------------
// Step 2: Property specifications
// -----------------------------------------------------------------------------

class _Step2Specs extends StatelessWidget {
  final RequirementDraftProvider provider;

  const _Step2Specs({required this.provider});

  @override
  Widget build(BuildContext context) {
    const propertyTypes = [
      ('Villa', Icons.villa_outlined),
      ('Apartment', Icons.apartment_outlined),
      ('Commercial', Icons.storefront_outlined),
      ('Land', Icons.landscape_outlined),
      ('Vacant Land', Icons.terrain_outlined),
      ('Building', Icons.business_outlined),
      ('Agri Land', Icons.grass_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What property is needed?',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Choose the property type and bedroom preference.',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 22),
        _SectionCard(
          title: 'Property Type',
          subtitle: 'Select the preferred property',
          icon: Icons.home_work_outlined,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: propertyTypes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.25,
              ),
              itemBuilder: (context, index) {
                final item = propertyTypes[index];
                final selected = provider.draft.propertyType == item.$1;

                return InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () {
                    provider.updateDraft((d) => d.propertyType = item.$1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEFF3FF)
                          : const Color(0xFFFAFBFE),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: selected ? _primary : _border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.$2,
                          size: 19,
                          color: selected ? _primary : _muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.$1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? _primary
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: _primary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Bedrooms',
          subtitle: 'Choose a minimum BHK preference',
          icon: Icons.bed_outlined,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Minimum BHK',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                Text(
                  provider.draft.bhk == null
                      ? 'Any'
                      : '${provider.draft.bhk} BHK',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: (provider.draft.bhk ?? 1).toDouble().clamp(1, 10),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: _primary,
              inactiveColor: _border,
              label: provider.draft.bhk?.toString() ?? 'Any',
              onChanged: (value) {
                provider.updateDraft((d) => d.bhk = value.toInt());
              },
            ),
            OutlinedButton.icon(
              onPressed: () {
                provider.updateDraft((d) => d.bhk = null);
              },
              icon: Icon(
                provider.draft.bhk == null
                    ? Icons.check_circle
                    : Icons.bed_outlined,
                size: 18,
              ),
              label: const Text('Any number of bedrooms'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _border),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Step 3: Budget and location
// -----------------------------------------------------------------------------

class _Step3BudgetLocation extends StatelessWidget {
  final RequirementDraftProvider provider;

  const _Step3BudgetLocation({required this.provider});

  @override
  Widget build(BuildContext context) {
    final draft = provider.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Budget & Location',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Narrow down the search to a suitable area and budget.',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 22),
        _SectionCard(
          title: 'Preferred Location',
          subtitle: 'Where should the property be?',
          icon: Icons.location_on_outlined,
          children: [
            const _FieldLabel('City or Area'),
            TextFormField(
              key: ValueKey('location_${draft.requirementId}'),
              initialValue: draft.location,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hint: 'e.g. Perinthalmanna, Manjeri',
                icon: Icons.map_outlined,
              ),
              onChanged: (value) =>
                  provider.updateDraft((d) => d.location = value),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Maximum Budget',
          subtitle: 'Set the customer’s spending limit',
          icon: Icons.account_balance_wallet_outlined,
          children: [
            const _FieldLabel('Maximum Budget', hint: 'INR'),
            TextFormField(
              key: ValueKey('budget_${draft.requirementId}'),
              initialValue: draft.maxBudget > 0
                  ? draft.maxBudget.toStringAsFixed(0)
                  : '',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _inputDecoration(
                hint: 'Enter maximum budget',
                icon: Icons.currency_rupee,
                prefixText: '₹ ',
              ),
              onChanged: (value) {
                provider.updateDraft(
                  (d) => d.maxBudget = double.tryParse(value) ?? 0,
                );
              },
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 19, color: _primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      draft.maxBudget > 0
                          ? 'Maximum budget: ${_formatRupees(draft.maxBudget)}'
                          : 'Enter a budget to see the formatted amount.',
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatRupees(double amount) {
  if (amount >= 10000000) {
    return '₹${(amount / 10000000).toStringAsFixed(2)} crore';
  }
  if (amount >= 100000) {
    return '₹${(amount / 100000).toStringAsFixed(2)} lakh';
  }
  return '₹${amount.toStringAsFixed(0)}';
}

// -----------------------------------------------------------------------------
// Step 4: Review and save
// -----------------------------------------------------------------------------

class _Step4Review extends StatelessWidget {
  final RequirementDraftProvider provider;

  const _Step4Review({required this.provider});

  @override
  Widget build(BuildContext context) {
    final draft = provider.draft;
    const statuses = ['Waiting', 'Property Found'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Requirement',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Check the details before saving this requirement.',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.real_estate_agent_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Property Requirement',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.verified_outlined, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '${draft.purpose} ${draft.propertyType}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white70,
                    size: 17,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      draft.location.trim().isEmpty
                          ? 'Location not specified'
                          : draft.location,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white24),
              const SizedBox(height: 15),
              const Text(
                'MAXIMUM BUDGET',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                draft.maxBudget > 0
                    ? _formatRupees(draft.maxBudget)
                    : 'Not specified',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Client Details',
          subtitle: 'Customer contact information',
          icon: Icons.person_outline,
          children: [
            _ReviewRow(
              icon: Icons.person_outline,
              label: 'Customer',
              value: draft.customerName.trim().isEmpty
                  ? 'Not provided'
                  : draft.customerName,
            ),
            const Divider(height: 24, color: _border),
            _ReviewRow(
              icon: Icons.phone_outlined,
              label: 'Phone Number',
              value: draft.phone.trim().isEmpty ? 'Not provided' : draft.phone,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Property Preferences',
          subtitle: 'Requested property specifications',
          icon: Icons.home_work_outlined,
          children: [
            _ReviewRow(
              icon: Icons.home_outlined,
              label: 'Property Type',
              value: draft.propertyType,
            ),
            const Divider(height: 24, color: _border),
            _ReviewRow(
              icon: Icons.bed_outlined,
              label: 'Bedrooms',
              value: draft.bhk == null ? 'Any' : '${draft.bhk} BHK minimum',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Requirement Status',
          subtitle: 'Update this as the search progresses',
          icon: Icons.flag_outlined,
          children: [
            DropdownButtonFormField<String>(
              value: statuses.contains(draft.status) ? draft.status : 'Waiting',
              isExpanded: true,
              decoration: _inputDecoration(
                hint: 'Select status',
                icon: Icons.track_changes_outlined,
              ),
              items: statuses.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  provider.updateDraft((d) => d.status = value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: _muted),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Please verify the customer contact details, budget, and location before saving.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5FA),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _primary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
