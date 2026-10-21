import 'dart:io';
import 'package:flutter/material.dart';
// Added imports to access your storage and state
import '../../../core/services/storage_service.dart'; 
import '../providers/app_state.dart';

class PropertyDetailScreen extends StatefulWidget {
  final dynamic property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _currentImageIndex = 0;

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    }
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(0)} Lakhs';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  // THE DELETE WORKFLOW
  Future<void> _confirmDelete(BuildContext context, String propertyId) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Property'),
            ],
          ),
          content: const Text(
            'Are you sure you want to permanently delete this property? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // 1. Close the dialog
                Navigator.pop(dialogContext);
                
                // 2. Delete the property folder locally
                await storageService.archiveProperty(propertyId);
                
                // 3. Refresh the main properties list
                await appState.loadProperties();
                
                // 4. Go back to the main grid and show success message
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Property deleted successfully'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00796B);

    final Map<String, dynamic> prop = widget.property is Map ? widget.property : {};

    final double budget = (prop['pricing']?['budget'] ?? 0).toDouble();
    final String propertyName = prop['propertyName']?.toString() ?? 'Property Details';
    final String propertyType = prop['propertyType']?.toString() ?? '';
    final String propertyId = prop['propertyId']?.toString() ?? 'N/A';
    final String bhk = prop['specifications']?['bhk']?.toString() ?? '0';

    final Map<String, dynamic>? loc = prop['location'];
    final String locationDisplay = loc != null && loc['city'] != null
        ? '${loc['area'] ?? ''}, ${loc['city']}'.trim()
        : 'Kannur';

    List<String> images = (prop['allImagePaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    if (images.isEmpty && prop['coverImagePath'] != null) {
      images.add(prop['coverImagePath']);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black87),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          propertyName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: primaryTeal),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black54),
            onPressed: () {},
          ),
          // NEW DELETE BUTTON
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context, propertyId),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageGallery(images),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHeaderCard(primaryTeal, budget, propertyName, bhk, propertyType),
                  const SizedBox(height: 16),
                  
                  _buildInformationCard(primaryTeal, prop, propertyId, propertyType, bhk),
                  const SizedBox(height: 16),
                  
                  _buildContactCard(primaryTeal),
                  const SizedBox(height: 16),
                  
                  _buildLocationCard(primaryTeal, locationDisplay),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 5, 
        child: Container(
          width: double.infinity,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.file(
                File(images[index]),
                fit: BoxFit.cover,
                width: double.infinity,
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1} / ${images.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Color primaryColor, double budget, String name, String bhk, String type) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatCurrency(budget),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Negotiable',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$bhk BHK  $type',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard(Color primaryColor, Map<String, dynamic> prop, String propertyId, String type, String bhk) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              const Text('Property Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Property Document', 'Available'),
          _buildDivider(),
          _buildInfoRow('Property ID', propertyId),
          _buildDivider(),
          _buildInfoRow('Type', type.isNotEmpty ? type : 'N/A'),
          _buildDivider(),
          _buildInfoRow('Width', '2000'),
          _buildDivider(),
          _buildInfoRow('Length', '2000'),
          _buildDivider(),
          _buildInfoRow('Land Area', '1', suffix: 'cent'),
          _buildDivider(),
          _buildInfoRow('Land Rate /Cent', '₹400', suffix: 'Thousand'),
          _buildDivider(),
          _buildInfoRow('Buildup Area', '25000', suffix: 'sq.ft'),
          _buildDivider(),
          _buildInfoRow('BHK', bhk, suffix: 'BHK'),
          _buildDivider(),
          _buildInfoRow('No of Floors', '2'),
          _buildDivider(),
          _buildInfoRow('Furnished', 'Yes'),
          _buildDivider(),
          _buildInfoRow('Built Year', '2024'),
          _buildDivider(),
          _buildInfoRow('Parking', '🚗 4W'),
          _buildDivider(),
          _buildInfoRow('Direction', 'South'),
          _buildDivider(),
          _buildInfoRow('Status', prop['status']?.toString() ?? 'ACTIVE'),
        ],
      ),
    );
  }

  Widget _buildContactCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              const Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              text: 'Usman ',
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
              children: [
                TextSpan(
                  text: '(Broker)',
                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('9563421846', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: primaryColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Color primaryColor, String locationDisplay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              const Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Text(locationDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Address details fetched from saved data.',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                text: value,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 14),
                children: suffix != null
                    ? [
                        TextSpan(
                          text: ' $suffix',
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal, fontSize: 13),
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
    return Divider(height: 24, thickness: 1, color: Colors.grey.shade100);
  }
}