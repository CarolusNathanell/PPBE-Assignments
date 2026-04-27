import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService{

  final CollectionReference events = FirebaseFirestore.instance.collection('events');

  //create new note
  Future<void> addEvent(String? userUid, String title, String content, DateTime? eventDate, String? imagePublicId){
    return events.add({
      'userUid': userUid,
      'title': title,
      'content': content,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate) : null,
      'imagePublicId': imagePublicId,
      'createdAt': Timestamp.now()
    });
  }

  //fetch events by user id
  Stream<QuerySnapshot> getEvents(String? userUid) {
    return events.where('userUid', isEqualTo: userUid).orderBy('createdAt', descending: true).snapshots();
  }

  //update events
  Future<void> updateEvent(String id, String title, String content, DateTime? eventDate, String? imagePublicId){
    return events.doc(id).update({
      'title': title,
      'content': content,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate) : null,
      'imagePublicId': imagePublicId,
      'createdAt': Timestamp.now(),
    });
  }

  //delete events
  Future<void> deleteEvent(String id) {
    return events.doc(id).delete();
  }

}