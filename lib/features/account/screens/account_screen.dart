import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const Color _primaryColor = Color(0xFF1E3A8A);
  static const Color _backgroundColor = Color(0xFFF7F8FC);
  static const Color _borderColor = Color(0xFFE9ECF3);
  static const Color _textColor = Color(0xFF172033);
  static const Color _secondaryTextColor = Color(0xFF70798B);

  String _name = 'Admin User';
  String _email = 'admin@realestate.com';
  String _phone = '';

  bool _confirmBeforeDelete = true;
  bool _showPropertyIds = true;
  String _defaultSort = 'Newest First';

  bool _isLoading = true;
  bool _isSaving = false;

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.trim().isNotEmpty) {
          final decoded = jsonDecode(contents);
          if (decoded is Map) {
            _name = decoded['name']?.toString() ?? _name;
            _email = decoded['email']?.toString() ?? _email;
            _phone = decoded['phone']?.toString() ?? _phone;
            _confirmBeforeDelete =
                decoded['confirmBeforeDelete'] as bool? ?? true;
            _showPropertyIds = decoded['showPropertyIds'] as bool? ?? true;
            _defaultSort = decoded['defaultSort']?.toString() ?? 'Newest First';
          }
        }
      }
    } catch (error) {
      debugPrint('Unable to load account settings: $error');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final file = await _getSettingsFile();
      final data = <String, dynamic>{
        'name': _name,
        'email': _email,
        'phone': _phone,
        'confirmBeforeDelete': _confirmBeforeDelete,
        'showPropertyIds': _showPropertyIds,
        'defaultSort': _defaultSort,
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
    } catch (error) {
      debugPrint('Unable to save account settings: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save settings. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);
    final phoneController = TextEditingController(text: _phone);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Edit Account Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.isEmpty ||
                            !RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)
                        ? 'Enter a valid email address'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save details'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _name = nameController.text.trim();
        _email = emailController.text.trim();
        _phone = phoneController.text.trim();
      });
      await _saveSettings();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account details saved')));
      }
    }
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  Future<void> _openAppSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Personalize how you manage your property records.',
                  style: TextStyle(color: _secondaryTextColor),
                ),
                const SizedBox(height: 22),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmBeforeDelete,
                  activeTrackColor: _primaryColor,
                  secondary: _iconContainer(Icons.delete_outline),
                  title: const Text(
                    'Confirm before deleting',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Ask before removing a property.'),
                  onChanged: (value) async {
                    setState(() => _confirmBeforeDelete = value);
                    setSheetState(() {});
                    await _saveSettings();
                  },
                ),
                const Divider(color: _borderColor, height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showPropertyIds,
                  activeTrackColor: _primaryColor,
                  secondary: _iconContainer(Icons.tag_outlined),
                  title: const Text(
                    'Show property IDs',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Show reference IDs on property records.',
                  ),
                  onChanged: (value) async {
                    setState(() => _showPropertyIds = value);
                    setSheetState(() {});
                    await _saveSettings();
                  },
                ),
                const Divider(color: _borderColor, height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _iconContainer(Icons.sort_rounded),
                  title: const Text(
                    'Default property sorting',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_defaultSort),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (dialogContext) => SimpleDialog(
                        title: const Text('Sort Properties By'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        children: [
                          for (final option in [
                            'Newest First',
                            'Oldest First',
                            'Name A–Z',
                            'Name Z–A',
                          ])
                            RadioListTile<String>(
                              value: option,
                              groupValue: _defaultSort,
                              title: Text(option),
                              activeColor: _primaryColor,
                              onChanged: (value) =>
                                  Navigator.pop(dialogContext, value),
                            ),
                        ],
                      ),
                    );
                    if (selected != null) {
                      setState(() => _defaultSort = selected);
                      setSheetState(() {});
                      await _saveSettings();
                    }
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'These preferences are saved on this device. The property list must be connected to these preferences for them to change its behavior.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: _secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStorageInformation() async {
    final directory = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: _primaryColor),
            SizedBox(width: 10),
            Expanded(child: Text('Local Device Storage')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your account preferences and property records are currently stored locally on this device.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Application storage location:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(
                '${directory.path}${Platform.pathSeparator}REAL_ESTATE_APP',
                style: const TextStyle(
                  fontSize: 12,
                  color: _secondaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Google Drive synchronization has not been configured in this version of the app.',
                style: TextStyle(color: _secondaryTextColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutInformation() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Logout'),
        content: const Text(
          'An authentication and sign-in system has not been connected to this app yet. Your local property records will remain on this device.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Account',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _textColor,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _topIcon(Icons.settings_outlined, onTap: _openAppSettings),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                _profileCard(),
                const SizedBox(height: 28),
                _sectionHeading('PREFERENCES', 'Manage your app experience'),
                const SizedBox(height: 12),
                _settingsCard(
                  children: [
                    _settingsTile(
                      icon: Icons.tune_rounded,
                      title: 'App Settings',
                      subtitle: 'Sorting and management preferences',
                      onTap: _openAppSettings,
                    ),
                    _tileDivider(),
                    _settingsTile(
                      icon: Icons.storage_rounded,
                      title: 'Storage & Backup',
                      subtitle: 'Local storage · Drive not connected',
                      onTap: _showStorageInformation,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _sectionHeading('ABOUT', 'Application and account'),
                const SizedBox(height: 12),
                _settingsCard(
                  children: [
                    _settingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Real Estate Manager',
                      subtitle: 'Property and customer management',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'Real Estate Manager',
                        applicationVersion: '1.0.0',
                        applicationLegalese: 'Property management application',
                      ),
                    ),
                    _tileDivider(),
                    _settingsTile(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      subtitle: 'Sign-in functionality is not configured',
                      iconColor: const Color(0xFFDC2626),
                      titleColor: const Color(0xFFDC2626),
                      onTap: _showLogoutInformation,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Real Estate Manager',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _secondaryTextColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _profileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF182B56).withValues(alpha: 0.035),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primaryColor.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: const Color(0xFFEAF0FF),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 46,
                    color: _primaryColor,
                  ),
                ),
              ),
              Material(
                color: _primaryColor,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _editProfile,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textColor,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _secondaryTextColor, fontSize: 13.5),
          ),
          if (_phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phone_rounded,
                  size: 14,
                  color: _secondaryTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _phone,
                  style: const TextStyle(
                    color: _secondaryTextColor,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Account Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(color: Color(0xFFD8E1F5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.25,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    final color = iconColor ?? _primaryColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      leading: _iconContainer(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: titleColor ?? _textColor,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: _secondaryTextColor,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 21,
        color: _secondaryTextColor,
      ),
      onTap: onTap,
    );
  }

  Widget _tileDivider() => const Divider(
    height: 1,
    thickness: 1,
    indent: 72,
    endIndent: 14,
    color: _borderColor,
  );

  Widget _iconContainer(IconData icon, {Color color = _primaryColor}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  Widget _topIcon(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _borderColor),
          ),
          child: Icon(icon, color: _textColor, size: 21),
        ),
      ),
    );
  }
}
