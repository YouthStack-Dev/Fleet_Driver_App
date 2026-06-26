import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final userData = user ?? {};
    final driver = userData['driver'] ?? userData['user']?['driver'] ?? {};
    final tenant = userData['tenant'] ?? userData['user']?['tenant'] ?? {};
    
    return Scaffold(
      backgroundColor: const Color(0xFF051424),
      appBar: AppBar(
        title: Text(
          'My Profile', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFD4E4FA))
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF122131),
        foregroundColor: const Color(0xFFD4E4FA),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD4E4FA)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(driver, tenant),
            
            _buildSection(
              context, 
              title: 'Personal Information', 
              icon: Icons.person_outline_rounded,
              children: [
                _buildInfoRow('Email', driver['email']),
                _buildInfoRow('Phone', driver['phone'] ?? driver['mobile_number']),
                _buildInfoRow('Gender', driver['gender']),
                _buildInfoRow('Date of Birth', driver['date_of_birth']),
                _buildInfoRow('Date of Joining', driver['date_of_joining']),
              ],
            ),
            
            _buildSection(
              context, 
              title: 'Address Info', 
              icon: Icons.map_outlined,
              children: [
                _buildInfoRow('Current Address', driver['current_address']),
                _buildInfoRow('Permanent Address', driver['permanent_address']),
              ],
            ),
            
            _buildSection(
              context, 
              title: 'License & Identification', 
              icon: Icons.badge_outlined,
              children: [
                _buildInfoRow('License Number', driver['license_number']),
                _buildInfoRow('License Expiry', driver['license_expiry_date']),
                _buildInfoRow('Badge Number', driver['badge_number']),
                _buildInfoRow('Badge Expiry', driver['badge_expiry_date']),
                _buildInfoRow('Alt ID Type', driver['alt_govt_id_type']),
                _buildInfoRow('Alt ID Number', driver['alt_govt_id_number']),
              ],
            ),
            
            _buildVerificationSection(context, driver),
            
            _buildSection(
              context, 
              title: 'Company Information', 
              icon: Icons.business_outlined,
              children: [
                _buildInfoRow('Company', tenant['name']),
                _buildInfoRow('Tenant ID', tenant['tenant_id']?.toString()),
                _buildInfoRow('Address', tenant['address']),
                _buildInfoRow('Induction Date', driver['induction_date']),
              ],
            ),
            
            _buildSection(
              context, 
              title: 'Settings & Actions', 
              icon: Icons.settings_outlined,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pushNamed(context, '/switch-account');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7CFF).withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF2E7CFF).withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2E7CFF), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Switch Company', 
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFFD4E4FA))
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toggle between your assigned corporate fleet entities', 
                                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFC2C6D7))
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF334155)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await auth.logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Log Out', 
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFFEF4444))
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign out of your active session securely', 
                                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFC2C6D7))
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF334155)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> driver, Map<String, dynamic> tenant) {
    final name = driver['name'] ?? 'Driver';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final code = driver['code'] ?? '';
    final tenantName = tenant['name'] ?? '';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          // Profile Avatar with Ring glow
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2E7CFF).withOpacity(0.2),
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F172A),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFF122131),
                backgroundImage: driver['photo_url'] != null ? NetworkImage(driver['photo_url']) : null,
                child: driver['photo_url'] == null 
                    ? Text(
                        initial, 
                        style: GoogleFonts.poppins(
                          fontSize: 36, 
                          fontWeight: FontWeight.bold, 
                          color: const Color(0xFF2E7CFF),
                        )
                      ) 
                    : null,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Driver Name
          Text(
            name, 
            style: GoogleFonts.poppins(
              fontSize: 21, 
              fontWeight: FontWeight.bold, 
              color: const Color(0xFFD4E4FA),
            )
          ),
          
          const SizedBox(height: 8),
          
          // Driver Code Badge
          if (code.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7CFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2E7CFF).withOpacity(0.2)),
              ),
              child: Text(
                code, 
                style: GoogleFonts.poppins(
                  fontSize: 11.5, 
                  fontWeight: FontWeight.bold, 
                  color: const Color(0xFFD4E4FA),
                  letterSpacing: 0.5
                )
              ),
            ),
            
          if (tenantName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tenantName, 
              style: GoogleFonts.poppins(
                fontSize: 13, 
                color: const Color(0xFFC2C6D7),
                fontWeight: FontWeight.w500
              )
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF122131),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2E7CFF), size: 20),
              const SizedBox(width: 8),
              Text(
                title, 
                style: GoogleFonts.poppins(
                  fontSize: 15.5, 
                  fontWeight: FontWeight.bold, 
                  color: const Color(0xFFD4E4FA)
                )
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(thickness: 1.0, color: Color(0xFF334155)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2, 
            child: Text(
              label, 
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFC2C6D7), fontWeight: FontWeight.w500)
            )
          ),
          Expanded(
            flex: 3, 
            child: Text(
              value ?? 'N/A', 
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFD4E4FA)), 
              textAlign: TextAlign.right
            )
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection(BuildContext context, Map<String, dynamic> driver) {
    return _buildSection(
      context, 
      title: 'Verification Status', 
      icon: Icons.verified_user_outlined,
      children: [
        _buildDocRow('Background Verification', driver['bg_verify_status'], driver['bg_expiry_date']),
        _buildDocRow('Police Verification', driver['police_verify_status'], driver['police_expiry_date']),
        _buildDocRow('Medical Verification', driver['medical_verify_status'], driver['medical_expiry_date']),
        _buildDocRow('Training Verification', driver['training_verify_status'], driver['training_expiry_date']),
        _buildDocRow('Eye Test', driver['eye_verify_status'], driver['eye_expiry_date']),
      ],
    );
  }

  Widget _buildDocRow(String label, String? status, String? expiry) {
    Color badgeTextColor = Colors.grey;
    Color badgeBgColor = const Color(0xFF1E293B);
    IconData statusIcon = Icons.help_outline;

    if (status == 'Approved') {
      badgeTextColor = const Color(0xFF10B981);
      badgeBgColor = const Color(0xFF10B981).withOpacity(0.12);
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'Pending') {
      badgeTextColor = const Color(0xFFF59E0B);
      badgeBgColor = const Color(0xFFF59E0B).withOpacity(0.12);
      statusIcon = Icons.hourglass_empty;
    } else if (status == 'Rejected' || status == 'Expired') {
      badgeTextColor = const Color(0xFFEF4444);
      badgeBgColor = const Color(0xFFEF4444).withOpacity(0.12);
      statusIcon = Icons.error_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFC2C6D7), fontWeight: FontWeight.w500)
            )
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeTextColor.withOpacity(0.3), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: badgeTextColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      status ?? 'N/A', 
                      style: GoogleFonts.poppins(color: badgeTextColor, fontSize: 11, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
              if (expiry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 2),
                  child: Text('Exp: $expiry', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF8C90A0), fontWeight: FontWeight.w500)),
                ),
            ],
          )
        ],
      ),
    );
  }
}
