import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _licenseController = TextEditingController(text: 'LC123456');
  // Removed password controller
  bool _isLoading = false;
  bool _isChecking = true;
  // Removed _isObscure
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // 1. Check existing session
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Ensure init ran
    await auth.init(); 

    /* 
    // Per user request: "fix it to open every time from the login screen"
    // Disabling auto-redirect for persistent sessions. Users must see Login.
    if (auth.status == AuthStatus.authenticated) {
       if (mounted) Navigator.pushReplacementNamed(context, '/home'); // RidesScreen
       return;
    } 
    */
    
    // 2. Check temp session 
    // Commented out as per user request to always show login screen if not fully authenticated
    /* 
    if (auth.status == AuthStatus.tempAuthenticated) {
       if (mounted) Navigator.pushReplacementNamed(context, '/select-account');
       return;
    }
    */

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
       return const Scaffold(
         body: Center(child: CircularProgressIndicator()),
       );
    }
    
    return Scaffold(
      backgroundColor: Colors.white, // Changed from grey
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Driver Login',
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              // Shadow Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Shadow Border for License Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4), // Shadow position
                    ),
                  ],
                ),
                child: TextField(
                  controller: _licenseController,
                  decoration: InputDecoration(
                    labelText: 'License Number (DL) or Username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none, // Remove default border to emphasize shadow
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Removed Password Field
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: 120, // Smaller button width as per image
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3), // Blue color
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Rectangular
                    ),
                    child: const Text('VERIFY DEVICE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
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
      // Call verifyDevice instead of login
      final result = await auth.verifyDevice(_licenseController.text);

      if (result['success'] == true) {
         // Request permissions
         await PermissionService().checkAndRequestAllPermissions(context);

         if (mounted) {
           // Navigate to Vendor Selection Screen
           // Passing license number to the next screen
           Navigator.pushNamed(
             context, 
             '/vendor-select', 
             arguments: _licenseController.text
           );
         }
      } else {
        if (mounted) {
          setState(() {
            _error = result['error']?.toString() ?? result['message']?.toString() ?? 'Verification failed';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
