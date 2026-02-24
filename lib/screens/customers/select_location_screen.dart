import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/runtime_permission_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SelectLocationScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final Future<bool> Function(LatLng)? onSaveLocation;

  const SelectLocationScreen({Key? key, this.initialLocation, this.onSaveLocation}) : super(key: key);

  @override
  _SelectLocationScreenState createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLocationLoading = true;
  String? _errorMessage;
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _pendingMoveToCurrentLocation = false;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _getCurrentLocation();
    } catch (e) {
      _handleLocationError('Failed to initialize location: ${e.toString()}');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _errorMessage = null;
    });

    if (widget.initialLocation != null) {
      setState(() {
        _currentLocation = widget.initialLocation;
        _isLocationLoading = false;
      });

      if (_mapReady) {
        _mapController.move(_currentLocation!, 15.0);
      } else {
        _pendingMoveToCurrentLocation = true;
      }
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationError('Location services are disabled. Please enable them in settings.');
        return;
      }

      final hasLocationPermission = await RuntimePermissionService.requestLocationPermission(context);
      if (!hasLocationPermission) {
        _handleLocationError('Location permission is required to use this feature.');
        return;
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );

        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLocationLoading = false;
          _errorMessage = null;
        });

        if (_mapReady && _currentLocation != null) {
          _mapController.move(_currentLocation!, 15.0);
        } else if (_currentLocation != null) {
          _pendingMoveToCurrentLocation = true;
        }
      } on TimeoutException {
        _handleLocationError('Location request timed out. Please try again.');
      } catch (e) {
        _handleLocationError('Unable to get location: ${e.toString()}');
      }
    } catch (e) {
      _handleLocationError('Unable to get location: ${e.toString()}');
    }
  }

  void _handleLocationError(String message) {
    setState(() {
      _isLocationLoading = false;
      _errorMessage = message;
    });
  }

  Future<void> _recenterMap() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationError('Location services are disabled');
        return;
      }

      final hasLocationPermission = await RuntimePermissionService.requestLocationPermission(context);
      if (!hasLocationPermission) {
        _handleLocationError('Location permission is required to use this feature.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      final deviceLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = deviceLocation;
        _isLocationLoading = false;
      });

      if (_mapReady) {
        _mapController.move(deviceLocation, 15.0);
      }
    } catch (e) {
      _handleLocationError('Failed to get current location: ${e.toString()}');
    }
  }

  void _onMapReady() {
    setState(() {
      _mapReady = true;
    });
    if (_pendingMoveToCurrentLocation && _currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
      _pendingMoveToCurrentLocation = false;
    }
  }

  void _retryLocation() {
    _getCurrentLocation();
  }

  Future<void> _confirmLocation() async {
    if (_selectedLocation == null || widget.onSaveLocation == null) return;
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    bool success = false;
    try {
      success = await widget.onSaveLocation!(_selectedLocation!);
    } catch (e) {
      success = false;
    }
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, _selectedLocation);
    } else {
      setState(() {
        _isSaving = false;
        _saveError = 'Failed to save location.';
      });
    }
  }

  void _showLocationHelp() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Location Help'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Tap anywhere on the map to select a location'),
            SizedBox(height: 8),
            Text('• Use the location button to center on your current position'),
            SizedBox(height: 8),
            Text('• Red marker shows your selected location'),
            SizedBox(height: 8),
            Text('• The other one shows your current location'),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: isDark ? 0 : 3,
              ),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        title: const Text('Select Location'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const HugeIcon(icon:HugeIcons.strokeRoundedArrowLeft01),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showLocationHelp,
            tooltip: 'Help',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLocationLoading)
            Container(
              color: colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoadingAnimationWidget.fourRotatingDots(
                      color: isDark ? Colors.white : theme.primaryColor,
                      size: 50,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Getting your location...',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorMessage != null && !_isLocationLoading)
            Container(
              color: colorScheme.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Location Error',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _retryLocation,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isLocationLoading && _errorMessage == null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? const LatLng(20, 0),
                initialZoom: _currentLocation != null ? 15.0 : 2.0,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                  });
                },
                onMapReady: _onMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mobo.billing',
                ),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : theme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.surface, width: 2),
                          ),
                          child: Icon(Icons.my_location, color: colorScheme.onPrimary, size: 24),
                        ),
                      ),
                    ],
                  ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.surface, width: 2),
                          ),
                          child: Icon(Icons.location_on, color: colorScheme.onError, size: 24),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          if (!_isLocationLoading && _errorMessage == null)
            Positioned(
              bottom: _selectedLocation != null ? 160 : 100,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'recenter',
                    mini: true,
                    onPressed: _currentLocation != null && _mapReady ? _recenterMap : null,
                    elevation: 0,
                    focusElevation: 0,
                    hoverElevation: 0,
                    highlightElevation: 0,
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'retry',
                    mini: true,
                    onPressed: _retryLocation,
                    elevation: 0,
                    focusElevation: 0,
                    hoverElevation: 0,
                    highlightElevation: 0,
                    child: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedLocation != null
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _confirmLocation,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              label: _isSaving ? const Text('Saving...') : const Text('Confirm Location'),
              icon: _isSaving ? null : const Icon(Icons.check),
            )
          : null,
    );
  }
}
