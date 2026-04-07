import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:trying_flutter_app/firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final titleTextController = TextEditingController();
  final contentTextController = TextEditingController();

  final FirestoreService firestoreService = FirestoreService();

  void openNoteBox({String? docId, String? existingTitle, String? existingNote}) async {
    if (docId != null) {

      titleTextController.text = existingTitle ?? '';
      contentTextController.text = existingNote ?? '';

    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(docId == null ? "Create new Note" : "Edit Note"),
          content: Column(
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
            ],
          ),
          actions: [
            MaterialButton(
              onPressed: () {
                if (docId == null) {
                  firestoreService.addNote(
                    titleTextController.text,
                    contentTextController.text,
                  );
                } else {
                  firestoreService.updateNote(
                    docId,
                    titleTextController.text,
                    contentTextController.text,
                  );
                }
                titleTextController.clear();
                contentTextController.clear();

                Navigator.pop(context);
              },
              child: Text(docId == null ? "Create" : "Update"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notes")),
      floatingActionButton: FloatingActionButton(
        onPressed: openNoteBox,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getNotes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            List notesList = snapshot.data!.docs;

            return ListView.builder(
              itemCount: notesList.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = notesList[index];
                String docId = document.id;

                Map<String, dynamic> data =
                document.data() as Map<String, dynamic>;
                String noteTitle = data['title'];
                String noteContent = data['content'];

                return ListTile(
                  title: Text(noteTitle),
                  subtitle: Text(noteContent),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          openNoteBox(docId: docId, existingNote: noteContent, existingTitle: noteTitle);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          firestoreService.deleteNote(docId);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          } else {
            return const Text("No data");
          }
        },
      ),
    );
  }
}