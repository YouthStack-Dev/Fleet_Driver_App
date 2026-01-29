import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF6C63FF)),
            accountName: Text(auth.driver?['name'] ?? 'Driver'),
            accountEmail: Text('Tenant: ${auth.tenantId} | Vendor: ${auth.vendorId}'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF6C63FF)),
            ),
            otherAccountsPictures: [
               IconButton(
                 icon: const Icon(Icons.close, color: Colors.white),
                 onPressed: () => Navigator.pop(context),
               )
            ],
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.purple),
            title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
               Navigator.pop(context);
               Navigator.pushNamed(context, '/profile');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined, color: Colors.orange), 
            title: const Text('My Schedules', style: TextStyle(fontWeight: FontWeight.w500)), 
            onTap: () {
               Navigator.pop(context);
               Navigator.pushReplacementNamed(context, '/home'); // RidesScreen
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.green),
            title: const Text('Switch Company', style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/switch-account');
            },
          ),
          
          // Spacer logic for ListView: we need to use a sized box or just ensure it's at end.
          // Since ListView scrolls, "bottom" is relative. We'll add a large gap or just place it.
          const SizedBox(height: 20), 
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await auth.logout();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
            ),
          )
        ],
      ),
    );
  }
}
