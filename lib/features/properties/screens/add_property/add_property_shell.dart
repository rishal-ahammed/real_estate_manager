import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // NEW: Added cropper package
import '../../../../data/models/property_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../providers/app_state.dart';

//// ============================================================================
// ADD PROPERTY WORKFLOW (lib/features/properties/screens/add_property/)
// ============================================================================

class PropertyDraftProvider extends ChangeNotifier {
  Property draft = Property();
  int currentStep = 0;
  bool isSaving = false;

  List<String> imagePaths = [];
  final ImagePicker _picker = ImagePicker();

  void updateDraft(void Function(Property) update) {
    update(draft);
    notifyListeners();
  }

  void nextStep() {
    if (currentStep < 5) {
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

  void setStep(int step) {
    currentStep = step;
    notifyListeners();
  }

  // UPDATED: Image Picking Logic with Cropper (Fitment Assist)
  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);

      if (images.isNotEmpty) {
        for (var img in images) {
          // Open the cropper for each image selected
          CroppedFile? croppedFile = await ImageCropper().cropImage(
            sourcePath: img.path,
            aspectRatio: const CropAspectRatio(
              ratioX: 4,
              ratioY: 5,
            ), // Forces perfect rectangle
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Adjust Image Fit',
                toolbarColor: const Color(0xFF00796B), // Match your theme
                toolbarWidgetColor: Colors.white,
                // initAspectRatio: CropAspectRatioPreset.ratio4x5,
                lockAspectRatio: true, // Prevents free-form cropping
              ),
              IOSUiSettings(
                title: 'Adjust Image Fit',
                aspectRatioLockEnabled: true,
                resetAspectRatioEnabled: false,
              ),
            ],
          );

          if (croppedFile != null) {
            imagePaths.add(croppedFile.path);
          }
        }

        // Restrict to max 5 images
        if (imagePaths.length > 5) {
          imagePaths = imagePaths.sublist(0, 5);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error picking and cropping images: $e');
    }
  }

  void removeImage(int index) {
    imagePaths.removeAt(index);
    notifyListeners();
  }

  Future<String?> saveToDrive() async {
    isSaving = true;
    notifyListeners();

    try {
      if (draft.propertyId == null || draft.propertyId!.isEmpty) {
        draft.propertyId = 'PROP-${DateTime.now().millisecondsSinceEpoch}';
      }

      await storageService.saveProperty(draft, imagePaths: imagePaths);
      await appState.loadProperties();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

class AddPropertyShell extends StatefulWidget {
  const AddPropertyShell({super.key});

  @override
  State<AddPropertyShell> createState() => _AddPropertyShellState();
}

class _AddPropertyShellState extends State<AddPropertyShell> {
  final PropertyDraftProvider _draftProvider = PropertyDraftProvider();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draftProvider,
      builder: (context, _) {
        final step = _draftProvider.currentStep;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add Property'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _confirmDiscard(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${_draftProvider.draft.readinessScore}% Ready',
                    style: TextStyle(
                      color: _draftProvider.draft.readinessScore > 50
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              LinearProgressIndicator(
                value: (step + 1) / 6,
                backgroundColor: Colors.grey.shade200,
              ),
              Expanded(
                child: IndexedStack(
                  index: step,
                  children: [
                    Step1Basic(provider: _draftProvider),
                    Step2Pricing(provider: _draftProvider),
                    Step3Details(provider: _draftProvider),
                    Step4Media(provider: _draftProvider),
                    Step5Location(provider: _draftProvider),
                    Step6Review(provider: _draftProvider),
                  ],
                ),
              ),
              _buildBottomControls(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_draftProvider.currentStep > 0)
              TextButton(
                onPressed: _draftProvider.previousStep,
                child: const Text('Back'),
              )
            else
              const SizedBox.shrink(),

            if (_draftProvider.currentStep < 5)
              FilledButton(
                onPressed: () {
                  if (_draftProvider.currentStep == 0 &&
                      _draftProvider.draft.propertyName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Property Name is required'),
                      ),
                    );
                    return;
                  }
                  _draftProvider.nextStep();
                },
                child: const Text('Continue'),
              )
            else
              FilledButton.icon(
                onPressed: _draftProvider.isSaving
                    ? null
                    : () async {
                        final errorMsg = await _draftProvider.saveToDrive();

                        if (mounted) {
                          if (errorMsg == null) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Property Saved Successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: $errorMsg'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                icon: _draftProvider.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _draftProvider.isSaving ? 'Saving...' : 'Save Property',
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDiscard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: const Text('Unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class Step1Basic extends StatelessWidget {
  final PropertyDraftProvider provider;
  const Step1Basic({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        TextFormField(
          initialValue: provider.draft.propertyName,
          decoration: const InputDecoration(
            labelText: 'Property Name *',
            hintText: 'e.g. 3 BHK Modern Villa',
          ),
          onChanged: (val) => provider.updateDraft((d) => d.propertyName = val),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: provider.draft.propertyType,
          decoration: const InputDecoration(labelText: 'Property Type *'),
          items: [
            'Vacant Land',
            'Building',
            'Apartment',
            'Commercial',
            'Villa',
            'Agri Land',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) =>
              provider.updateDraft((d) => d.propertyType = val!),
        ),
        const SizedBox(height: 24),
        const Text(
          'Contact Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                value: provider.draft.contactType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['Owner', 'Broker', 'Agent', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) =>
                    provider.updateDraft((d) => d.contactType = val!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: provider.draft.contactName,
                decoration: const InputDecoration(labelText: 'Contact Name'),
                onChanged: (val) =>
                    provider.updateDraft((d) => d.contactName = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.contactPhone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixText: '+91 ',
          ),
          keyboardType: TextInputType.phone,
          onChanged: (val) => provider.updateDraft((d) => d.contactPhone = val),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: provider.draft.documentStatus,
          decoration: const InputDecoration(labelText: 'Document Status'),
          items: [
            'Available',
            'In Bank / Pledged / Mortgaged',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) =>
              provider.updateDraft((d) => d.documentStatus = val!),
        ),
      ],
    );
  }
}

class Step2Pricing extends StatelessWidget {
  final PropertyDraftProvider provider;
  const Step2Pricing({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Pricing & Dimension',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        TextFormField(
          initialValue: provider.draft.budget > 0
              ? provider.draft.budget.toStringAsFixed(0)
              : '',
          decoration: const InputDecoration(
            labelText: 'Total Budget (₹) *',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
          keyboardType: TextInputType.number,
          onChanged: (val) => provider.updateDraft(
            (d) => d.budget = double.tryParse(val) ?? 0.0,
          ),
        ),
        SwitchListTile(
          title: const Text('Price is Negotiable'),
          contentPadding: EdgeInsets.zero,
          value: provider.draft.isNegotiable,
          onChanged: (val) => provider.updateDraft((d) => d.isNegotiable = val),
        ),
        const Divider(height: 48),
        const Text(
          'Dimensions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: provider.draft.landArea?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Land Area',
                  suffixText: 'Cent',
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => provider.updateDraft(
                  (d) => d.landArea = double.tryParse(val),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: provider.draft.builtUpArea?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Built-up Area',
                  suffixText: 'Sq.ft',
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => provider.updateDraft(
                  (d) => d.builtUpArea = double.tryParse(val),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class Step3Details extends StatelessWidget {
  final PropertyDraftProvider provider;
  const Step3Details({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isLand =
        provider.draft.propertyType == 'Vacant Land' ||
        provider.draft.propertyType == 'Agri Land';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Detailed Specifications',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        if (!isLand) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: provider.draft.bhk?.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Bedrooms (BHK)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) =>
                      provider.updateDraft((d) => d.bhk = int.tryParse(val)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: provider.draft.floors?.toString(),
                  decoration: const InputDecoration(labelText: 'Floors'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) =>
                      provider.updateDraft((d) => d.floors = int.tryParse(val)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: provider.draft.furnishedStatus,
            decoration: const InputDecoration(labelText: 'Furnished Status'),
            items: [
              'Fully Furnished',
              'Semi-Furnished',
              'Unfurnished',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) =>
                provider.updateDraft((d) => d.furnishedStatus = val!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: provider.draft.builtYear?.toString(),
            decoration: const InputDecoration(labelText: 'Built Year'),
            keyboardType: TextInputType.number,
            onChanged: (val) =>
                provider.updateDraft((d) => d.builtYear = int.tryParse(val)),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'Structure & Access',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: provider.draft.facing,
          decoration: const InputDecoration(labelText: 'Facing Direction'),
          items: [
            'East',
            'West',
            'North',
            'South',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => provider.updateDraft((d) => d.facing = val!),
        ),
      ],
    );
  }
}

class Step4Media extends StatelessWidget {
  final PropertyDraftProvider provider;
  const Step4Media({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Media & Notes',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        GestureDetector(
          onTap: provider.pickImages,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_a_photo, size: 48, color: Colors.indigo),
                const SizedBox(height: 8),
                const Text('Tap to select images (Max 5)'),
                Text(
                  'Images will be cropped to a perfect 16:9 ratio',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),

        if (provider.imagePaths.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(provider.imagePaths.length, (index) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(provider.imagePaths[index]),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: GestureDetector(
                      onTap: () => provider.removeImage(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],

        const SizedBox(height: 32),
        const Text(
          'Listing Notes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: provider.draft.manualNotes,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Enter specific details, nearby landmarks, or highlights...',
          ),
          onChanged: (val) => provider.updateDraft((d) => d.manualNotes = val),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            provider.updateDraft(
              (d) => d.aiGeneratedNotes =
                  "A beautiful ${d.bhk ?? ''} BHK ${d.propertyType} located in ${d.city}. Features include ${d.facing} facing orientation. Priced at ₹${d.budget}.",
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI Notes Generated from provided specs!'),
              ),
            );
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate Notes with AI'),
        ),
        if (provider.draft.aiGeneratedNotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              provider.draft.aiGeneratedNotes,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }
}

class Step5Location extends StatelessWidget {
  final PropertyDraftProvider provider;
  const Step5Location({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Location',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () {
            provider.updateDraft((d) {
              d.state = 'Kerala';
              d.city = 'Malappuram';
              d.area = 'Perinthalmanna';
              d.pincode = '679322';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location fetched via GPS')),
            );
          },
          icon: const Icon(Icons.my_location),
          label: const Text('Use Current GPS Location'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR MANUAL ENTRY'),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        TextFormField(
          initialValue: provider.draft.state,
          decoration: const InputDecoration(labelText: 'State'),
          onChanged: (val) => provider.updateDraft((d) => d.state = val),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.city,
          decoration: const InputDecoration(labelText: 'City'),
          onChanged: (val) => provider.updateDraft((d) => d.city = val),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.area,
          decoration: const InputDecoration(labelText: 'Area / Locality'),
          onChanged: (val) => provider.updateDraft((d) => d.area = val),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: provider.draft.pincode,
          decoration: const InputDecoration(labelText: 'Pincode'),
          keyboardType: TextInputType.number,
          onChanged: (val) => provider.updateDraft((d) => d.pincode = val),
        ),
      ],
    );
  }
}

class Step6Review extends StatelessWidget {
  final PropertyDraftProvider provider;
  const Step6Review({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final d = provider.draft;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Review & Save',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildSection(context, 'Basic Information', 0, {
          'Name': d.propertyName,
          'Type': d.propertyType,
          'Contact': '${d.contactName} (${d.contactType})',
          'Status': d.documentStatus,
        }),
        _buildSection(context, 'Pricing', 1, {
          'Budget': '₹${d.budget}',
          'Negotiable': d.isNegotiable ? 'Yes' : 'No',
        }),
        _buildSection(context, 'Location', 4, {
          'Address': '${d.area}, ${d.city}, ${d.state}\n${d.pincode}',
        }),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    int stepIndex,
    Map<String, String> data,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => provider.setStep(stepIndex),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const Divider(),
            ...data.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        e.key,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value.isEmpty ? 'Not provided' : e.value,
                        style: const TextStyle(fontWeight: FontWeight.w500),
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
  }
}
