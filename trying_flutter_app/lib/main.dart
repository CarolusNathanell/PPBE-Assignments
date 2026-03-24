import 'package:trying_flutter_app/models/task_database.dart';
import 'package:trying_flutter_app/pages/tasks_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TaskDatabase.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => TaskDatabase(),
      child: const MyApp(),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TasksPage()
    );
  }
}
