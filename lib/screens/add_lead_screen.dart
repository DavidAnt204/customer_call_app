import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../services/api_services.dart';

// --- Design Constants for Trendy Look ---
const Color primaryColor = Color(0xFF4169E1); // Vibrant Royal Blue
const Color accentColor = Color(0xFF00C6FF); // Bright Cyan
const Color bgColor = Color(0xFFF5F7FA); // Light gray background
const double cardRadius = 12.0;

class AddLeadScreen extends StatefulWidget {
  final String leadId;
  const AddLeadScreen({Key? key, required this.leadId}) : super(key: key);

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final LeadService _leadService = LeadService();

  String? _selectedSource;
  String? _selectedStatus;
  bool _isLoading = false;
  bool _isFetchingSources = false;
  bool _isFetchingStatuses = false;
  bool _isFetchingLeadData = false;
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _statuses = [];
  Map<String, dynamic>? _leadData;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchSources();
    _fetchStatuses();
    if (widget.leadId != '--') {
      _fetchLeadData();
    }
  }

  // --- Data Fetching Functions (Functionality Preserved) ---
  Future<void> _fetchSources() async {
    setState(() => _isFetchingSources = true);
    try {
      final fetchedSources = await _leadService.getSources();
      setState(() => _sources = fetchedSources);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching sources: $e")),
      );
    } finally {
      setState(() => _isFetchingSources = false);
    }
  }

  Future<void> _fetchStatuses() async {
    setState(() => _isFetchingStatuses = true);
    try {
      final fetchedStatuses = await _leadService.getStatuses();
      setState(() => _statuses = fetchedStatuses);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching statuses: $e")),
      );
    } finally {
      setState(() => _isFetchingStatuses = false);
    }
  }

  Future<void> _fetchLeadData() async {
    setState(() => _isFetchingLeadData = true);
    try {
      final leadResponse = await _leadService.getLeadData(widget.leadId);
      setState(() {
        _leadData = leadResponse;
        _nameController.text = _leadData?['name'] ?? '';
        _phoneController.text = _leadData?['phonenumber'] ?? '';
        _selectedSource = _leadData?['source']?.toString();
        _selectedStatus = _leadData?['status']?.toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching lead data: $e")),
      );
    } finally {
      setState(() => _isFetchingLeadData = false);
    }
  }

  Future<void> _saveLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    final Map<String, dynamic> staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    try {
      if (widget.leadId == '--') {
        // Add lead
        final result = await _leadService.saveLead(
          source: int.parse(_selectedSource!),
          status: int.parse(_selectedStatus!),
          assigned: int.parse(staffInfo['staffid']),
          phoneNumber: "${_phoneController.text.trim()}",
          name: _nameController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lead saved: ${result['message'] ?? 'Success'}")),
        );
      } else {
        // Update existing lead
        final result = await _leadService.updateLead(
          leadId: widget.leadId,
          source: int.parse(_selectedSource!),
          status: int.parse(_selectedStatus!),
          assigned: int.parse(staffInfo['staffid']),
          phoneNumber: "${_phoneController.text.trim()}",
          name: _nameController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lead updated: ${result['message'] ?? 'Success'}")),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Helper Widget for Modern Input Fields (Preserved) ---
  InputDecoration _buildModernInputDecoration(
      {required String labelText, IconData? icon, Widget? prefix}) {
    return InputDecoration(
      labelText: labelText,
      prefix: prefix,
      suffixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        borderSide: const BorderSide(color: primaryColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.leadId != '--' ? 'Edit Lead' : 'Add Lead';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
      ),
      body: _isFetchingLeadData
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column( // Main Column to hold scrolling content and fixed button
        children: [
          Expanded( // Allows the form to take available space and scroll
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Name Field
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.poppins(),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Name',
                        icon: Icons.person_rounded,
                      ),
                      validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Please enter a name'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // 2. Phone Field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Phone Number',
                        icon: Icons.phone_android_rounded,
                        prefix: Text(
                          '+91 ',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (value.trim().length != 10) {
                          return 'Phone number must be 10 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Reset maxLength counter spacing
                    Container(height: 0, width: 0),
                    const SizedBox(height: 10),

                    // 3. Source Dropdown
                    _isFetchingSources
                        ? const Center(child: CircularProgressIndicator(color: accentColor))
                        : DropdownButtonFormField<String>(
                      value: _selectedSource,
                      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Source',
                        icon: Icons.flag_rounded,
                      ),
                      items: _sources.map((src) {
                        return DropdownMenuItem<String>(
                          value: src['id'].toString(),
                          child: Text(src['text'], style: GoogleFonts.poppins()),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedSource = value),
                      validator: (value) => value == null ? 'Please select a source' : null,
                    ),
                    const SizedBox(height: 20),

                    // 4. Status Dropdown
                    _isFetchingStatuses
                        ? const Center(child: CircularProgressIndicator(color: accentColor))
                        : DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Status',
                        icon: Icons.check_circle_rounded,
                      ),
                      items: _statuses.map((status) {
                        return DropdownMenuItem<String>(
                          value: status['id'].toString(),
                          child: Text(status['text'], style: GoogleFonts.poppins()),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedStatus = value),
                      validator: (value) => value == null ? 'Please select a status' : null,
                    ),

                    const SizedBox(height: 20), // Padding at the bottom of the scroll view
                  ],
                ),
              ),
            ),
          ),

          // 5. Fixed Save button container
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3), // shadow only on top
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54, // Button height
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveLead,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : Text(
                  widget.leadId != '--' ? 'UPDATE LEAD' : 'SAVE LEAD',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}