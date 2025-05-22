// ignore_for_file: use_build_context_synchronously, use_key_in_widget_constructors, library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeleteBusesPage extends StatefulWidget {
  @override
  _DeleteBusesPageState createState() => _DeleteBusesPageState();
}

class _DeleteBusesPageState extends State<DeleteBusesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteBus(String busId) async {
    try {
      await _firestore.collection('buses').doc(busId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting bus: $e')));
    }
  }

  Future<void> _confirmDelete(String busId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this bus?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      _deleteBus(busId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Buses')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('buses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No buses available'));
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmDelete(busId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
