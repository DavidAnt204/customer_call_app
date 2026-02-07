import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

// Reuse same design constants
const Color primaryColor = Color(0xFF4169E1);
const Color accentColor = Color(0xFF00C6FF);
const Color bgColor = Color(0xFFF5F7FA);
const double cardRadius = 12.0;

class AddTaskScreen extends StatefulWidget {
  final int leadId;

  // NEW (optional for edit)
  final int? taskId;
  final bool isEdit;
  final String? subject;
  final String? description;
  final String? startDate;
  final String? dueDate;
  final int? priority;

  const AddTaskScreen({
    super.key,
    required this.leadId,
    this.taskId,
    this.isEdit = false,
    this.subject,
    this.description,
    this.startDate,
    this.dueDate,
    this.priority,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _dueDateCtrl = TextEditingController();

  int _priority = 2;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill when editing (no UI change, only values)
    if (widget.isEdit) {
      _subjectCtrl.text = widget.subject ?? '';
      _descCtrl.text = widget.description ?? '';
      _startDateCtrl.text = widget.startDate ?? '';
      _dueDateCtrl.text = widget.dueDate ?? '';
      _priority = widget.priority ?? 2;
    }
  }

  InputDecoration _buildModernInputDecoration(
      {required String labelText, required IconData icon}) {
    return InputDecoration(
      labelText: labelText,
      suffixIcon: Icon(icon, color: Colors.grey.shade600),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      floatingLabelStyle:
      const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
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
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today, // disable past dates
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    final Map<String, dynamic> staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    http.Response response;

    if (widget.isEdit) {
      // PATCH update API
      response = await http.patch(
        Uri.parse(
            'https://crm.vasaantham.com/api/update_task/${widget.taskId}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "subject": _subjectCtrl.text.trim(),
          "description": _descCtrl.text.trim(),
          "priority": _priority,
          "status": 3,
          "duedate": _dueDateCtrl.text,
        }),
      );
    } else {
      // CREATE API (your existing logic)
      response = await http.post(
        Uri.parse('https://crm.vasaantham.com/api/create_task'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "subject": _subjectCtrl.text.trim(),
          "description": _descCtrl.text.trim(),
          "lead_id": widget.leadId,
          "startdate": _startDateCtrl.text,
          "duedate": _dueDateCtrl.text,
          "priority": _priority,
          "assigned_to": int.parse(staffInfo['staffid'])
        }),
      );
    }

    setState(() => _isLoading = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.isEdit
                ? "Task updated successfully"
                : "Task created successfully")),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Task' : 'Add Task',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 24, bottom: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _subjectCtrl,
                      style: GoogleFonts.poppins(),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Subject',
                        icon: Icons.title_rounded,
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Please enter subject' : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      style: GoogleFonts.poppins(),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Description',
                        icon: Icons.description_rounded,
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Please enter description' : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _startDateCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(_startDateCtrl),
                      style: GoogleFonts.poppins(),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Start Date',
                        icon: Icons.calendar_today_rounded,
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Select start date' : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _dueDateCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(_dueDateCtrl),
                      style: GoogleFonts.poppins(),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Due Date',
                        icon: Icons.event_available_rounded,
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Select due date' : null,
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<int>(
                      value: _priority,
                      style: GoogleFonts.poppins(
                          color: Colors.black87, fontSize: 16),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: primaryColor),
                      decoration: _buildModernInputDecoration(
                        labelText: 'Priority',
                        icon: Icons.flag_rounded,
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Low')),
                        DropdownMenuItem(value: 2, child: Text('Medium')),
                        DropdownMenuItem(value: 3, child: Text('High')),
                      ],
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  widget.isEdit ? 'UPDATE TASK' : 'SAVE TASK',
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
