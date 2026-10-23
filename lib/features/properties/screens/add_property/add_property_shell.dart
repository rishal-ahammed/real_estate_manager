import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../../../../data/models/property_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../providers/app_state.dart';

/// ADD / EDIT PROPERTY WORKFLOW
class PropertyDraftProvider extends ChangeNotifier {
  PropertyDraftProvider({Property? existingProperty})
    : draft = existingProperty == null
          ? Property()
          : Property.fromJson(existingProperty.toJson()) {
    imagePaths = List<String>.from(draft.images);
  }

  Property draft;
  int currentStep = 0;
  bool isSaving = false;
  List<String> imagePaths = [];

  final ImagePicker _picker = ImagePicker();

  bool get isEditing =>
      draft.propertyId != null && draft.propertyId!.isNotEmpty;

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
    if (step >= 0 && step <= 5) {
      currentStep = step;
      notifyListeners();
    }
  }

  Future<void> pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 80);
      if (images.isEmpty) return;

      for (final img in images) {
        if (imagePaths.length >= 5) break;

        final croppedFile = await ImageCropper().cropImage(
          sourcePath: img.path,
          aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 5),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Adjust Image Fit',
              toolbarColor: const Color(0xFF1E3A8A),
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Adjust Image Fit',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) imagePaths.add(croppedFile.path);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error picking and cropping images: $e');
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < imagePaths.length) {
      imagePaths.removeAt(index);
      notifyListeners();
    }
  }

  Future<String?> saveToDrive() async {
    isSaving = true;
    notifyListeners();

    try {
      if (draft.propertyName.trim().isEmpty) {
        return 'Property Name is required.';
      }

      final phoneDigits = draft.contactPhone.replaceAll(RegExp(r'\D'), '');
      if (phoneDigits.isNotEmpty && phoneDigits.length != 10) {
        return 'Mobile number must contain exactly 10 digits.';
      }

      if (draft.propertyId == null || draft.propertyId!.trim().isEmpty) {
        draft.propertyId = 'PROP-${DateTime.now().millisecondsSinceEpoch}';
      }

      draft.propertyName = draft.propertyName.trim();
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
  final Property? propertyToEdit;

  const AddPropertyShell({super.key, this.propertyToEdit});

  @override
  State<AddPropertyShell> createState() => _AddPropertyShellState();
}

class _AddPropertyShellState extends State<AddPropertyShell> {
  late final PropertyDraftProvider _draftProvider;

  @override
  void initState() {
    super.initState();
    _draftProvider = PropertyDraftProvider(
      existingProperty: widget.propertyToEdit,
    );
  }

  @override
  void dispose() {
    _draftProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draftProvider,
      builder: (context, _) {
        final step = _draftProvider.currentStep;
        const stepTitles = [
          'Basic Information',
          'Pricing & Dimensions',
          'Specifications',
          'Photos & Notes',
          'Property Location',
          'Review & Save',
        ];
        const stepSubtitles = [
          'Start with the essential property and contact details.',
          'Enter the asking price and property dimensions.',
          'Add features that help buyers understand the property.',
          'Upload property photos and add useful notes.',
          'Specify where the property is located.',
          'Review the information before saving your property.',
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF172033),
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              tooltip: 'Close',
              onPressed: () => _confirmDiscard(context),
              icon: const Icon(Icons.close_rounded),
            ),
            title: Text(
              _draftProvider.isEditing ? 'Edit Property' : 'Add Property',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            actions: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_draftProvider.draft.readinessScore}% ready',
                    style: TextStyle(
                      color: _draftProvider.draft.readinessScore > 50
                          ? const Color(0xFF15803D)
                          : const Color(0xFF1E3A8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'STEP ${step + 1} OF 6',
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Text(
                          '${((step + 1) / 6 * 100).round()}% complete',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: (step + 1) / 6,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE9ECF3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      stepTitles[step],
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stepSubtitles[step],
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
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
    final step = _draftProvider.currentStep;
    final isLastStep = step == 5;
    const primary = Color(0xFF1E3A8A);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE9ECF3))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (step > 0)
              OutlinedButton.icon(
                onPressed: _draftProvider.isSaving
                    ? null
                    : _draftProvider.previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: const BorderSide(color: Color(0xFFE9ECF3)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              )
            else
              const SizedBox(width: 4),
            const Spacer(),
            if (!isLastStep)
              FilledButton.icon(
                onPressed: () {
                  if (step == 0 &&
                      _draftProvider.draft.propertyName.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Property Name is required'),
                      ),
                    );
                    return;
                  }
                  _draftProvider.nextStep();
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Continue'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _draftProvider.isSaving
                    ? null
                    : () async {
                        final wasEditing = _draftProvider.isEditing;
                        final errorMsg = await _draftProvider.saveToDrive();
                        if (!mounted) return;

                        if (errorMsg == null) {
                          Navigator.pop(context, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                wasEditing
                                    ? 'Property Updated Successfully'
                                    : 'Property Saved Successfully',
                              ),
                              backgroundColor: const Color(0xFF15803D),
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
                      },
                icon: _draftProvider.isSaving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _draftProvider.isEditing
                            ? Icons.check_rounded
                            : Icons.save_outlined,
                        size: 19,
                      ),
                label: Text(
                  _draftProvider.isSaving
                      ? 'Saving...'
                      : _draftProvider.isEditing
                      ? 'Update Property'
                      : 'Save Property',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDiscard(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: Text(
          _draftProvider.isEditing
              ? 'Your unsaved changes will be lost.'
              : 'Your unsaved draft will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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
    const propertyTypes = [
      'Vacant Land',
      'Building',
      'Apartment',
      'Commercial',
      'Villa',
      'Agri Land',
    ];
    const contactTypes = ['Owner', 'Broker', 'Agent', 'Other'];
    const documentStatuses = ['Available', 'In Bank / Pledged / Mortgaged'];

    final propertyType = propertyTypes.contains(provider.draft.propertyType)
        ? provider.draft.propertyType
        : 'Villa';
    final contactType = contactTypes.contains(provider.draft.contactType)
        ? provider.draft.contactType
        : 'Owner';
    final documentStatus =
        documentStatuses.contains(provider.draft.documentStatus)
        ? provider.draft.documentStatus
        : 'Available';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FormSectionCard(
          title: 'Property Information',
          subtitle: 'Give this listing a clear name and category.',
          icon: Icons.home_work_outlined,
          children: [
            TextFormField(
              key: ValueKey(
                'property_name_${provider.draft.propertyId ?? 'new'}',
              ),
              initialValue: provider.draft.propertyName,
              decoration: const InputDecoration(
                labelText: 'Property Name *',
                hintText: 'e.g. 3 BHK Modern Villa',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              onChanged: (val) =>
                  provider.updateDraft((d) => d.propertyName = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: propertyType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Property Type *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: propertyTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  provider.updateDraft((d) => d.propertyType = val);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FormSectionCard(
          title: 'Contact Information',
          subtitle: 'Add the owner, broker, or agent details.',
          icon: Icons.person_outline,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: contactType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: contactTypes
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        provider.updateDraft((d) => d.contactType = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: provider.draft.contactName,
                    decoration: const InputDecoration(
                      labelText: 'Contact Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    onChanged: (val) =>
                        provider.updateDraft((d) => d.contactName = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: provider.draft.contactPhone.replaceAll(
                RegExp(r'\D'),
                '',
              ),
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Enter 10-digit mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
                prefixText: '+91 ',
                helperText: 'Enter exactly 10 digits',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                final digits = (value ?? '').trim();
                if (digits.isNotEmpty && digits.length != 10) {
                  return 'Enter exactly 10 digits';
                }
                return null;
              },
              onChanged: (val) =>
                  provider.updateDraft((d) => d.contactPhone = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: documentStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Document Status',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              items: documentStatuses
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  provider.updateDraft((d) => d.documentStatus = val);
                }
              },
            ),
          ],
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
      padding: const EdgeInsets.all(20),
      children: [
        _FormSectionCard(
          title: 'Asking Price',
          subtitle: 'Enter the total expected selling price.',
          icon: Icons.currency_rupee,
          children: [
            TextFormField(
              initialValue: provider.draft.budget > 0
                  ? provider.draft.budget.toStringAsFixed(0)
                  : '',
              decoration: const InputDecoration(
                labelText: 'Total Budget (₹) *',
                prefixIcon: Icon(Icons.currency_rupee),
                hintText: 'Enter amount',
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => provider.updateDraft(
                (d) => d.budget = double.tryParse(val) ?? 0.0,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text(
                'Price is Negotiable',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Allow room for price discussion'),
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF1E3A8A),
              value: provider.draft.isNegotiable,
              onChanged: (val) =>
                  provider.updateDraft((d) => d.isNegotiable = val),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FormSectionCard(
          title: 'Dimensions',
          subtitle: 'Add the available land and building area.',
          icon: Icons.square_foot,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: provider.draft.landArea?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Land Area',
                      suffixText: 'Cent',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (val) => provider.updateDraft(
                      (d) => d.landArea = double.tryParse(val),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: provider.draft.builtUpArea?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Built-up Area',
                      suffixText: 'Sq.ft',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (val) => provider.updateDraft(
                      (d) => d.builtUpArea = double.tryParse(val),
                    ),
                  ),
                ),
              ],
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
    const furnishingOptions = [
      'Fully Furnished',
      'Semi-Furnished',
      'Unfurnished',
    ];
    const facingOptions = ['East', 'West', 'North', 'South'];

    final furnishedStatus =
        furnishingOptions.contains(provider.draft.furnishedStatus)
        ? provider.draft.furnishedStatus
        : 'Unfurnished';
    final facing = facingOptions.contains(provider.draft.facing)
        ? provider.draft.facing
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FormSectionCard(
          title: 'Detailed Specifications',
          subtitle: 'Add the features relevant to this property.',
          icon: Icons.tune,
          children: [
            if (!isLand) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: provider.draft.bhk?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Bedrooms (BHK)',
                        prefixIcon: Icon(Icons.bedroom_parent_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => provider.updateDraft(
                        (d) => d.bhk = int.tryParse(val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: provider.draft.floors?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Floors',
                        prefixIcon: Icon(Icons.stairs_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => provider.updateDraft(
                        (d) => d.floors = int.tryParse(val),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: furnishedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Furnished Status',
                  prefixIcon: Icon(Icons.weekend_outlined),
                ),
                items: furnishingOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    provider.updateDraft((d) => d.furnishedStatus = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: provider.draft.builtYear?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Built Year',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => provider.updateDraft(
                  (d) => d.builtYear = int.tryParse(val),
                ),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: facing,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Facing Direction',
                prefixIcon: Icon(Icons.explore_outlined),
              ),
              items: facingOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => provider.updateDraft((d) => d.facing = val),
            ),
          ],
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
      padding: const EdgeInsets.all(20),
      children: [
        _FormSectionCard(
          title: 'Property Photos',
          subtitle: 'Choose up to five images. Each image is cropped to 4:5.',
          icon: Icons.photo_library_outlined,
          children: [
            InkWell(
              onTap: provider.pickImages,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  border: Border.all(
                    color: const Color(0xFFD5DDF1),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 42,
                      color: Color(0xFF1E3A8A),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Tap to select images',
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Maximum 5 photos · Portrait 4:5',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
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
                  final path = provider.imagePaths[index];
                  final imageFile = File(path);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageFile.existsSync()
                            ? Image.file(
                                imageFile,
                                width: 88,
                                height: 110,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 88,
                                height: 110,
                                color: const Color(0xFFE9ECF3),
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Material(
                          color: Colors.red,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => provider.removeImage(index),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _FormSectionCard(
          title: 'Listing Notes',
          subtitle: 'Highlight useful details and nearby landmarks.',
          icon: Icons.notes_outlined,
          children: [
            TextFormField(
              initialValue: provider.draft.manualNotes,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Enter specific details, nearby landmarks, or highlights...',
                alignLabelWithHint: true,
              ),
              onChanged: (val) =>
                  provider.updateDraft((d) => d.manualNotes = val),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                provider.updateDraft(
                  (d) => d.aiGeneratedNotes =
                      'A beautiful ${d.bhk ?? ''} BHK '
                      '${d.propertyType} located in ${d.city}. '
                      'Features include ${d.facing ?? 'unspecified'} '
                      'facing orientation. Priced at ₹${d.budget}.',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notes generated from provided details.'),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Notes from Details'),
            ),
            if (provider.draft.aiGeneratedNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF5E4B5)),
                ),
                child: Text(
                  provider.draft.aiGeneratedNotes,
                  style: const TextStyle(
                    color: Color(0xFF6B5420),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class Step5Location extends StatefulWidget {
  final PropertyDraftProvider provider;

  const Step5Location({super.key, required this.provider});

  @override
  State<Step5Location> createState() => _Step5LocationState();
}

class _Step5LocationState extends State<Step5Location> {
  bool _isFetchingLocation = false;

  // geocoding 5.0.0 requires an instance of Geocoding.
  final geocoding.Geocoding _geocoding = geocoding.Geocoding();

  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _areaController;
  late final TextEditingController _pincodeController;

  @override
  void initState() {
    super.initState();

    _stateController = TextEditingController(text: widget.provider.draft.state);
    _cityController = TextEditingController(text: widget.provider.draft.city);
    _areaController = TextEditingController(text: widget.provider.draft.area);
    _pincodeController = TextEditingController(
      text: widget.provider.draft.pincode,
    );
  }

  @override
  void dispose() {
    _stateController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return;

    setState(() => _isFetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location is turned off. Please enable GPS and try again.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Please allow location access.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // Correct API for geocoding 5.0.0.
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception(
          'No address was found for your current GPS location. Please enter it manually.',
        );
      }

      final place = placemarks.first;

      final stateName = (place.administrativeArea ?? '').trim();

      final subDistrict = (place.subAdministrativeArea ?? '').trim();

      final locality = (place.locality ?? '').trim();

      final subLocality = (place.subLocality ?? '').trim();

      final cityName = subDistrict.isNotEmpty
          ? subDistrict
          : locality.isNotEmpty
          ? locality
          : subLocality;

      final areaName =
          <String>[
                place.subLocality ?? '',
                place.thoroughfare ?? '',
                place.name ?? '',
              ]
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .join(', ');

      final postalCode = (place.postalCode ?? '').trim();

      widget.provider.updateDraft((draft) {
        if (stateName.isNotEmpty) {
          draft.state = stateName;
        }
        if (cityName.isNotEmpty) {
          draft.city = cityName;
        }
        if (areaName.isNotEmpty) {
          draft.area = areaName;
        }
        if (postalCode.isNotEmpty) {
          draft.pincode = postalCode;
        }
      });

      _stateController.text = widget.provider.draft.state;
      _cityController.text = widget.provider.draft.city;
      _areaController.text = widget.provider.draft.area;
      _pincodeController.text = widget.provider.draft.pincode;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS location fetched. Please verify the address.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FormSectionCard(
          title: 'Property Location',
          subtitle:
              'Use your device GPS to fill the address, then verify it below.',
          icon: Icons.location_on_outlined,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: Text(
                  _isFetchingLocation
                      ? 'Fetching current location…'
                      : 'Use Current GPS Location',
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'GPS detects this device’s location, which may differ from the property location. Verify the details or enter the property address manually.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR ENTER MANUALLY',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            TextFormField(
              controller: _stateController,
              decoration: const InputDecoration(
                labelText: 'State',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              onChanged: (value) =>
                  provider.updateDraft((d) => d.state = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City / District',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              onChanged: (value) => provider.updateDraft((d) => d.city = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Area / Locality',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              onChanged: (value) => provider.updateDraft((d) => d.area = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pincodeController,
              decoration: const InputDecoration(
                labelText: 'PIN Code',
                prefixIcon: Icon(Icons.markunread_mailbox_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (value) =>
                  provider.updateDraft((d) => d.pincode = value),
            ),
          ],
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
      padding: const EdgeInsets.all(20),
      children: [
        _FormSectionCard(
          title: provider.isEditing ? 'Review & Update' : 'Review & Save',
          subtitle: 'Check the details below. Tap Edit to make changes.',
          icon: Icons.fact_check_outlined,
          children: [
            _reviewSection(context, 'Basic Information', 0, {
              'Name': d.propertyName,
              'Type': d.propertyType,
              'Contact': '${d.contactName} (${d.contactType})',
              'Phone': d.contactPhone,
              'Document Status': d.documentStatus,
            }),
            _reviewSection(context, 'Pricing & Dimensions', 1, {
              'Budget': '₹${d.budget}',
              'Negotiable': d.isNegotiable ? 'Yes' : 'No',
              'Land Area': d.landArea == null ? '' : '${d.landArea} Cent',
              'Built-up Area': d.builtUpArea == null
                  ? ''
                  : '${d.builtUpArea} Sq.ft',
            }),
            _reviewSection(context, 'Specifications', 2, {
              'Bedrooms': d.bhk?.toString() ?? '',
              'Floors': d.floors?.toString() ?? '',
              'Furnished': d.furnishedStatus ?? '',
              'Built Year': d.builtYear?.toString() ?? '',
              'Facing': d.facing ?? '',
            }),
            _reviewSection(context, 'Media & Notes', 3, {
              'Images': '${provider.imagePaths.length} selected',
              'Notes': d.manualNotes,
              'AI Notes': d.aiGeneratedNotes,
            }),
            _reviewSection(context, 'Location', 4, {
              'Address': [
                d.area,
                d.city,
                d.state,
                d.pincode,
              ].where((v) => v.trim().isNotEmpty).join(', '),
            }),
          ],
        ),
      ],
    );
  }

  Widget _reviewSection(
    BuildContext context,
    String title,
    int stepIndex,
    Map<String, String> data,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => provider.setStep(stepIndex),
                child: const Text('Edit'),
              ),
            ],
          ),
          const Divider(height: 12),
          ...data.entries.map((entry) {
            final value = entry.value;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value.trim().isEmpty ? 'Not provided' : value,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _FormSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF1E3A8A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}
