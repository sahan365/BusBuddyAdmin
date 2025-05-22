// ignore_for_file: use_super_parameters, avoid_print, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../bookings/viewbooking.dart';
import 'bus_tracking_screen.dart';
import 'permission_handler.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard(
      {Key? key, required String busId, required bool isDriver})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _buses = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _fetchBusesForSelectedDate() async {
    if (_selectedDate == null) return;

    setState(() {
      _isLoading = true;
      _buses = [];
      _errorMessage = null;
    });

    try {
      Timestamp selectedTimestamp = Timestamp.fromDate(_selectedDate!);

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('date', isEqualTo: selectedTimestamp)
          .get();

      print(
          'Fetched ${querySnapshot.docs.length} buses for date $_selectedDate');
      for (var doc in querySnapshot.docs) {
        print('Bus ${doc.id} - ${doc.data()}');
      }

      List<Map<String, dynamic>> buses = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        buses.add({
          'id': doc.id,
          'name': data['busName'] ?? 'Unnamed Bus',
          'time': data['departureTime'] ?? 'No time specified',
          'routeNumber': data['routeNumber'] ?? 'N/A',
          'from': data['fromLocation'] ?? 'Unknown',
          'to': data['toLocation'] ?? 'Unknown',
          'totalSeats': data['seatCount'] ?? 20,
        });
      }

      setState(() {
        _buses = buses;
        _isLoading = false;
        if (buses.isEmpty) {
          _errorMessage = 'No buses found for selected date';
        }
      });
    } catch (e) {
      print('Error fetching buses: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching buses: ${e.toString()}';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchBusesForSelectedDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'No date selected'
                        : 'Selected: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Select Date'),
                ),
              ],
            ),
          ),
          const Divider(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            )
          else if (_selectedDate == null)
            const Center(
              child: Text(
                'Please select a date to view buses',
                style: TextStyle(fontSize: 18),
              ),
            )
          else if (_buses.isEmpty)
            const Center(
              child: Text(
                'No buses found for selected date',
                style: TextStyle(fontSize: 18),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _buses.length,
                itemBuilder: (context, index) {
                  final bus = _buses[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bus['name'],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Route: ${bus['routeNumber']}'),
                          Text('Time: ${bus['time']}'),
                          Text('From: ${bus['from']}'),
                          Text('To: ${bus['to']}'),
                          Text('Total Seats: ${bus['totalSeats']}'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AdminBookingsPage(),
                                      settings: RouteSettings(
                                        arguments: {
                                          'busId': bus['id'],
                                          'date': _selectedDate,
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('View Bookings'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  if (await PermissionHandler
                                      .checkLocationPermission(context)) {
                                    Navigator.push(
                                      // ignore: use_build_context_synchronously
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BusTrackingScreen(
                                          busId: bus['id'],
                                          routeFrom: '',
                                          routeTo: '',
                                          isDriver: false,
                                          routeNumber: '',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Share Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
