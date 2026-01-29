import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';

class SelectAccountScreen extends StatefulWidget {
  const SelectAccountScreen({super.key});

  @override
  State<SelectAccountScreen> createState() => _SelectAccountScreenState();
}

class _SelectAccountScreenState extends State<SelectAccountScreen> {
  bool _isLoading = false;
  String? _selectedKey; // vendorId:tenantId

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          )
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    // Auto-select logic
    if (auth.accounts.length == 1 && !_isLoading && _selectedKey == null) {
      final account = auth.accounts[0];
      final key = _getAccountKey(account);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           setState(() => _selectedKey = key);
           _handleAccountSelect(account);
        }
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Select Vendor / Tenant', 
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
          ),
        ),
        if (auth.driver != null)
           Container(
             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.grey[200],
               borderRadius: BorderRadius.circular(8)
             ),
             child: Row(
               children: [
                 const CircleAvatar(child: Icon(Icons.person)),
                 const SizedBox(width: 12),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(auth.driver?['name'] ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.bold)),
                     Text(auth.driver?['license_number'] ?? '', style: TextStyle(color: Colors.grey[600])),
                   ],
                 )
               ],
             ),
           ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: auth.accounts.length,
            itemBuilder: (context, index) {
              final account = auth.accounts[index];
              final vendorName = account['vendor_name'] ?? account['vendor']?['name'] ?? 'Unknown Vendor';
              final tenantName = account['tenant_name'] ?? account['tenant']?['name'] ?? 'Unknown Tenant';
              final key = _getAccountKey(account);
              
              return InkWell(
                onTap: () => setState(() => _selectedKey = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(tenantName, style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedKey == key ? Theme.of(context).primaryColor : Colors.grey,
                            width: 2
                          ),
                          color: _selectedKey == key ? Colors.white : Colors.transparent,
                        ),
                        child: _selectedKey == key 
                            ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle)))
                            : null,
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading || _selectedKey == null ? null : () {
                  final account = auth.accounts.firstWhere((a) => _getAccountKey(a) == _selectedKey);
                  _handleAccountSelect(account);
                },
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('CONTINUE WITH SELECTED ACCOUNT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getAccountKey(dynamic account) {
    final vendorId = account['vendor_id'] ?? account['vendor']?['id'];
    final tenantId = account['tenant_id'] ?? account['tenant']?['id'];
    return '$vendorId:$tenantId';
  }

  Future<void> _handleAccountSelect(dynamic account) async {
    // 1. Check Permissions
    final permStatus = await Permission.location.status;
    if (!permStatus.isGranted) {
      if (mounted) {
         final shouldRequest = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text('This app requires location access to track your trips and duties. Please grant location permission to continue.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Grant Access')),
              ],
            )
         );

         if (shouldRequest == true) {
            final result = await Permission.location.request();
            if (!result.isGranted) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied. Cannot login.')));
               return;
            }
         } else {
           return;
         }
      }
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final result = await auth.confirmLogin(account);
      
      if (mounted && result['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?.toString() ?? 'Selection failed')),
        );
        setState(() => _isLoading = false);
      } else if (mounted) {
        // Updated: Redirect to Home (RidesScreen) immediately on success.
        // matches RN navigation.replace('Schedules') logic which maps to RidesScreen
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
