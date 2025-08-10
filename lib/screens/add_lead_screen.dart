import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../services/api_services.dart';  // Import your API service

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
  final Color primaryColor = const Color(0xFF4169E1);
  final LeadService _leadService = LeadService();

  String? _selectedSource;
  String? _selectedStatus;
  bool _isLoading = false;
  bool _isFetchingSources = false;
  bool _isFetchingStatuses = false;
  bool _isFetchingLeadData = false;  // Flag for fetching lead data
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _statuses = [];
  Map<String, dynamic>? _leadData;  // Store fetched lead data

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Fetch sources, statuses, and lead data when screen is loaded
  @override
  void initState() {
    super.initState();
    _fetchSources();
    _fetchStatuses();
    if (widget.leadId != '--') {
      _fetchLeadData();
    }
  }

  Future<void> _fetchSources() async {
    setState(() {
      _isFetchingSources = true;
    });

    try {
      final fetchedSources = await _leadService.getSources();
      setState(() {
        _sources = fetchedSources;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching sources: $e")),
      );
    } finally {
      setState(() {
        _isFetchingSources = false;
      });
    }
  }

  Future<void> _fetchStatuses() async {
    setState(() {
      _isFetchingStatuses = true;
    });

    try {
      final fetchedStatuses = await _leadService.getStatuses();
      setState(() {
        _statuses = fetchedStatuses;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching statuses: $e")),
      );
    } finally {
      setState(() {
        _isFetchingStatuses = false;
      });
    }
  }

  Future<void> _fetchLeadData() async {
    setState(() {
      _isFetchingLeadData = true;
    });

    try {
      final leadResponse = await _leadService.getLeadData(widget.leadId);
      setState(() {
        _leadData = leadResponse;
        _nameController.text = _leadData?['name'] ?? '';
        _phoneController.text = _leadData?['phonenumber'] ?? '';
        _selectedSource = _leadData?['source'].toString();
        _selectedStatus = _leadData?['status'].toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching lead data: $e")),
      );
    } finally {
      setState(() {
        _isFetchingLeadData = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.leadId != '--' ? 'Edit Lead' : 'Add Lead',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          iconSize: 32,
          onPressed: () => Navigator.pop(context),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.all(8),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        titleSpacing: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isFetchingLeadData
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: Column(
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  suffixIcon: Icon(Icons.person),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4169E1)),
                  ),
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 24),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefix: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  suffixIcon: const Icon(Icons.phone),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4169E1)),
                  ),
                  labelStyle: const TextStyle(color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                maxLength: 10, // Limit to 10 characters
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Only allow digits
                  LengthLimitingTextInputFormatter(10), // Limit to 10 digits
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.trim().length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                    return 'Phone number must contain only digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Source Dropdown
              _isFetchingSources
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<String>(
                value: _selectedSource,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4169E1)),
                  ),
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                items: _sources.map((src) {
                  return DropdownMenuItem<String>(
                    value: src['id'].toString(),
                    child: Text(src['text']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedSource = value),
                validator: (value) => value == null ? 'Please select a source' : null,
              ),
              const SizedBox(height: 24),

              // Status Dropdown
              _isFetchingStatuses
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4169E1)),
                  ),
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                items: _statuses.map((status) {
                  return DropdownMenuItem<String>(
                    value: status['id'].toString(),
                    child: Text(status['text']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value),
                validator: (value) => value == null ? 'Please select a status' : null,
              ),

              const Spacer(),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveLead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4169E1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    widget.leadId != '--' ? 'Update' : 'Save',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
