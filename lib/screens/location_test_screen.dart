import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  String _log = "Logs will appear here...\n";
  bool _testing = false;

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _log += "${DateTime.now().toIso8601String().substring(11, 19)}: $message\n";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('🧪 Location Testing')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusCard(locationProvider),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => locationProvider.toggleTracking(),
                  icon: Icon(locationProvider.isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(locationProvider.isTracking ? 'Stop Tracking' : 'Start Tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: locationProvider.isTracking ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _testFirebaseConnection,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Test Firebase (SDK + HTTP)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _testGps,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Test GPS Hardware'),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Logs", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              color: Colors.black87,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(LocationProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Status:", style: TextStyle(fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(provider.isTracking ? "ACTIVE" : "INACTIVE"),
                  backgroundColor: provider.isTracking ? Colors.green[100] : Colors.red[100],
                  labelStyle: TextStyle(color: provider.isTracking ? Colors.green : Colors.red),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testFirebaseConnection() async {
    _addLog("🧪 Starting Firebase Test...");
    setState(() => _testing = true);
    
    try {
      final result = await FirebaseService().updateDriverLocation(
        tenantId: 'TEST_TENANT', 
        vendorId: 'TEST_VENDOR', 
        driverId: 'TEST_DRIVER_FLUTTER', 
        latitude: 0.0, 
        longitude: 0.0,
        additionalData: {'test': true}
      );
      
      if (result['success']) {
        _addLog("✅ Firebase Success via ${result['method']}");
      } else {
        _addLog("❌ Firebase Failed: ${result['error']}");
      }
    } catch (e) {
      _addLog("❌ Error: $e");
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _testGps() async {
     _addLog("📍 Requesting GPS Location...");
     try {
       final pos = await LocationService().checkPermission() 
           ? await Provider.of<LocationProvider>(context, listen: false).getCurrentLocation()
           : null;
           
       if (pos != null) {
         _addLog("✅ GPS Success: ${pos.latitude}, ${pos.longitude}");
       } else {
         _addLog("❌ GPS Failed: Permission denied or service disabled");
       }
     } catch (e) {
       _addLog("❌ GPS Error: $e");
     }
  }
}
