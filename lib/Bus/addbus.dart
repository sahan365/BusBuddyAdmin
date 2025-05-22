// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddBusPage extends StatefulWidget {
  const AddBusPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddBusPageState createState() => _AddBusPageState();
}

class _AddBusPageState extends State<AddBusPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _busIdController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _busNameController = TextEditingController();
  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _ticketPriceController = TextEditingController();
  final TextEditingController _seatCountController = TextEditingController();
  final TextEditingController _busRouteNumberController =
      TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<String> _suggestedCities = [];

  @override
  void initState() {
    super.initState();
    _busRouteNumberController.addListener(_onRouteNumberChanged);
  }

  @override
  void dispose() {
    _busRouteNumberController.removeListener(_onRouteNumberChanged);
    _busRouteNumberController.dispose();
    super.dispose();
  }

  Future<void> _onRouteNumberChanged() async {
    String routeNumber = _busRouteNumberController.text.trim();
    if (routeNumber.isNotEmpty) {
      try {
        DocumentSnapshot routeDoc = await FirebaseFirestore.instance
            .collection('routes')
            .doc(routeNumber)
            .get();

        if (routeDoc.exists) {
          List<dynamic> cities = routeDoc['cities'] ?? [];
          setState(() {
            _suggestedCities = List<String>.from(cities);
          });
        } else {
          setState(() {
            _suggestedCities = [];
          });
        }
      } on FirebaseException catch (e) {
        // ignore: avoid_print
        print('Firestore error: ${e.code} - ${e.message}');
        setState(() {
          _suggestedCities = [];
        });
      }
    } else {
      setState(() {
        _suggestedCities = [];
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  void _addBus() async {
    if (_formKey.currentState?.validate() ?? false) {
      String formattedTime = _selectedTime != null
          ? '${_selectedTime!.hour}:${_selectedTime!.minute}'
          : '';

      int seatCount = int.tryParse(_seatCountController.text) ?? 0;

      await FirebaseFirestore.instance.collection('buses').add({
        'busId': _busIdController.text,
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'routeNumber': _busRouteNumberController.text.trim(),
        'date':
            _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'busName': _busNameController.text,
        'busNumber': _busNumberController.text,
        'ticketPrice': double.tryParse(_ticketPriceController.text) ?? 0.0,
        'busTime': formattedTime,
        'seatCount': seatCount,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus added successfully')),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildToField() {
    if (_suggestedCities.isNotEmpty) {
      return DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'To (Destination)'),
        value: _suggestedCities.contains(_toController.text)
            ? _toController.text
            : null,
        items: _suggestedCities.map((city) {
          return DropdownMenuItem<String>(
            value: city,
            child: Text(city),
          );
        }).toList(),
        onChanged: (selectedCity) {
          setState(() {
            _toController.text = selectedCity ?? '';
          });
        },
        validator: (value) => value == null || value.isEmpty
            ? 'Please select a destination'
            : null,
      );
    } else {
      return TextFormField(
        controller: _toController,
        decoration: const InputDecoration(labelText: 'To (Destination)'),
        validator: (value) =>
            value!.isEmpty ? 'Please enter a destination' : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bus')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _busIdController,
                decoration: const InputDecoration(labelText: 'Bus ID'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a bus ID' : null,
              ),
              TextFormField(
                controller: _busNameController,
                decoration: const InputDecoration(labelText: 'Bus Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a bus name' : null,
              ),
              TextFormField(
                controller: _busRouteNumberController,
                decoration:
                    const InputDecoration(labelText: 'Bus Route Number'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter the route number' : null,
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _fromController,
                decoration: const InputDecoration(labelText: 'From'),
                validator: (value) => value!.isEmpty
                    ? 'Please enter the departure location'
                    : null,
              ),
              _buildToField(),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                          : '',
                    ),
                    decoration: const InputDecoration(labelText: 'Date'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please select a date' : null,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _selectTime(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _selectedTime != null
                          ? _selectedTime!.format(context)
                          : '',
                    ),
                    decoration: const InputDecoration(labelText: 'Bus Time'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please select a bus time' : null,
                  ),
                ),
              ),
              TextFormField(
                controller: _busNumberController,
                decoration: const InputDecoration(labelText: 'Bus Number'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter the bus number' : null,
              ),
              TextFormField(
                controller: _ticketPriceController,
                decoration: const InputDecoration(labelText: 'Ticket Price'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a ticket price' : null,
              ),
              TextFormField(
                controller: _seatCountController,
                decoration: const InputDecoration(labelText: 'Seat Count'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter the number of seats' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addBus,
                child: const Text('Add Bus'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
