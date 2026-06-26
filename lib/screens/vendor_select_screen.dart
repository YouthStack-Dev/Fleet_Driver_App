import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/auth_provider.dart';

class VendorSelectScreen extends StatefulWidget {
  final String licenseNumber;

  const VendorSelectScreen({super.key, required this.licenseNumber});

  @override
  State<VendorSelectScreen> createState() => _VendorSelectScreenState();
}

class _VendorSelectScreenState extends State<VendorSelectScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.vendors.length == 1) {
        final Map<String, dynamic> singleVendor = Map<String, dynamic>.from(authProvider.vendors.first);
        _handleSelect(singleVendor);
      }
    });
  }

  Future<void> _handleSelect(Map<String, dynamic> vendor) async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.selectTenant(vendor, widget.licenseNumber);

    if (mounted) setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
         Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } else {
      if (mounted) {
        final errorMsg = result['error'] ?? 'Selection failed';
        
        if (errorMsg.toString().contains('DEVICE_NOT_AUTHORIZED') || errorMsg.toString().contains('not activated')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF122131),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Device Not Activated', 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFFD4E4FA)),
                  ),
                ],
              ),
              content: Text(
                'Your device is not activated for this company. Please contact your fleet administrator to activate this device.',
                style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFFC2C6D7), height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK', 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2E7CFF)),
                  ),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = Provider.of<AuthProvider>(context).vendors;

    return Scaffold(
      backgroundColor: const Color(0xFF051424),
      body: Stack(
        children: [
          // Background glowing gradients
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7CFF).withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7CFF).withOpacity(0.03),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top back button
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 12),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFD4E4FA), size: 24),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ),
                
                // Top Header Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7CFF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2E7CFF).withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_rounded, size: 14, color: Color(0xFF2E7CFF)),
                            const SizedBox(width: 6),
                            Text(
                              'DL: ${widget.licenseNumber}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFD4E4FA),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Company',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4E4FA),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose the active corporate fleet you are driving for today.',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: const Color(0xFFC2C6D7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Vendors List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2E7CFF),
                            strokeWidth: 3,
                          ),
                        )
                      : vendors.isEmpty
                          ? _buildEmptyState()
                          : AnimationLimiter(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                itemCount: vendors.length,
                                itemBuilder: (context, index) {
                                  final vendor = vendors[index];
                                  final isActive = vendor['device_active'] == true || vendor['device_active'] == 1;
                                  return AnimationConfiguration.staggeredList(
                                    position: index,
                                    duration: const Duration(milliseconds: 375),
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: _buildVendorCard(vendor, isActive),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor, bool isActive) {
    final vendorName = vendor['vendor_name'] ?? 'Unknown Vendor';
    final tenantName = vendor['tenant_name'] ?? 'Unknown Tenant';
    final vendorId = vendor['vendor_id']?.toString() ?? 'N/A';
    final tenantId = vendor['tenant_id']?.toString() ?? 'N/A';

    return GestureDetector(
      onTap: (!isActive || _isLoading) ? null : () => _handleSelect(vendor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF122131),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? const Color(0xFF2E7CFF).withOpacity(0.15) : const Color(0xFF334155),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isActive ? const Color(0xFF2E7CFF) : const Color(0xFF334155),
                  width: 5,
                ),
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? const Color(0xFF2E7CFF).withOpacity(0.1) 
                        : const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    color: isActive ? const Color(0xFF2E7CFF) : const Color(0xFF64748B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Vendor details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendorName,
                        style: GoogleFonts.poppins(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: isActive ? const Color(0xFFD4E4FA) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tenantName,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: const Color(0xFFC2C6D7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'TID: $tenantId  |  VID: $vendorId',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: const Color(0xFF8C90A0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status Badge & Navigation Arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive 
                            ? const Color(0xFFD1FAE5) 
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isActive ? const Color(0xFF2E7CFF) : const Color(0xFF334155),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB4AB).withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFB4AB).withOpacity(0.15)),
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 64,
                color: Color(0xFFFFB4AB),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Operators Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD4E4FA),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This device/license is not registered under any fleet operators. Please contact support.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: const Color(0xFFC2C6D7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7CFF), Color(0xFF1A67F5)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Go Back',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
