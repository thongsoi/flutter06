import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TaskListScreen(),
    );
  }
}

class Task {
  final int id;
  final String title;
  final String description;
  final bool completed;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      completed: json['completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed,
    };
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? completed,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
    );
  }
}

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080'; // Android emulator
    } else {
      return 'http://localhost:8080'; // iOS simulator
    }
  }

  static Future<List<Task>> getTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tasks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Task> createTask(String title, String description) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'title': title, 'description': description}),
      );

      if (response.statusCode == 201) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Task> updateTask(Task task) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/tasks/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      );

      if (response.statusCode == 200) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<void> deleteTask(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tasks/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final fetchedTasks = await ApiService.getTasks();
      setState(() {
        tasks = fetchedTasks;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> addTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditTaskScreen()),
    );

    if (result == true) {
      loadTasks();
    }
  }

  Future<void> editTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditTaskScreen(task: task)),
    );

    if (result == true) {
      loadTasks();
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    try {
      final updatedTask = task.copyWith(completed: !task.completed);
      await ApiService.updateTask(updatedTask);
      loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await ApiService.deleteTask(id);
      loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: loadTasks)],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $error'),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: loadTasks, child: Text('Retry')),
                ],
              ),
            )
          : tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tasks yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text('Tap + to add your first task'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.completed,
                      onChanged: (_) => toggleTaskCompletion(task),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: task.description.isNotEmpty
                        ? Text(task.description)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => editTask(task),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteTask(task.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: addTask,
        tooltip: 'Add Task',
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddEditTaskScreen extends StatefulWidget {
  final Task? task;

  const AddEditTaskScreen({super.key, this.task});

  @override
  _AddEditTaskScreenState createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      if (widget.task == null) {
        // Create new task
        await ApiService.createTask(
          _titleController.text.trim(),
          _descriptionController.text.trim(),
        );
      } else {
        // Update existing task
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
        );
        await ApiService.updateTask(updatedTask);
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
        actions: [
          TextButton(
            onPressed: isLoading ? null : saveTask,
            child: Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              if (isLoading)
                CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saveTask,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      widget.task == null ? 'CREATE TASK' : 'UPDATE TASK',
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
