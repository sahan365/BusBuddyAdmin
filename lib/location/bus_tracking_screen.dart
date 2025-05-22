// ignore_for_file: unused_field, library_private_types_in_public_api, unnecessary_null_comparison

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class BusTrackingScreen extends StatefulWidget {
  final String busId;
  final bool isDriver;

  const BusTrackingScreen({
    super.key,
    required this.busId,
    required this.isDriver,
    required String routeFrom,
    required String routeTo,
    required String routeNumber,
  });

  @override
  _BusTrackingScreenState createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  LatLng? _currentLocation;
  bool _isLoading = true;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<DocumentSnapshot>? _busLocationSubscription;
  Timer? _firestoreUpdateTimer;
  Position? _lastPosition;
  bool _isSharingStarted = false;

  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentLocation != null && _mapController != null) {
      _updateMarker();
    }
  }

  Future<void> _initializeLocation() async {
    try {
      await _checkLocationPermissions();

      if (widget.isDriver) {
      } else {
        await _startTrackingBus();
      }
    } on PlatformException catch (e) {
      debugPrint("Platform error: ${e.message}");
      _showError("Device error: ${e.message}");
    } catch (e) {
      debugPrint("Initialization error: $e");
      _showError("Failed to initialize");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied');
    }
  }

  Future<void> _startSharingLocation() async {
    try {
      Position position = await _getCurrentPosition();

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }

      await _updateFirestore(position);

      _locationSubscription ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
        _lastPosition = position;

        if (widget.isDriver && mounted && _mapController != null) {
          _mapController.animateCamera(
            CameraUpdate.newLatLng(
                LatLng(position.latitude, position.longitude)),
          );
        }
      });

      _firestoreUpdateTimer ??=
          Timer.periodic(const Duration(seconds: 3), (timer) async {
        try {
          Position currentPosition = await _getCurrentPosition();
          await _updateFirestore(currentPosition);

          debugPrint(
              "Updated location to Firestore: ${currentPosition.latitude}, ${currentPosition.longitude}");
        } catch (e) {
          debugPrint("Periodic update error: $e");
        }
      });
    } catch (e) {
      debugPrint("Sharing error: $e");
      rethrow;
    }
  }

  Future<Position> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Location timeout'),
      );
    } catch (e) {
      debugPrint("Position error: $e");
      rethrow;
    }
  }

  Future<void> _updateFirestore(Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection('bus_locations')
          .doc(widget.busId)
          .set({
        'location': GeoPoint(position.latitude, position.longitude),
        'timestamp': FieldValue.serverTimestamp(),
        'busId': widget.busId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore error: $e");
      throw Exception('Failed to update location');
    }
  }

  Future<void> _startTrackingBus() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('bus_locations')
          .doc(widget.busId)
          .get();

      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        GeoPoint location = data['location'] as GeoPoint;
        _updateLocationFromGeoPoint(location);
      }

      _busLocationSubscription = FirebaseFirestore.instance
          .collection('bus_locations')
          .doc(widget.busId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          var data = snapshot.data() as Map<String, dynamic>;
          GeoPoint location = data['location'] as GeoPoint;
          _updateLocationFromGeoPoint(location);
        }
      });
    } catch (e) {
      debugPrint("Tracking error: $e");
      rethrow;
    }
  }

  void _updateLocationFromGeoPoint(GeoPoint location) {
    _updateLocation(Position(
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    ));
  }

  void _updateLocation(Position position) {
    if (!mounted) return;

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    if (widget.isDriver && _mapController != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLng(_currentLocation!),
      );
    }
  }

  void _updateMarker() {
    if (_currentLocation == null) return;

    setState(() {
      _markers.clear();
      _markers.add(Marker(
        markerId: const MarkerId('busMarker'),
        position: _currentLocation!,
        infoWindow: InfoWindow(title: 'Bus ${widget.busId}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        draggable: false,
        flat: true,
        zIndex: 2,
      ));
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isDriver ? 'Share Location' : 'Track Bus ${widget.busId}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation ?? _defaultLocation,
                zoom: 15,
              ),
              markers: const <Marker>{},
              onMapCreated: (controller) {
                _mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onCameraMove: (CameraPosition position) {
                debugPrint(
                    "Camera moved to: ${position.target.latitude}, ${position.target.longitude}");
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            Position position = await _getCurrentPosition();
            await _updateFirestore(position);
            _mapController.animateCamera(
              CameraUpdate.newLatLng(
                  LatLng(position.latitude, position.longitude)),
            );
            _showError("Location shared successfully!");

            if (!_isSharingStarted) {
              _isSharingStarted = true;
              await _startSharingLocation();
            }
          } catch (e) {
            _showError("Failed to share location");
          }
        },
        child: const Icon(Icons.share_location),
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _busLocationSubscription?.cancel();
    _firestoreUpdateTimer?.cancel();
    super.dispose();
  }
}
