// ignore_for_file: use_build_context_synchronously

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class PermissionHandler {
  static Future<bool> checkLocationPermission(BuildContext context) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Request to enable location services
        serviceEnabled = await Geolocator.openLocationSettings();
        if (!serviceEnabled) {
          _showPermissionDialog(context,
              'Location services are disabled. Please enable them to continue.');
          return false;
        }
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          _showPermissionDialog(
              context, 'Location permissions are required to track the bus.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDialog(context,
            'Location permissions are permanently denied. Please enable them in app settings.');
        return false;
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Location permission error: $e');
      _showPermissionDialog(
          context, 'An error occurred while checking location permissions.');
      return false;
    }
  }

  static void _showPermissionDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
}
