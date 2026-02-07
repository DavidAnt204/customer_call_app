class Task {
  final String id;
  final String name;
  final String description;
  final String priority;
  final String startDate;
  final String dueDate;
  final String status;

  Task({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.startDate,
    required this.dueDate,
    required this.status,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? '1',
      startDate: json['startdate'] ?? '',
      dueDate: json['duedate'] ?? '',
      status: json['status'] ?? '0',
    );
  }
}
