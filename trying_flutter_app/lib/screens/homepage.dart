import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_flutter/cloudinary_object.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:cloudinary_url_gen/transformation/resize/resize.dart';
import 'package:trying_flutter_app/firestore.dart';
import 'package:trying_flutter_app/screens/login.dart';


class HomePage extends StatefulWidget {
  final CloudinaryObject cloudinary;
  const HomePage({super.key, required this.cloudinary});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final titleTextController = TextEditingController();
  final contentTextController = TextEditingController();
  DateTime? selectedEventDate;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  XFile? selectedImage;
  bool isUploading = false;

  final FirestoreService firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    AwesomeNotifications().requestPermissionToSendNotifications();
  }

  Future<void> _sendEventNotification(String title, DateTime? eventDate) async {
    final String dateText = eventDate != null
        ? '📅 ${eventDate.day}/${eventDate.month}/${eventDate.year} at ${eventDate.hour.toString().padLeft(2, '0')}:${eventDate.minute.toString().padLeft(2, '0')}'
        : 'No date set';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'events_channel',
        title: '📌 New Event: $title',
        body: dateText,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  // Build a map of date -> list of events from Firestore docs
  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap(List<QueryDocumentSnapshot> docs) {
    final Map<DateTime, List<Map<String, dynamic>>> map = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['eventDate'] as Timestamp?;
      if (timestamp == null) continue;

      final date = _normalizeDate(timestamp.toDate());
      map[date] = map[date] ?? [];
      map[date]!.add({...data, 'docId': doc.id});
    }
    return map;
  }
List<Map<String, dynamic>> _getEventsForDay(
      DateTime day, Map<DateTime, List<Map<String, dynamic>>> eventMap) {
    return eventMap[_normalizeDate(day)] ?? [];
  }

  void _showDayEventsSheet(
      BuildContext context,
      DateTime day,
      List<Map<String, dynamic>> events,
      String? userUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Date header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${day.day}/${day.month}/${day.year}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      // Add event button for this specific day
                      IconButton(
                        icon: const Icon(CupertinoIcons.add_circled),
                        onPressed: () {
                          Navigator.pop(context);
                          selectedEventDate = day;
                          openEventBox(userUid: userUid, existingDate: selectedEventDate);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Events list
                Expanded(
                  child: events.isEmpty
                      ? const Center(child: Text('No events on this day'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            final String docId = event['docId'];
                            final String title = event['title'] ?? '';
                            final String content = event['content'] ?? '';
                            final DateTime? eventDate =
                                (event['eventDate'] as Timestamp?)?.toDate();
                            final String? imagePublicId = event['imagePublicId'];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imagePublicId != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        height: 150,
                                        width: double.infinity,
                                        child: CldImageWidget(
                                          cloudinary: widget.cloudinary,
                                          publicId: imagePublicId,
                                          transformation: Transformation()
                                            ..resize(Resize.fill()),
                                        ),
                                      ),
                                    ),
                                  ListTile(
                                    title: Text(title),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(content),
                                        if (eventDate != null)
                                          Text(
                                            '🕐 ${eventDate.hour.toString().padLeft(2, '0')}:${eventDate.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                                fontSize: 12, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(CupertinoIcons.pencil),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            openEventBox(
                                              docId: docId,
                                              existingTitle: title,
                                              existingContent: content,
                                              existingDate: eventDate,
                                              existingImagePublicId: imagePublicId,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(CupertinoIcons.delete),
                                          onPressed: () {
                                            firestoreService.deleteEvent(docId);
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> pickEventDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedEventDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedEventDate ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          selectedEventDate = DateTime(
            picked.year, picked.month, picked.day,
            pickedTime.hour, pickedTime.minute,
          );
        });
      }
    }
  }

  Future<String?> uploadImageToCloudinary(XFile image) async {
    
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/dxxkk3cwr/upload');

    final bytes = await image.readAsBytes();

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = 'ThingyMinder_preset'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: image.name,
      ));

    final response = await request.send();
    if (response.statusCode == 200) {  
      final body = jsonDecode(await response.stream.bytesToString());
      return body['public_id'] as String?;
    }
    return null;
  }

  void openEventBox({
      String? userUid,
      String? docId,
      String? existingTitle,
      String? existingContent,
      DateTime? existingDate,
      String? existingImagePublicId,
    }) async {
    if (docId != null) {
      titleTextController.text = existingTitle ?? '';
      contentTextController.text = existingContent ?? '';
      selectedEventDate = existingDate;
    } else {
      selectedEventDate = null;
    }
    selectedImage = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(docId == null ? "Create new Event" : "Edit Event"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(labelText: "Title"),
                      controller: titleTextController,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(labelText: "Content"),
                      controller: contentTextController,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedEventDate == null
                                ? 'No date selected'
                                : '${selectedEventDate!.toLocal()}'.split('.')[0],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(CupertinoIcons.calendar_today, size: 16),
                          label: const Text('Pick'),
                          onPressed: () async {
                            await pickEventDate(dialogContext);
                            setDialogState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(selectedImage!.path),
                          height: 150,
                          width: 300,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (existingImagePublicId != null)
                      // Show existing Cloudinary image when editing
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: CldImageWidget(
                            cloudinary: widget.cloudinary,
                            publicId: existingImagePublicId,
                            transformation: Transformation()
                              ..resize(Resize.fill()),
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(CupertinoIcons.photo, size: 16),
                          label: const Text('Gallery'),
                          onPressed: () async {
                            final XFile? image = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 80,         // compress to save bandwidth
                            );
                            if (image != null) {
                              setDialogState(() => selectedImage = image);
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(CupertinoIcons.camera, size: 16),
                          label: const Text('Camera'),
                          onPressed: () async {
                            final XFile? image = await _picker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 80,
                            );
                            if (image != null) {
                              setDialogState(() => selectedImage = image);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                else
                MaterialButton(
                  onPressed: () async {
                    setDialogState(() => isUploading = true);

                    // Upload image if a new one was picked
                    String? imagePublicId = existingImagePublicId;
                    if (selectedImage != null) {
                      imagePublicId = await uploadImageToCloudinary(selectedImage!);
                    }

                    if (docId == null) {
                      firestoreService.addEvent(
                        userUid,
                        titleTextController.text,
                        contentTextController.text,
                        selectedEventDate,
                        imagePublicId
                      );

                      await _sendEventNotification(titleTextController.text, selectedEventDate);
                    } else {
                      firestoreService.updateEvent(
                        docId,
                        titleTextController.text,
                        contentTextController.text,
                        selectedEventDate,
                        imagePublicId
                      );
                    }
                    titleTextController.clear();
                    contentTextController.clear();
                    selectedEventDate = null;
                    selectedImage = null;
                    setDialogState(() => isUploading = false);

                    Navigator.pop(context);
                  },
                  child: Text(docId == null ? "Create" : "Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final userUid = snapshot.data?.uid;

          return Scaffold(
            appBar: AppBar(
              title: Text('${snapshot.data?.displayName}\'s Events'),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => openEventBox(userUid: userUid),
              child: const Icon(CupertinoIcons.add_circled),
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getEvents(userUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final eventMap = _buildEventMap(
                    docs.cast<QueryDocumentSnapshot>());

                return TableCalendar(
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2100),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) => _getEventsForDay(day, eventMap),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    // Show bottom sheet with that day's events
                    _showDayEventsSheet(
                      context,
                      selectedDay,
                      _getEventsForDay(selectedDay, eventMap),
                      userUid,
                    );
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  // Number badge builder
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${events.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                );
              },
            ),
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}