import 'package:flutter/material.dart';

class RequirementDetailScreen extends StatelessWidget {
  final dynamic requirement; // Accepting dynamic to handle incoming Map data

  const RequirementDetailScreen({super.key, required this.requirement});

  // Helper for formatting large currency
  String _formatCurrency(double amount) {
    if (amount >= 10000000) return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(2)} Lakhs';
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00796B); 
    
    // Safely extract data treating it as a Map (since it comes from JSON)
    final Map<String, dynamic> req = requirement is Map ? requirement : {};
    
    final String reqId = req['requirementId']?.toString() ?? 'N/A';
    final double maxBudget = double.tryParse(req['maxBudget']?.toString() ?? '0') ?? 0.0;
    final String customerName = req['customerName']?.toString() ?? 'Unknown Customer';
    final String phone = req['phone']?.toString() ?? 'N/A';
    final String purpose = req['purpose']?.toString() ?? 'Buy';
    final String propertyType = req['propertyType']?.toString() ?? 'Any';
    final String location = req['location']?.toString() ?? 'Any Location';
    final String bhk = req['bhk']?.toString() ?? '';
    final String status = req['status']?.toString() ?? 'ACTIVE';

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
        title: const Text(
          'Requirement Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.black54), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share_outlined, color: Colors.black54), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black54), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderCard(primaryTeal, maxBudget, purpose, bhk, propertyType),
            const SizedBox(height: 16),
            
            _buildContactCard(primaryTeal, customerName, phone),
            const SizedBox(height: 16),

            _buildInformationCard(primaryTeal, reqId, propertyType, bhk, purpose, location, status),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color primaryColor, double budget, String purpose, String bhk, String propertyType) {
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
          const Text(
            'Max Budget',
            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(budget),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Looking to $purpose',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            bhk.isNotEmpty ? '$bhk BHK  $propertyType' : propertyType,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Color primaryColor, String customerName, String phone) {
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
                'Client Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              text: '$customerName ',
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
              children: [
                TextSpan(
                  text: '(Customer)',
                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                phone,
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    radius: 18,
                    child: const Icon(Icons.call, color: Colors.green, size: 18),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    radius: 18,
                    child: const Icon(Icons.message, color: Colors.blue, size: 18),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard(Color primaryColor, String reqId, String type, String bhk, String purpose, String location, String status) {
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
              Icon(Icons.assignment_outlined, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Requirement Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Requirement ID', reqId),
          _buildDivider(),
          _buildInfoRow('Status', status),
          _buildDivider(),
          _buildInfoRow('Purpose', purpose),
          _buildDivider(),
          _buildInfoRow('Property Type', type),
          _buildDivider(),
          _buildInfoRow('Bedrooms', bhk.isNotEmpty ? bhk : 'Any', suffix: bhk.isNotEmpty ? 'BHK' : null),
          _buildDivider(),
          _buildInfoRow('Preferred Location', location),
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