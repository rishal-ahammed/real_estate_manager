import 'package:flutter/material.dart';

class PropertyDetailScreen extends StatelessWidget {
  final dynamic property; // Accepting dynamic to handle both Index and Full property models for now

  const PropertyDetailScreen({super.key, required this.property});

  // Helper for formatting large currency
  String _formatCurrency(double amount) {
    if (amount >= 10000000) return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(0)} Lakhs';
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    // Custom Teal color to match your screenshot
    const primaryTeal = Color(0xFF00796B); 

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
          property.propertyName ?? 'Property Details',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border, color: Colors.black54), onPressed: () {}),
          IconButton(icon: const Icon(Icons.language, color: primaryTeal), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share_outlined, color: Colors.black54), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black54), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderCard(primaryTeal),
            const SizedBox(height: 16),
            
            _buildInformationCard(primaryTeal),
            const SizedBox(height: 16),
            
            _buildContactCard(primaryTeal),
            const SizedBox(height: 16),
            
            _buildLocationCard(primaryTeal),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color primaryColor) {
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
            _formatCurrency(property.budget ?? 500000),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Negotiable',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Text(
            property.propertyName ?? 'Unknown Property',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${property.bhk ?? 0} BHK  ${property.propertyType ?? ""}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard(Color primaryColor) {
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
              const Text(
                'Property Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Property Document', 'Available'),
          _buildDivider(),
          _buildInfoRow('Property ID', property.propertyId ?? 'N/A'),
          _buildDivider(),
          _buildInfoRow('Type', '${property.propertyType ?? ""} Single'),
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
          _buildInfoRow('BHK', '${property.bhk ?? 0}', suffix: 'BHK'),
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
          _buildInfoRow('Created At', '30 Sept 2026, 2:31 pm'),
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
              const Text(
                'Contact Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
              Text(
                '9563421846',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: primaryColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Color primaryColor) {
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
              const Text(
                'Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            property.location ?? 'Kannur',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Address not available',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Helper Widget for the key-value rows
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

  // Helper for the faint divider lines
  Widget _buildDivider() {
    return Divider(
      height: 24,
      thickness: 1,
      color: Colors.grey.shade100,
    );
  }
}