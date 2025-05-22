// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminBookingsPage extends StatefulWidget {
  const AdminBookingsPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AdminBookingsPageState createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<AdminBookingsPage> {
  DateTime? selectedDate;
  String? selectedBusId;
  List<String> bookedSeats = [];
  int totalSeats = 20;
  Map<String, dynamic> busMetrics = {
    'bookedSeats': 0,
    'availableSeats': 20,
    'revenue': 0.0,
    'confirmedPassengers': 0,
    'totalPassengers': 0
  };
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  StreamSubscription<DocumentSnapshot>? _busSubscription;
  Map<String, List<Map<String, dynamic>>> locationPassengers = {};
  String? selectedLocation;
  bool showLocationDetails = false;

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _busSubscription?.cancel();
    super.dispose();
  }

  Future<void> _calculateMetrics(String busId) async {
    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('busId', isEqualTo: busId)
          .get();

      int booked = 0;
      double revenue = 0.0;
      int confirmed = 0;

      for (var doc in bookingsSnapshot.docs) {
        // ignore: unnecessary_cast
        final data = doc.data() as Map<String, dynamic>;
        final seatCount = (data['seatNumbers'] as List).length;
        booked += seatCount;

        final ticketPrice = (data['ticketPrice'] as num?)?.toDouble() ?? 0.0;
        revenue += ticketPrice * seatCount;

        if (data['status'] == 'Confirmed') {
          confirmed++;
        }
      }

      setState(() {
        busMetrics = {
          'bookedSeats': booked,
          'availableSeats': totalSeats - booked,
          'revenue': revenue,
          'confirmedPassengers': confirmed,
          'totalPassengers': bookingsSnapshot.docs.length
        };
      });
    } catch (e) {
      print('Error calculating metrics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPassengersForLocation(
      String busId, String location) async {
    try {
      final locationKey = location.toLowerCase().trim();
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('busId', isEqualTo: busId)
          .get();

      List<Map<String, dynamic>> passengers = [];

      for (var doc in bookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        String docPickupLocation =
            (data['pickupLocation'] ?? '').toString().toLowerCase().trim();
        String docDropLocation =
            (data['dropLocation'] ?? '').toString().toLowerCase().trim();

        if (docPickupLocation == locationKey ||
            docDropLocation == locationKey) {
          passengers.add({
            'id': doc.id,
            'name': data['name'] ?? 'No Name',
            'seatNumbers': data['seatNumbers'] ?? [],
            'pickupLocation': data['pickupLocation'],
            'dropLocation': data['dropLocation'],
            'phone': data['phone'],
            'status': data['status'] ?? 'Confirmed',
            'amount': data['amount']?.toStringAsFixed(2),
          });
        }
      }

      return passengers;
    } catch (e) {
      // ignore: duplicate_ignore
      // ignore: avoid_print
      print('Error getting passengers: $e');
      return [];
    }
  }

  Future<void> loadLocationPassengers(String busId) async {
    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('busId', isEqualTo: busId)
          .get();

      Set<String> allLocations = {};

      for (var doc in bookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data['pickupLocation'] != null) {
          allLocations.add(data['pickupLocation'].toString().toLowerCase());
        }
        if (data['dropLocation'] != null) {
          allLocations.add(data['dropLocation'].toString().toLowerCase());
        }
      }

      Map<String, List<Map<String, dynamic>>> locationData = {};

      for (String location in allLocations) {
        final passengers = await getPassengersForLocation(busId, location);
        if (passengers.isNotEmpty) {
          locationData[location] = passengers;
        }
      }

      setState(() {
        locationPassengers = locationData;
        if (locationData.isNotEmpty) {
          selectedLocation = locationData.keys.first;
        }
      });
    } catch (e) {
      print('Error loading location passengers: $e');
    }
  }

  void _setupBusListener(String busId) {
    _busSubscription = FirebaseFirestore.instance
        .collection('buses')
        .doc(busId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        setState(() {
          totalSeats = snapshot.data()?['seatCount'] ?? 20;
        });
        loadLocationPassengers(busId);
        _calculateMetrics(busId);
      }
    }, onError: (error) {
      print("Error listening to bus: $error");
    });
  }

  void _setupBookingsListener(String busId) {
    _bookingsSubscription?.cancel();

    _bookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('busId', isEqualTo: busId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          bookedSeats = snapshot.docs
              .expand((doc) => (doc.data()['seatNumbers'] as List<dynamic>)
                  .map((seat) => seat.toString())
                  .toList())
              .toList();
        });
        _calculateMetrics(busId);
        loadLocationPassengers(busId);
      }
    }, onError: (error) {
      print("Error listening to bookings: $error");
    });
  }

  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
        selectedBusId = null;
        bookedSeats.clear();
        busMetrics = {
          'bookedSeats': 0,
          'availableSeats': 20,
          'revenue': 0.0,
          'confirmedPassengers': 0,
          'totalPassengers': 0
        };
        locationPassengers.clear();
        showLocationDetails = false;
      });
      _bookingsSubscription?.cancel();
      _busSubscription?.cancel();
    }
  }

  void _showPassengerDetails(Map<String, dynamic> passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(passenger['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Seats', passenger['seatNumbers'].join(', ')),
              _buildDetailItem('Status', passenger['status']),
              if (passenger['phone'] != null)
                _buildDetailItem('Phone', passenger['phone']),
              if (passenger['amount'] != null)
                _buildDetailItem('Amount', '\$${passenger['amount']}'),
              _buildDetailItem('Pickup Location', passenger['pickupLocation']),
              _buildDetailItem('Drop Location', passenger['dropLocation']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _navigateToEditBooking(BuildContext context, String bookingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBookingPage(bookingId: bookingId),
      ),
    ).then((_) {
      if (selectedBusId != null) {
        _setupBookingsListener(selectedBusId!);
        _calculateMetrics(selectedBusId!);
        loadLocationPassengers(selectedBusId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Bookings Dashboard'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF57C00),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF57C00).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildDatePickerSection(),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (selectedDate != null) _buildBusSelectionGrid(),
                      if (selectedBusId != null) _buildBusDetailsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDate == null
                  ? 'Select a travel date'
                  : DateFormat('EEE, MMM d, yyyy').format(selectedDate!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: _pickDate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'SELECT DATE',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusSelectionGrid() {
    Timestamp selectedTimestamp = Timestamp.fromDate(selectedDate!);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('buses')
          .where('date', isEqualTo: selectedTimestamp)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching buses'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No buses available for this date'));
        }

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.2,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            bool isSelected = doc.id == selectedBusId;

            return GestureDetector(
              onTap: () {
                _bookingsSubscription?.cancel();
                _busSubscription?.cancel();
                setState(() {
                  selectedBusId = doc.id;
                  bookedSeats.clear();
                  busMetrics = {
                    'bookedSeats': 0,
                    'availableSeats': data['seatCount'] ?? 20,
                    'revenue': 0.0,
                    'confirmedPassengers': 0,
                    'totalPassengers': 0
                  };
                  locationPassengers.clear();
                  showLocationDetails = false;
                });
                _setupBusListener(doc.id);
                _setupBookingsListener(doc.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF57C00).withOpacity(0.2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFF57C00)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_bus,
                              color: isSelected
                                  ? const Color(0xFFF57C00)
                                  : Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['busName'] ?? 'No Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSelected
                                    ? const Color(0xFFF57C00)
                                    : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildBusInfoItem(
                          Icons.schedule, data['departureTime'] ?? "N/A"),
                      _buildBusInfoItem(Icons.airline_seat_recline_normal,
                          '${data['seatCount'] ?? 20} seats'),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57C00),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'SELECTED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBusInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildBusDetailsSection() {
    if (selectedBusId == null) return const SizedBox.shrink();

    return Column(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Color(0xFFF57C00),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFFF57C00),
                    tabs: [
                      Tab(text: 'Metrics'),
                      Tab(text: 'Passengers'),
                      Tab(text: 'Seats'),
                    ],
                  ),
                  SizedBox(
                    height: 120,
                    child: TabBarView(
                      children: [
                        _buildMetricsTab(),
                        _buildPassengersTab(),
                        _buildSeatsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (locationPassengers.isNotEmpty)
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Passenger Locations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: locationPassengers.keys.map((location) {
                      final pickupCount = locationPassengers[location]!
                          .where((p) =>
                              p['pickupLocation'].toString().toLowerCase() ==
                              location.toLowerCase())
                          .length;
                      final dropCount = locationPassengers[location]!
                          .where((p) =>
                              p['dropLocation'].toString().toLowerCase() ==
                              location.toLowerCase())
                          .length;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedLocation = location;
                            showLocationDetails = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selectedLocation == location
                                ? const Color(0xFFF57C00).withOpacity(0.2)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedLocation == location
                                  ? const Color(0xFFF57C00)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                location.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedLocation == location
                                      ? const Color(0xFFF57C00)
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildMiniCountBadge(
                                      pickupCount, Colors.green),
                                  const SizedBox(width: 4),
                                  _buildMiniCountBadge(dropCount, Colors.blue),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        if (showLocationDetails && selectedLocation != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _buildLocationPassengerDetails(),
          ),
      ],
    );
  }

  Widget _buildMiniCountBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricsTab() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricCircle(
            label: 'Booked',
            value: busMetrics['bookedSeats'] ?? 0,
            color: Colors.red,
          ),
          _buildMetricCircle(
            label: 'Available',
            value: busMetrics['availableSeats'] ?? 0,
            color: Colors.green,
          ),
          _buildMetricCircle(
            label: 'Revenue',
            value: busMetrics['revenue']?.toStringAsFixed(2) ?? '0.00',
            color: Colors.orange,
            isCurrency: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCircle({
    required String label,
    required dynamic value,
    required Color color,
    bool isCurrency = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              isCurrency ? '\$$value' : value.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPassengersTab() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPassengerStat(
              'Total', busMetrics['totalPassengers'] ?? 0, Icons.group),
          _buildPassengerStat('Confirmed',
              busMetrics['confirmedPassengers'] ?? 0, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildPassengerStat(String label, int value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFF57C00), size: 24),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSeatsTab() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${busMetrics['bookedSeats'] ?? 0} / $totalSeats',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (busMetrics['bookedSeats'] ?? 0) / totalSeats,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              (busMetrics['bookedSeats'] ?? 0) / totalSeats > 0.8
                  ? Colors.red
                  : const Color(0xFFF57C00),
            ),
            minHeight: 10,
          ),
          const SizedBox(height: 8),
          Text(
            'Seats Occupied',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPassengerDetails() {
    if (selectedLocation == null ||
        locationPassengers[selectedLocation] == null) {
      return const Center(child: Text('No location selected'));
    }

    final passengers = locationPassengers[selectedLocation]!;
    final pickupPassengers = passengers
        .where((p) =>
            p['pickupLocation'].toString().toLowerCase() ==
            selectedLocation!.toLowerCase())
        .toList();
    final dropPassengers = passengers
        .where((p) =>
            p['dropLocation'].toString().toLowerCase() ==
            selectedLocation!.toLowerCase())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location: ${selectedLocation!.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPassengerCountCard(
                      'BOARDING',
                      pickupPassengers.length,
                      Colors.green,
                    ),
                    _buildPassengerCountCard(
                      'DROPPING',
                      dropPassengers.length,
                      Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (pickupPassengers.isNotEmpty)
          _buildPassengerList('Boarding Passengers', pickupPassengers),
        if (dropPassengers.isNotEmpty)
          _buildPassengerList('Dropping Passengers', dropPassengers),
      ],
    );
  }

  Widget _buildPassengerCountCard(String title, int count, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerList(
      String title, List<Map<String, dynamic>> passengers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: passengers.length,
          itemBuilder: (context, index) {
            final passenger = passengers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              child: ListTile(
                title: Text(passenger['name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seats: ${passenger['seatNumbers'].join(', ')}'),
                    if (passenger['phone'] != null)
                      Text('Phone: ${passenger['phone']}'),
                    if (passenger['amount'] != null)
                      Text('Amount: \$${passenger['amount']}'),
                  ],
                ),
                trailing:
                    passenger['pickupLocation'].toString().toLowerCase() ==
                            selectedLocation!.toLowerCase()
                        ? const Chip(
                            label: Text('Boarding'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : const Chip(
                            label: Text('Dropping'),
                            backgroundColor: Colors.blue,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                onTap: () {
                  _showPassengerDetails(passenger);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class EditBookingPage extends StatelessWidget {
  final String bookingId;

  const EditBookingPage({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Booking')),
      body: Center(child: Text('Editing booking $bookingId')),
    );
  }
}
