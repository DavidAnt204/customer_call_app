import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../models/task_model.dart';
import 'create_task_screen.dart';

const Color primaryColor = Color(0xFF4169E1);
const Color bgColor = Color(0xFFF5F7FA);
const double cardRadius = 12.0;

class TaskListScreen extends StatefulWidget {
  final int leadId;
  const TaskListScreen({super.key, required this.leadId});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);

    final res = await http.get(
      Uri.parse(
          'https://crm.vasaantham.com/api/get_tasks_by_lead/${widget.leadId}'),
    );

    final List data = jsonDecode(res.body);
    _tasks = data.map((e) => Task.fromJson(e)).toList();

    setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    await _loadTasks();
  }

  Color priorityColor(String p) =>
      p == '3' ? Colors.red : p == '2' ? Colors.orange : Colors.green;

  String priorityText(String p) =>
      p == '3' ? 'High' : p == '2' ? 'Medium' : 'Low';

  Future<void> _deleteTask(String id) async {
    await http.post(
      Uri.parse('https://crm.vasaantham.com/api/delete_task/$id'),
      headers: {"Content-Type": "application/json"},
    );
    await _loadTasks();
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white, // white text
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) _deleteTask(id);
  }

  Future<void> _openEdit(Task t) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          leadId: widget.leadId,
          taskId: int.parse(t.id),
          isEdit: true,
          subject: t.name,
          description: t.description.replaceAll(RegExp(r'<[^>]*>'), ''),
          startDate: t.startDate,
          dueDate: t.dueDate,
          priority: int.parse(t.priority),
        ),
      ),
    );

    if (result == true) {
      await _loadTasks();
    }
  }

  Widget actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Task List',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: primaryColor),
            onPressed: () async {
              final r = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddTaskScreen(leadId: widget.leadId)),
              );
              if (r == true) await _loadTasks();
            },
          )
        ],
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: primaryColor))
          : _tasks.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No tasks found',
                style: GoogleFonts.poppins(
                    fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 8),
            Text('Tap + to create a new task',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      )
          : RefreshIndicator(
        color: primaryColor,
        onRefresh: _refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _tasks.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 16),
          itemBuilder: (_, i) {
            final t = _tasks[i];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.name,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor)),
                      ),

                      // priority chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin:
                        const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: priorityColor(t.priority)
                              .withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(
                            priorityText(t.priority),
                            style: TextStyle(
                                color:
                                priorityColor(t.priority),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),

                      actionButton(
                        icon: Icons.edit_rounded,
                        color: primaryColor,
                        onTap: () => _openEdit(t),
                      ),
                      const SizedBox(width: 8),
                      actionButton(
                        icon: Icons.delete_rounded,
                        color: Colors.red,
                        onTap: () =>
                            _confirmDelete(t.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    t.description.replaceAll(
                        RegExp(r'<[^>]*>'), ''),
                    style:
                    GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(Icons.play_arrow,
                          size: 18, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(t.startDate),
                      const Spacer(),
                      const Icon(Icons.event,
                          size: 18,
                          color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(t.dueDate),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
