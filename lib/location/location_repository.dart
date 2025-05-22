import 'package:cloud_firestore/cloud_firestore.dart';

class LocationRepository {
  final FirebaseFirestore _firestore;

  LocationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> updateBusLocation(String busId, double lat, double lng) async {
    assert(busId.isNotEmpty, 'busId cannot be empty');
    await _firestore.collection('buses').doc(busId).set({
      'location': GeoPoint(lat, lng),
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getBusLocationStream(String busId) {
    assert(busId.isNotEmpty, 'busId cannot be empty');
    return _firestore.collection('buses').doc(busId).snapshots();
  }
}
