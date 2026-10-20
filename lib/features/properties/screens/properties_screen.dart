import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import 'add_property/add_property_shell.dart';
import 'property_detail_screen.dart';
import 'dart:io';

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  @override
  void initState() {
    super.initState();
    appState.loadProperties();
    appState.addListener(_update);
  }

  @override
  void dispose() {
    appState.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    }
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} Lakh';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Properties',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: appState.isLoadingProperties
          ? const Center(child: CircularProgressIndicator())
          : appState.properties.isEmpty
          ? _buildEmptyState(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Stats Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    '${appState.properties.length} Active Properties',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                _buildFilterPills(),
                    const SizedBox(height: 16),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => appState.loadProperties(),
                    child: GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: appState.properties.length,
                      itemBuilder: (context, index) {
                        final prop = appState.properties[index];
                        return _buildPropertyCard(context, prop);
                      },
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0, right: 10.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPropertyShell()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, dynamic item) {
    final Map<String, dynamic> prop = item as Map<String, dynamic>;
    final double budget = (prop['pricing']?['budget'] ?? 0).toDouble();
    final Map<String, dynamic>? loc = prop['location'];
    
    String locationText = 'Unknown Location';
    if (loc != null) {
      final area = loc['area'] ?? '';
      final city = loc['city'] ?? '';
      locationText = [area, city].where((e) => e.toString().trim().isNotEmpty).join(', ');
      if (locationText.isEmpty) locationText = 'Unknown Location';
    }

    final String type = prop['propertyType']?.toString() ?? 'Property';
    final String bhk = prop['specifications']?['bhk']?.toString() ?? '-';
    // Dummy logic for baths based on beds, just for aesthetic display
    final String baths = int.tryParse(bhk) != null ? '${int.parse(bhk) + 1}' : '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Tighter radius for grid cards
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailScreen(property: prop),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE SECTION
            // Using Expanded so the image takes exactly whatever height is left
            // in the grid cell, eliminating the bottom overflow completely.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: prop['coverImagePath'] != null
                        ? Image.file(File(prop['coverImagePath']), fit: BoxFit.cover)
                        : Container(color: Colors.grey.shade200, child: const Icon(Icons.home, size: 36, color: Colors.grey)),
                  ),
                  // Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // Favorite Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      radius: 14,
                      child: const Icon(Icons.favorite_border, size: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. BOTTOM DETAILS SECTION
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatCurrency(budget),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF00796B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    prop['propertyName'] ?? 'Beautiful Property',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          locationText, 
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                  ),
                  // Specs Row
                  // Using Flexible widgets here stops the right-side overflow!
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: _buildSpecItem(Icons.king_bed_outlined, '$bhk Beds')),
                      const SizedBox(width: 4),
                      Flexible(child: _buildSpecItem(Icons.bathtub_outlined, '$baths Baths')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated Spec Item explicitly designed for small grid cells
  Widget _buildSpecItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label, 
            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // Cuts off massive numbers like "86835 Beds" cleanly
          ),
        ),
      ],
    );
  }

// Widget _buildSpecItem(IconData icon, String label) {
//   return Row(
//     children: [
//       Icon(icon, size: 18, color: Colors.grey.shade700),
//       const SizedBox(width: 6),
//       Text(label, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
//     ],
//   );
// }

  Widget _buildEmptyState(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => appState.loadProperties(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.real_estate_agent,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No properties yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first property.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFilterPills() {
  final filters = ['All', 'House', 'Villa', 'Apartment', 'Commercial'];
  return SizedBox(
    height: 40,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final isActive = index == 0; // Set up state management for this
        return Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0A4D3C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? const Color(0xFF0A4D3C) : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              filters[index],
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    ),
  );
}
}
