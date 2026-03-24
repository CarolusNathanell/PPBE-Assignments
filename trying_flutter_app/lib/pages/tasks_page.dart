// pages/tasks_page.dart

import 'package:trying_flutter_app/models/task.dart';
import 'package:trying_flutter_app/models/task_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  // text controller to access what the user typed
  final textController = TextEditingController();
  final dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    readTasks();
  }

  // create a task
  void createTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min, // Prevents unnecessary expansion
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: dateController,
              decoration: InputDecoration(
                labelText: "Deadline",
              ), 
              onTap: () async{
                FocusScope.of(context).requestFocus(FocusNode());
                DateTime? date = DateTime(1900);

                date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100));

                dateController.text = date == null ? DateTime.now().toIso8601String() : date.toIso8601String();
              },
            ),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: "Details",
              ),
            ),
          ],
        ),
        actions: [
          MaterialButton(
            onPressed: () {
              // add to db
              context.read<TaskDatabase>().addTask(textController.text, dateController.text);

              // clear controller
              textController.clear();
              dateController.clear();

              Navigator.pop(context);
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  // read tasks
  void readTasks() {
    context.read<TaskDatabase>().fetchTasks(); // Use read instead of watch
  }

  // update a task
  void updateTask(Task task) {
    textController.text = task.text;
    dateController.text = task.date;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Update Task"),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Prevents unnecessary expansion
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: dateController,
                decoration: InputDecoration(
                  labelText: "Deadline",
                ),
                onTap: () async{
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? date = DateTime(1900);

                  date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(dateController.text),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100));

                  dateController.text = date == null ? DateTime.now().toIso8601String() : date.toIso8601String();
                },
              ),
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: "Details",
                ),
              ),
            ],
          ),
          actions: [
            MaterialButton(
                onPressed: () {
                  context
                      .read<TaskDatabase>()
                      .updateTask(task.id, textController.text, dateController.text);
                  // clear controller
                  textController.clear();
                  dateController.clear();

                  Navigator.pop(context);
                },
                child: const Text("Update"))
          ],
        ));
  }

  // delete a task
  void deleteTask(int id) {
    context.read<TaskDatabase>().deleteTask(id);
  }

  @override
  Widget build(BuildContext context) {
    // task database
    final taskDatabase = context.watch<TaskDatabase>();

    // current tasks
    List<Task> currentTasks = taskDatabase.currentTasks;

    return Scaffold(
        appBar: AppBar(title: const Text('Tasks')),
        floatingActionButton: FloatingActionButton(
          onPressed: createTask,
          child: const Icon(Icons.add),
        ),
        body: ListView.builder(
          itemCount: currentTasks.length,
          itemBuilder: (context, index) {
            // get individual task
            final task = currentTasks[index];

            // list tile UI
            return ListTile(
              title: Text(task.text),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // edit button
                  IconButton(
                      onPressed: () => updateTask(task),
                      icon: const Icon(Icons.edit)),
                  // delete button
                  IconButton(
                      onPressed: () => deleteTask(task.id),
                      icon: const Icon(Icons.delete))
                ],
              ),
            );
          },
        ));
  }
}