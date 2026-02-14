import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class VendorSelectScreen extends StatefulWidget {
  final String licenseNumber;

  const VendorSelectScreen({super.key, required this.licenseNumber});

  @override
  State<VendorSelectScreen> createState() => _VendorSelectScreenState();
}

class _VendorSelectScreenState extends State<VendorSelectScreen> {
  bool _isLoading = false;

  Future<void> _handleSelect(Map<String, dynamic> vendor) async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.selectTenant(vendor, widget.licenseNumber);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
         Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (mounted) {
        final errorMsg = result['error'] ?? 'Selection failed';
        
        if (errorMsg.toString().contains('DEVICE_NOT_AUTHORIZED') || errorMsg.toString().contains('not activated')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Device Not Activated'),
              content: const Text('Your device is not activated. Please contact your administrator to activate this device before logging in.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg, style: GoogleFonts.poppins())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = Provider.of<AuthProvider>(context).vendors;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Select Company', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vendors.length,
              itemBuilder: (context, index) {
                final vendor = vendors[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.business, color: Colors.blue),
                    ),
                    title: Text(
                      vendor['vendor_name'] ?? 'Unknown Vendor',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      vendor['tenant_name'] ?? 'Unknown Tenant',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _handleSelect(vendor),
                  ),
                );
              },
            ),
    );
  }
}
