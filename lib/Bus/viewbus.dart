// ignore_for_file: library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ViewBusesPage extends StatefulWidget {
  const ViewBusesPage({super.key});

  @override
  _ViewBusesPageState createState() => _ViewBusesPageState();
}

class _ViewBusesPageState extends State<ViewBusesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Buses')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: _selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                        : 'Select Date',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _selectedDate != null
                    ? _firestore
                        .collection('buses')
                        .where('date',
                            isEqualTo: Timestamp.fromDate(_selectedDate!))
                        .snapshots()
                    : _firestore.collection('buses').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No buses found for the selected date.'));
                  }
                  final buses = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: buses.length,
                    itemBuilder: (context, index) {
                      final bus = buses[index];
                      final busId = bus.id;
                      final from = bus['from'] ?? 'N/A';
                      final to = bus['to'] ?? 'N/A';
                      final busName = bus['busName'] ?? 'N/A';
                      final busNumber = bus['busNumber'] ?? 'N/A';
                      final date = bus['date'] != null
                          ? DateFormat('yyyy-MM-dd')
                              .format((bus['date'] as Timestamp).toDate())
                          : 'N/A';
                      final ticketPrice = bus['ticketPrice'] ?? 0.0;

                      return ListTile(
                        title: Text('Bus ID: $busId'),
                        subtitle: Text(
                            'Bus Name: $busName\nBus Number: $busNumber\nFrom: $from\nTo: $to\nDate: $date\nTicket Price: \$${ticketPrice.toStringAsFixed(2)}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
