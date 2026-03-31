// models/task_database.dart
import 'package:trying_flutter_app/models/task.dart';
import 'package:flutter/cupertino.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TaskDatabase extends ChangeNotifier{
  static late Isar isar;

  // INIT
  static Future<void> initialize() async {
    if (Platform.isAndroid) { // Check if it's Android
      final dir = await getApplicationDocumentsDirectory();
      isar = await Isar.open([TaskSchema], directory: dir.path);
    } else {
      // Handle other platforms or provide a default directory
      final dir = getTemporaryDirectory(); // Example for other platforms
      isar = await Isar.open([TaskSchema], directory: (await dir).path);
    }
  }

  // list
  final List<Task> currentTasks = [];

  // create
  Future<void> addTask(String textFromUser, DateTime dateFromUser) async {
    // create a new object
    late Task newTask = Task();
    newTask.text = textFromUser;
    newTask.deadlineDate = dateFromUser;

    // save to db
    await isar.writeTxn(() => isar.tasks.put(newTask));

    // re-read from db
    fetchTasks();
  }

  // read
  Future<void> fetchTasks() async {
    List<Task> fetchedTasks = await isar.tasks.where().findAll();
    currentTasks.clear();
    currentTasks.addAll(fetchedTasks);
    notifyListeners();
  }

  // update
  Future<void> updateTask(int id, String newText, DateTime newDate) async {
    final existingTask = await isar.tasks.get(id);
    if (existingTask != null) {
      existingTask.text = newText;
      existingTask.deadlineDate = newDate;
      await isar.writeTxn(() => isar.tasks.put(existingTask));
      await fetchTasks();
    }
  }

  // delete
  Future<void> deleteTask(int id) async {
    await isar.writeTxn(() => isar.tasks.delete(id));
    await fetchTasks();
  }
}