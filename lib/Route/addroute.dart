// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddRoutePage extends StatefulWidget {
  const AddRoutePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddRoutePageState createState() => _AddRoutePageState();
}

class _AddRoutePageState extends State<AddRoutePage> {
  final TextEditingController _routeNumberController = TextEditingController();
  final TextEditingController _fromCityController = TextEditingController();
  final TextEditingController _toCityController = TextEditingController();
  // ignore: prefer_final_fields
  List<TextEditingController> _cityControllers = [];

  final _formKey = GlobalKey<FormState>();

  void _addCityField() {
    setState(() {
      _cityControllers.add(TextEditingController());
    });
  }

  void _removeCityField(int index) {
    setState(() {
      _cityControllers[index].dispose();
      _cityControllers.removeAt(index);
    });
  }

  Future<void> _saveRoute() async {
    if (_formKey.currentState!.validate()) {
      List<String> citiesBetween =
          _cityControllers.map((c) => c.text.trim()).toList();

      Map<String, dynamic> routeData = {
        'routeNumber': _routeNumberController.text.trim(),
        'from': _fromCityController.text.trim(),
        'to': _toCityController.text.trim(),
        'citiesBetween': citiesBetween,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance
            .collection('bus_routes')
            .add(routeData);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Route added successfully!')));
        _clearForm();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving route: $e')));
      }
    }
  }

  void _clearForm() {
    _routeNumberController.clear();
    _fromCityController.clear();
    _toCityController.clear();
    setState(() {
      // ignore: avoid_function_literals_in_foreach_calls
      _cityControllers.forEach((controller) => controller.clear());
      _cityControllers.clear();
    });
  }

  @override
  void dispose() {
    _routeNumberController.dispose();
    _fromCityController.dispose();
    _toCityController.dispose();
    for (var controller in _cityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Route')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _routeNumberController,
                  decoration: const InputDecoration(labelText: 'Route Number'),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter route number' : null,
                ),
                TextFormField(
                  controller: _fromCityController,
                  decoration: const InputDecoration(labelText: 'From City'),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter starting city' : null,
                ),
                TextFormField(
                  controller: _toCityController,
                  decoration: const InputDecoration(labelText: 'To City'),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter destination city' : null,
                ),
                const SizedBox(height: 10),
                const Text('Cities Between:',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Column(
                  children: List.generate(_cityControllers.length, (index) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityControllers[index],
                            decoration:
                                InputDecoration(labelText: 'City ${index + 1}'),
                            validator: (value) =>
                                value!.isEmpty ? 'Enter city' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () => _removeCityField(index),
                        ),
                      ],
                    );
                  }),
                ),
                ElevatedButton(
                  onPressed: _addCityField,
                  child: const Text('Add City'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveRoute,
                  child: const Text('Save Route'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
