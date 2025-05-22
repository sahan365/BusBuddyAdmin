import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<void> addAdmin(Admin admin) async {
    try {
      await _firestore.collection('admins').doc(admin.id).set(admin.toMap());
    } catch (e) {
      // ignore: avoid_print
      print("Error adding admin: $e");
    }
  }


  Future<Admin?> getAdminById(String adminId) async {
    try {
      DocumentSnapshot snapshot =
          await _firestore.collection('admins').doc(adminId).get();
      if (snapshot.exists) {
        return Admin.fromMap(snapshot.data() as Map<String, dynamic>);
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error getting admin: $e");
    }
    return null;
  }
}
