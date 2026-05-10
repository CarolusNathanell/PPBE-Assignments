import 'package:flutter/material.dart';
import 'package:trying_flutter_app/image_detection_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context){
    return const MaterialApp(
      home: ImageDetectionPage()
    );
  }
}