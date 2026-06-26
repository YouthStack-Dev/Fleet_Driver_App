import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _licenseController = TextEditingController();
  bool _isLoading = false;
  bool _isChecking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
       return const Scaffold(
         backgroundColor: Color(0xFF051424),
         body: Center(child: CircularProgressIndicator(color: Color(0xFF2E7CFF), strokeWidth: 3)),
       );
    }
    
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
                color: const Color(0xFF2E7CFF).withOpacity(0.06),
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
                color: const Color(0xFF34C759).withOpacity(0.04),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo container
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7CFF).withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2E7CFF).withOpacity(0.15), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.directions_car_rounded,
                        size: 42,
                        color: Color(0xFF2E7CFF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // App Title
                  Text(
                    'MLT DRIVER',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: const Color(0xFFD4E4FA),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Verification Mode',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13, 
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFC2C6D7),
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  // License Input
                  Text(
                    'License Number (DL)',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD4E4FA).withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF122131),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF334155),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _licenseController,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFD4E4FA),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: const Color(0xFF2E7CFF),
                      decoration: InputDecoration(
                        hintText: 'Enter your license number',
                        hintStyle: GoogleFonts.poppins(
                          color: const Color(0xFFC2C6D7).withOpacity(0.4),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF2E7CFF), size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action Button
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Color(0xFF2E7CFF)),
                    )
                  else
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7CFF), Color(0xFF1A67F5)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7CFF).withOpacity(0.24),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          'VERIFY DEVICE', 
                          style: GoogleFonts.poppins(
                            fontSize: 14, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB4AB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFB4AB).withOpacity(0.2)),
                        ),
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFB4AB),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedWithVendorSelection(AuthProvider auth, String licenseNumber, {bool replace = true}) async {
    if (auth.vendors.isEmpty) {
      if (mounted) {
        if (replace) {
          Navigator.pushReplacementNamed(context, '/vendor-select', arguments: licenseNumber);
        } else {
          Navigator.pushNamed(context, '/vendor-select', arguments: licenseNumber);
        }
      }
      return;
    }

    if (auth.vendors.length == 1) {
      final singleVendor = auth.vendors.first;
      setState(() => _isLoading = true);
      
      final result = await auth.selectTenant(singleVendor, licenseNumber);
      
      if (mounted) setState(() => _isLoading = false);

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        if (mounted) {
          if (replace) {
            Navigator.pushReplacementNamed(context, '/vendor-select', arguments: licenseNumber);
          } else {
            Navigator.pushNamed(context, '/vendor-select', arguments: licenseNumber);
          }
        }
      }
    } else {
      if (mounted) {
        if (replace) {
          Navigator.pushReplacementNamed(context, '/vendor-select', arguments: licenseNumber);
        } else {
          Navigator.pushNamed(context, '/vendor-select', arguments: licenseNumber);
        }
      }
    }
  }

  void _showWarningDialog(String message) {
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
              'Verification Warning', 
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, 
                fontSize: 17, 
                color: const Color(0xFFD4E4FA),
              )
            ),
          ],
        ),
        content: Text(
          message,
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
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final result = await auth.verifyDevice(_licenseController.text);

      if (result['success'] == true) {
         await PermissionService().checkAndRequestAllPermissions(context);

         if (mounted) {
           await _proceedWithVendorSelection(auth, _licenseController.text);
         }
      } else {
        if (mounted) {
          final errorMsg = result['error']?.toString() ?? result['message']?.toString() ?? 'Verification failed';
          setState(() {
            _error = errorMsg;
          });
          _showWarningDialog(errorMsg);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _showWarningDialog(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
