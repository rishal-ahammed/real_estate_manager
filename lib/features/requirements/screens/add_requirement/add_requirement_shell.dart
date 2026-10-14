import 'package:flutter/material.dart';
import '../../../../data/models/requirement_model.dart';
// Add this import at the top of the file:
import '../../providers/requirement_state.dart';
// Add this import at the top so we can talk to Drive:
import '../../../../core/services/storage_service.dart';

class RequirementDraftProvider extends ChangeNotifier {
  Requirement draft = Requirement();
  int currentStep = 0;

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
  const AddRequirementShell({super.key});

  @override
  State<AddRequirementShell> createState() => _AddRequirementShellState();
}

class _AddRequirementShellState extends State<AddRequirementShell> {
  final _draftProvider = RequirementDraftProvider();
  
  final List<String> _stepTitles = [
    'Client Info',
    'Property Specs',
    'Budget & Location',
    'Review'
  ];

  @override
  void initState() {
    super.initState();
    _draftProvider.addListener(_update);
  }

  @override
  void dispose() {
    _draftProvider.removeListener(_update);
    _draftProvider.dispose();
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Requirement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              'Step ${_draftProvider.currentStep + 1} of 4: ${_stepTitles[_draftProvider.currentStep]}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_draftProvider.draft.readinessScore}% Complete',
                style: TextStyle(
                  color: _draftProvider.draft.readinessScore > 50 ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (_draftProvider.currentStep + 1) / 4,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
          
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(),
            ),
          ),
          
          // Bottom Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Row(
              children: [
                if (_draftProvider.currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _draftProvider.previousStep,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Back'),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_draftProvider.currentStep < 3) {
                        _draftProvider.nextStep();
                      } else {
                        // 1. Save locally to UI State (Generates the REQ- ID)
                        requirementState.addRequirement(_draftProvider.draft);
                        
                        // 2. Show a quick loading snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saving to Google Drive...')),
                        );

                        try {
                           // 3. ACTUALLY SAVE TO GOOGLE DRIVE!
                           await storageService.saveRequirement(_draftProvider.draft);
                           
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Saved Successfully!'), backgroundColor: Colors.green),
                           );
                           
                           // 4. Close the form
                           if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Failed to save to Drive: $e'), backgroundColor: Colors.red),
                           );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_draftProvider.currentStep == 3 ? 'Save Requirement' : 'Continue'),
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
        return const SizedBox();
    }
  }
}

class _Step1ClientInfo extends StatelessWidget {
  final RequirementDraftProvider provider;
  const _Step1ClientInfo({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Client Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.customerName,
          decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person)),
          onChanged: (val) => provider.updateDraft((d) => d.customerName = val),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
          onChanged: (val) => provider.updateDraft((d) => d.phone = val),
        ),
        const SizedBox(height: 24),
        const Text('Purpose', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Buy', label: Text('Buy')),
            ButtonSegment(value: 'Rent', label: Text('Rent')),
            ButtonSegment(value: 'Lease', label: Text('Lease')),
          ],
          selected: {provider.draft.purpose},
          onSelectionChanged: (set) => provider.updateDraft((d) => d.purpose = set.first),
        ),
      ],
    );
  }
}

class _Step2Specs extends StatelessWidget {
  final RequirementDraftProvider provider;
  const _Step2Specs({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: ['Villa', 'Apartment', 'Commercial', 'Land'].map((type) {
            return ChoiceChip(
              label: Text(type),
              selected: provider.draft.propertyType == type,
              onSelected: (val) => provider.updateDraft((d) => d.propertyType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text('Minimum BHK (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Slider(
          value: (provider.draft.bhk ?? 1).toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: provider.draft.bhk?.toString() ?? 'Any',
          onChanged: (val) => provider.updateDraft((d) => d.bhk = val.toInt()),
        ),
      ],
    );
  }
}

class _Step3BudgetLocation extends StatelessWidget {
  final RequirementDraftProvider provider;
  const _Step3BudgetLocation({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preferred Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.location,
          decoration: const InputDecoration(labelText: 'City or Area', prefixIcon: Icon(Icons.location_on)),
          onChanged: (val) => provider.updateDraft((d) => d.location = val),
        ),
        const SizedBox(height: 24),
        const Text('Maximum Budget (₹)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.maxBudget > 0 ? provider.draft.maxBudget.toStringAsFixed(0) : '',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Max Budget', prefixIcon: Icon(Icons.currency_rupee)),
          onChanged: (val) => provider.updateDraft((d) => d.maxBudget = double.tryParse(val) ?? 0),
        ),
      ],
    );
  }
}

class _Step4Review extends StatelessWidget {
  final RequirementDraftProvider provider;
  const _Step4Review({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review Requirement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Customer'),
                  subtitle: Text('${provider.draft.customerName} - ${provider.draft.phone}'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Looking For'),
                  subtitle: Text('${provider.draft.purpose} a ${provider.draft.propertyType} in ${provider.draft.location}'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Budget'),
                  subtitle: Text('Up to ₹${provider.draft.maxBudget}'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}