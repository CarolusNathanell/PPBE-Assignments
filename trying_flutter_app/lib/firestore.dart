import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService{

  final CollectionReference notes = FirebaseFirestore.instance.collection('notes');

  //create new note
  Future<void> addNote(String title, String content) {
    return notes.add({
      'title': title,
      'content': content,
      'createdAt': Timestamp.now(),
    });
  }

  //fetch all notes
  Stream<QuerySnapshot> getNotes() {
    return notes.orderBy('createdAt', descending: true).snapshots();
  }

  //update notes
  Future<void> updateNote(String id, String title, String content) {
    return notes.doc(id).update({
      'title': title,
      'content': content,
      'createdAt': Timestamp.now(),
    });
  }

  //delete notes
  Future<void> deleteNote(String id) {
    return notes.doc(id).delete();
  }

}