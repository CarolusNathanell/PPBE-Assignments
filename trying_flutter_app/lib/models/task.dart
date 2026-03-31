// models/task.dart
import 'package:isar/isar.dart';

// this line is needed to generate file
// then run dart run build_runner build
part 'task.g.dart';

@Collection()
class Task {
  Id id = Isar.autoIncrement;
  late String text;
  late DateTime deadlineDate;
}