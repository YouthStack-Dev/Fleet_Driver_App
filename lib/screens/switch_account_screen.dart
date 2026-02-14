import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/navigation_service.dart';

class SwitchAccountScreen extends StatefulWidget {
  const SwitchAccountScreen({super.key});

  @override
  State<SwitchAccountScreen> createState() => _SwitchAccountScreenState();
}

class _SwitchAccountScreenState extends State<SwitchAccountScreen> {
  bool _isLoading = false;
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final accounts = auth.accounts;
    
    // Determine current account logic (if not explicitly stored in auth, we infer or use default)
    // Actually AuthProvider should know the authenticated account. 
    // In RN, it checks session.user_data.tenant_id/vendor_id.
    final currentUser = auth.currentUser;
    final String? currentTenantId = currentUser?['tenant_id']?.toString() ?? currentUser?['user']?['tenant_id']?.toString();
    final String? currentVendorId = currentUser?['vendor_id']?.toString() ?? currentUser?['user']?['driver']?['vendor_id']?.toString();
    final String currentKey = (currentTenantId != null && currentVendorId != null) ? '$currentVendorId:$currentTenantId' : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Switch Company')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : accounts.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final vendorName = account['vendor_name'] ?? account['vendor']?['name'] ?? 'Unknown';
                  final tenantName = account['tenant_name'] ?? account['tenant']?['name'] ?? 'Unknown';
                  final vendorId = account['vendor_id']?.toString() ?? account['vendor']?['id']?.toString();
                  final tenantId = account['tenant_id']?.toString() ?? account['tenant']?['id']?.toString();
                  final key = '$vendorId:$tenantId';
                  
                  final isCurrent = key == currentKey;
                  final isSelected = _selectedKey == key;

                  final isActive = account['device_active'] == true || account['device_active'] == 1;

                  return GestureDetector(
                    onTap: (_isLoading || !isActive) ? null : () => _handleSwitch(context, account, key, isCurrent),
                    child: Opacity(
                      opacity: isActive ? 1.0 : 0.6,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent 
                              ? Border.all(color: Colors.green, width: 2) 
                              : (isSelected ? Border.all(color: const Color(0xFF6C63FF), width: 2) : null),
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ]
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCurrent ? Colors.green.withOpacity(0.1) : (isActive ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                                shape: BoxShape.circle
                              ),
                              child: Icon(Icons.business, color: isCurrent ? Colors.green : (isActive ? const Color(0xFF6C63FF) : Colors.grey)),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(10)
                                        ),
                                        child: const Text('Current', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(tenantName, style: TextStyle(color: Colors.grey[600], fontSize: 13))
                                    ),
                                    // Status Badge
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (account['device_active'] == true || account['device_active'] == 1) 
                                            ? Colors.green.withOpacity(0.1) 
                                            : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: (account['device_active'] == true || account['device_active'] == 1) 
                                              ? Colors.green 
                                              : Colors.red,
                                          width: 0.5
                                        )
                                      ),
                                      child: Text(
                                        (account['device_active'] == true || account['device_active'] == 1) ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: (account['device_active'] == true || account['device_active'] == 1) 
                                              ? Colors.green 
                                              : Colors.red,
                                          fontSize: 10, 
                                          fontWeight: FontWeight.w600
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('TID: $tenantId | VID: $vendorId', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                              ],
                            ),
                          ),
                          if (isSelected && _isLoading)
                            const Padding(padding: EdgeInsets.only(left: 10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          else if (!isCurrent)
                            Icon(Icons.chevron_right, color: isActive ? Colors.grey : Colors.grey.withOpacity(0.5))
                        ],
                      ),
                    ),
                  ),
                );
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No other accounts found', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back'))
        ],
      ),
    );
  }

  Future<void> _handleSwitch(BuildContext itemContext, dynamic account, String key, bool isCurrent) async {
    if (isCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are currently active in ${account['vendor_name'] ?? 'this company'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedKey = key;
    });

    try {
      // Use this.context (State context) ensuring it's stable
      final auth = Provider.of<AuthProvider>(this.context, listen: false);
      print('UI: Calling switchCompany...');
      final result = await auth.switchCompany(account);
      print('UI: switchCompany result: $result');
      
      if (!mounted) {
        print('UI: Widget unmounted after switch');
        return;
      }

      if (result['success'] == true) {
        if (mounted) {
          setState(() { 
            _isLoading = false; 
          });

          // Ensure we use the screen's main context
          await showDialog(
             context: this.context,
             barrierDismissible: false,
             builder: (ctx) => AlertDialog(
               title: const Text('Success'),
               content: Text('Switched to ${account['vendor_name'] ?? account['vendor']?['name'] ?? 'selected company'}'),
               actions: [
                 TextButton(
                   onPressed: () {
                     Navigator.of(ctx).pop(); 
                   },
                   child: const Text('OK'),
                 )
               ],
             )
           );
           
           print('UI: Dialog result received. Navigating to Home...');
           if (mounted) {
              Navigator.of(this.context).pushNamedAndRemoveUntil('/home', (route) => false);
           }
        }
        return; 
      } else {
        // Failure: Stop loading FIRST
        if (mounted) {
           setState(() {
             _isLoading = false;
             _selectedKey = null;
           });
           
           try {
             ScaffoldMessenger.maybeOf(this.context)?.showSnackBar(
                SnackBar(content: Text(result['error'] ?? 'Switch failed'), backgroundColor: Colors.red),
             );
           } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedKey = null;
        });

        try {
          ScaffoldMessenger.maybeOf(this.context)?.showSnackBar(
             SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        } catch (_) {}
      }
    }
  }
}
