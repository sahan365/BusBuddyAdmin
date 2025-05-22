// ignore_for_file: library_private_types_in_public_api, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/bookings/viewbooking.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Bus/bus.dart';
import 'Route/addroute.dart';
import 'admin details/admin_profile.dart';
import 'location/driver_dashboard.dart';
import 'login/login.dart';

class HomePage extends StatefulWidget {
  final String adminId;

  const HomePage({super.key, required this.adminId});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, bool> _hoverStates = {
    'buses': false,
    'location': false,
    'bookings': false,
    'routes': false,
  };

  Future<DocumentSnapshot?> _getAdminDetails() async {
    try {
      return await _firestore.collection('admins').doc(widget.adminId).get();
    } catch (e) {
      print("Error fetching admin details: $e");
      return null;
    }
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Admin Dashboard",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: const Color(0xFFF57C00),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(15),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AdminProfilePage(adminId: widget.adminId),
                ),
              );
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 26),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getAdminDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No admin data found.'));
          } else {
            var adminData = snapshot.data!.data() as Map<String, dynamic>;
            final username = adminData['email']?.split('@').first ?? 'Admin';

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.deepOrangeAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back,",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrangeAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      children: [
                        _buildDashboardButton(
                          context,
                          "Manage Buses",
                          FontAwesomeIcons.bus,
                          Colors.blueAccent,
                          const BusPage(),
                          'buses',
                        ),
                        _buildDashboardButton(
                          context,
                          "Live Location",
                          FontAwesomeIcons.locationArrow,
                          Colors.greenAccent,
                          const AdminDashboard(
                            busId: 'BUS123',
                            isDriver: true,
                          ),
                          'location',
                        ),
                        _buildDashboardButton(
                          context,
                          "View Bookings",
                          // ignore: deprecated_member_use
                          FontAwesomeIcons.ticketAlt,
                          Colors.purpleAccent,
                          const AdminBookingsPage(),
                          'bookings',
                        ),
                        _buildDashboardButton(
                          context,
                          "Manage Routes",
                          FontAwesomeIcons.route,
                          Colors.orangeAccent,
                          const AddRoutePage(),
                          'routes',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDashboardButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget destinationPage,
    String hoverKey,
  ) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverStates[hoverKey] = true),
      onExit: (_) => setState(() => _hoverStates[hoverKey] = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationPage),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..scale(_hoverStates[hoverKey]! ? 1.03 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_hoverStates[hoverKey]! ? 0.2 : 0.1),
                blurRadius: _hoverStates[hoverKey]! ? 12 : 8,
                spreadRadius: _hoverStates[hoverKey]! ? 2 : 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: color,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 5),
              if (_hoverStates[hoverKey]!)
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
