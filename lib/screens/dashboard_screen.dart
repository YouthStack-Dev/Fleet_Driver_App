import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/location_provider.dart';
import '../screens/location_test_screen.dart';
import '../screens/rides_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLT Dashboard'),
      ),
      drawer: const DashboardDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Welcome to your dashboard!'),
              const SizedBox(height: 20),
              
              _buildLocationCard(context),
              
              const SizedBox(height: 20),
              
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                       SizedBox(height: 10),
                       Text('Please use the Drawer (☰) to access more features.'),
                     ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Location Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Chip(
                  label: Text(locationProvider.isTracking ? "Active" : "Inactive"),
                  backgroundColor: locationProvider.isTracking ? Colors.green[100] : Colors.red[100],
                  labelStyle: TextStyle(color: locationProvider.isTracking ? Colors.green : Colors.red),
                )
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => locationProvider.toggleTracking(),
              style: ElevatedButton.styleFrom(
                backgroundColor: locationProvider.isTracking ? Colors.redAccent : Colors.blueAccent,
              ),
              child: Text(locationProvider.isTracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF6C63FF)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'MLT Driver App',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Flutter Version', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
               Navigator.pop(context);
               // TODO: Navigate to Profile
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('My Schedules'),
            onTap: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const RidesScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Location Test'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationTestScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              auth.logout();
            },
          ),
        ],
      ),
    );
  }
}
