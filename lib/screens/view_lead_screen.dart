import 'package:flutter/material.dart';
import 'dart:ui'; // Required for BackdropFilter
import 'dart:convert';
import 'package:http/http.dart' as http; // Import for API calls

// --- Color Constants for Trendy Design ---
const Color primaryColor = Color(0xFF4169E1); // Vibrant Royal Blue
const Color backgroundColor = Color(0xFFF5F7FA); // Light gray background
const double cardRadius = 16.0; // Slightly larger radius for softer look

// --- API Service Implementation (Functionality Preserved) ---
class LeadService {
  final String baseUrl = 'https://crm.vasaantham.com/api';

  Future<Map<String, dynamic>> getLeadData(String leadId) async {
    final url = Uri.parse('$baseUrl/get_lead/$leadId');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load lead data. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
// --------------------------------------------------------------------------

class LeadDetailsPage extends StatefulWidget {
  final String leadId;

  const LeadDetailsPage({Key? key, required this.leadId}) : super(key: key);

  @override
  State<LeadDetailsPage> createState() => _LeadDetailsPageState();
}

class _LeadDetailsPageState extends State<LeadDetailsPage> {
  Map<String, dynamic>? _leadData;
  bool _isFetchingLeadData = false;
  final LeadService _leadService = LeadService();

  // Fields to group information (Functionality Preserved)
  static const contactFields = [
    'name',
    'company',
    'phonenumber',
    'email',
    'website',
  ];

  static const addressFields = [
    'address',
    'street',
    'city',
    'state',
    'zip',
    'country',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLeadData();
  }

  Future<void> _fetchLeadData() async {
    setState(() => _isFetchingLeadData = true);

    try {
      final leadResponse = await _leadService.getLeadData(widget.leadId);
      final cleanedData = Map<String, dynamic>.from(leadResponse)
        ..removeWhere((key, value) => value == null || value.toString().isEmpty);

      setState(() => _leadData = cleanedData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching lead data: $e')),
      );
    } finally {
      setState(() => _isFetchingLeadData = false);
    }
  }

  // --- REINSTATED: Glassy AppBar Implementation ---
  PreferredSizeWidget _buildGlassyAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          // Applies the blur effect
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            // Translucent color for the glassy look
            backgroundColor: const Color.fromRGBO(255, 255, 255, 0.4),
            elevation: 0,

            // Title is LEFT ALIGNED
            centerTitle: false,

            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Lead Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
  // ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = _leadData ?? {};

    final contactInfo = _filterFields(data, contactFields);
    final addressInfo = _filterFields(data, addressFields);
    final otherInfo = Map<String, dynamic>.from(data)
      ..removeWhere((key, _) =>
      contactFields.contains(key) || addressFields.contains(key));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildGlassyAppBar(context),
      body: _isFetchingLeadData
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard("Contact Information", contactInfo),
            _buildSectionCard("Address Information", addressInfo),
            _buildSectionCard("Other Details", otherInfo),
          ],
        ),
      ),
    );
  }

  // --- Utility Methods (Logic Retained) ---

  Map<String, dynamic> _filterFields(Map<String, dynamic> data, List<String> fields) {
    return {
      for (var key in fields)
        if (data.containsKey(key)) key: data[key]
    };
  }

  // --- MODIFIED: Section Card with User's Requested Header Style ---
  Widget _buildSectionCard(String title, Map<String, dynamic> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header (User's Requested Style)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  color: primaryColor,
                  margin: const EdgeInsets.only(right: 12),
                ),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primaryColor), // Use primaryColor as requested
                ),
              ],
            ),
          ),
          // Divider below the header (Kept from previous modern design)
          const Divider(height: .5, indent: 20, endIndent: 20, thickness: .5, color: primaryColor,),

          // List of Info Tiles (Modern Design Retained)
          ...data.entries.map((entry) {
            final isLast = entry.key == data.keys.last;
            return _buildInfoTile(
              entry.key,
              entry.value?.toString() ?? 'N/A',
              addBottomPadding: isLast,
            );
          }).toList(),
        ],
      ),
    );
  }

  // --- Modern Info Tile Widget (Retained) ---
  Widget _buildInfoTile(String key, String value, {required bool addBottomPadding}) {
    final icon = _getIcon(key);
    final color = _getIconColor(key);
    final label = _beautifyKey(key);
    final displayValue = (value == 'null' || value.trim().isEmpty) ? 'N/A' : value;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, addBottomPadding ? 20 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Separator for the value
          Container(
            padding: const EdgeInsets.only(left: 26, top: 4), // Aligns with the end of the icon
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Optional: A subtle divider between fields, not on the last item
          if (!addBottomPadding)
            const Padding(
              padding: EdgeInsets.only(top: 12, left: 26),
              child: Divider(height: 1, thickness: 0.5, color: Colors.black12),
            ),
        ],
      ),
    );
  }

  String _beautifyKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}')
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^[a-z]'),
            (match) => match.group(0)!.toUpperCase());
  }

  IconData _getIcon(String key) {
    if (key.contains('phone')) return Icons.phone_android_rounded;
    if (key.contains('email')) return Icons.mail_rounded;
    if (key.contains('date')) return Icons.calendar_today_rounded;
    if (key.contains('address') || key.contains('city') || key.contains('street') || key.contains('state') || key.contains('zip') || key.contains('country')) {
      return Icons.location_on_rounded;
    }
    if (key.contains('name')) return Icons.person_rounded;
    if (key.contains('company')) return Icons.business_rounded;
    if (key.contains('status')) return Icons.info_rounded;
    if (key.contains('id')) return Icons.badge_rounded;
    if (key.contains('description')) return Icons.notes_rounded;
    if (key.contains('website')) return Icons.web_asset_rounded;
    return Icons.label_rounded;
  }

  Color _getIconColor(String key) {
    if (key.contains('phone')) return Colors.green.shade600;
    if (key.contains('email')) return Colors.blue.shade600;
    if (key.contains('date')) return Colors.purple.shade600;
    if (key.contains('address') || key.contains('city') || key.contains('state') || key.contains('zip') || key.contains('country')) {
      return Colors.orange.shade600;
    }
    if (key.contains('name')) return Colors.indigo.shade600;
    if (key.contains('company')) return Colors.teal.shade600;
    if (key.contains('status')) return Colors.red.shade600;
    if (key.contains('description')) return Colors.brown.shade600;
    if (key.contains('website')) return Colors.pink.shade600;
    return Colors.grey.shade600;
  }
}