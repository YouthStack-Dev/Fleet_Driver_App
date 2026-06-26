import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/auth_provider.dart';

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
    
    final currentUser = auth.currentUser;
    final String? currentTenantId = currentUser?['tenant_id']?.toString() ?? currentUser?['user']?['tenant_id']?.toString();
    final String? currentVendorId = currentUser?['vendor_id']?.toString() ?? currentUser?['user']?['driver']?['vendor_id']?.toString();
    final String currentKey = (currentTenantId != null && currentVendorId != null) ? '$currentVendorId:$currentTenantId' : '';

    return Scaffold(
      backgroundColor: const Color(0xFF051424),
      appBar: AppBar(
        title: Text(
          'Switch Company',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFD4E4FA)),
        ),
        backgroundColor: const Color(0xFF122131),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD4E4FA)),
      ),
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
          
          _isLoading 
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7CFF),
                  strokeWidth: 3,
                ),
              )
            : accounts.isEmpty 
                ? _buildEmptyState()
                : AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final vendorName = account['vendor_name'] ?? account['vendor']?['name'] ?? 'Unknown';
                        final tenantName = account['tenant_name'] ?? account['tenant']?['name'] ?? 'Unknown';
                        final vendorId = account['vendor_id']?.toString() ?? account['vendor']?['id']?.toString();
                        final tenantId = account['tenant_id']?.toString() ?? account['tenant']?['id']?.toString();
                        final key = '${vendorId ?? ''}:${tenantId ?? ''}';
                        
                        final isCurrent = key == currentKey;
                        final isSelected = _selectedKey == key;
                        final isActive = account['device_active'] == true || account['device_active'] == 1;

                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: _buildAccountCard(
                                account: account,
                                vendorName: vendorName,
                                tenantName: tenantName,
                                vendorId: vendorId ?? '',
                                tenantId: tenantId ?? '',
                                keyStr: key,
                                isCurrent: isCurrent,
                                isSelected: isSelected,
                                isActive: isActive,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required dynamic account,
    required String vendorName,
    required String tenantName,
    required String vendorId,
    required String tenantId,
    required String keyStr,
    required bool isCurrent,
    required bool isSelected,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: (_isLoading || !isActive) ? null : () => _handleSwitch(context, account, keyStr, isCurrent),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF122131),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrent 
                  ? const Color(0xFF10B981).withOpacity(0.5) 
                  : (isSelected ? const Color(0xFF2E7CFF) : const Color(0xFF334155)),
              width: isCurrent || isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isCurrent 
                        ? const Color(0xFF10B981) 
                        : (isActive ? const Color(0xFF2E7CFF) : const Color(0xFF334155)),
                    width: 5,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Leading Icon Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCurrent 
                          ? const Color(0xFF10B981).withOpacity(0.12) 
                          : (isActive ? const Color(0xFF2E7CFF).withOpacity(0.12) : const Color(0xFF1E293B)),
                      shape: BoxShape.circle
                    ),
                    child: Icon(
                      Icons.business_rounded, 
                      color: isCurrent 
                          ? const Color(0xFF10B981) 
                          : (isActive ? const Color(0xFF2E7CFF) : const Color(0xFF64748B)),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Text details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vendorName, 
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 15,
                                  color: isActive ? const Color(0xFFD4E4FA) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                child: Text(
                                  'Current', 
                                  style: GoogleFonts.poppins(
                                    color: Colors.white, 
                                    fontSize: 9, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tenantName, 
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFC2C6D7), 
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'TID: $tenantId  |  VID: $vendorId', 
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF8C90A0), 
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? const Color(0xFFD1FAE5) 
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Inactive',
                                style: GoogleFonts.poppins(
                                  color: isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                  fontSize: 9, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Trailing indicator / chevron
                  if (isSelected && _isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: SizedBox(
                        width: 18, 
                        height: 18, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7CFF)),
                      ),
                    )
                  else if (!isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded, 
                        color: isActive ? const Color(0xFF2E7CFF) : const Color(0xFF334155),
                        size: 13,
                      ),
                    )
                ],
              ),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF122131),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.business_outlined, size: 56, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Text(
              'No alternate accounts',
              style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.bold, color: const Color(0xFFD4E4FA)),
            ),
            const SizedBox(height: 8),
            Text(
              'You are not registered under any other operators.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: const Color(0xFFC2C6D7), fontSize: 13.5, height: 1.4),
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
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                child: Text(
                  'Go Back',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSwitch(BuildContext itemContext, dynamic account, String key, bool isCurrent) async {
    if (isCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are currently active in ${account['vendor_name'] ?? 'this company'}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      final auth = Provider.of<AuthProvider>(context, listen: false);
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

          await showDialog(
             context: context,
             barrierDismissible: false,
             builder: (ctx) => AlertDialog(
               backgroundColor: const Color(0xFF122131),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               title: Row(
                 children: [
                   const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                   const SizedBox(width: 8),
                   Text(
                     'Company Switched', 
                     style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFFD4E4FA)),
                   ),
                 ],
               ),
               content: Text(
                 'Successfully switched active session to ${account['vendor_name'] ?? account['vendor']?['name'] ?? 'selected operator'}.',
                 style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFFC2C6D7), height: 1.4),
               ),
               actions: [
                 TextButton(
                   onPressed: () {
                     Navigator.of(ctx).pop(); 
                   },
                   child: Text(
                     'OK', 
                     style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2E7CFF)),
                   ),
                 )
               ],
             )
           );
           
           print('UI: Dialog result received. Navigating to Home...');
           if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
           }
        }
        return; 
      } else {
        if (mounted) {
           setState(() {
             _isLoading = false;
             _selectedKey = null;
           });
           
           try {
             ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(result['error'] ?? 'Switch failed', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
             SnackBar(
               content: Text('Error: $e', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
               backgroundColor: const Color(0xFFEF4444),
               behavior: SnackBarBehavior.floating,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             ),
          );
        } catch (_) {}
      }
    }
  }
}
