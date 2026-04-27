import 'package:cloudinary_flutter/cloudinary_object.dart';
import 'package:trying_flutter_app/screens/homepage.dart';
import 'package:trying_flutter_app/screens/login.dart';
import 'package:trying_flutter_app/screens/register.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await AwesomeNotifications().initialize(
    null, // null = default app icon
    [
      NotificationChannel(
        channelKey: 'events_channel',
        channelName: 'Event Notifications',
        channelDescription: 'Notifications for new events',
        defaultColor: Colors.deepPurple,
        importance: NotificationImportance.High,
      ),
    ],
  );

  final cloudinary = CloudinaryObject.fromCloudName(cloudName: 'dxxkk3cwr');
  
  runApp(MyApp(cloudinary: cloudinary));
}

class MyApp extends StatelessWidget {
  final CloudinaryObject cloudinary;

  const MyApp({super.key, required this.cloudinary});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(initialRoute: 'login', routes: {
      'home': (context) => HomePage(cloudinary: cloudinary),
      'login': (context) => const LoginScreen(),
      'register': (context) => const RegisterScreen(),
    });
  }
}