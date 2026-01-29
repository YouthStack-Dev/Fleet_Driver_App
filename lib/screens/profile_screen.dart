import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    // Extract driver and tenant data safely
    // Structure: user_data -> user -> driver OR user_data -> driver (depending on API)
    // Based on RN: const driver = userData.user?.driver || {};
    final userData = user ?? {};
    final driver = userData['driver'] ?? userData['user']?['driver'] ?? {};
    final tenant = userData['tenant'] ?? userData['user']?['tenant'] ?? {};
    
    // For account-specific tenant info (sometimes in account object)
    // RN: const tenant = userData.user?.tenant || {}; (It seems to prefer user level)

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(driver, tenant),
            _buildSection(context, 'Personal Information', [
              _buildInfoRow('Email', driver['email']),
              _buildInfoRow('Phone', driver['phone'] ?? driver['mobile_number']), // 'phone' in RN, 'mobile_number' in some Flutter stubs
              _buildInfoRow('Gender', driver['gender']),
              _buildInfoRow('Date of Birth', driver['date_of_birth']),
              _buildInfoRow('Date of Joining', driver['date_of_joining']),
            ]),
            _buildSection(context, 'Address', [
              _buildInfoRow('Current Address', driver['current_address']),
              _buildInfoRow('Permanent Address', driver['permanent_address']),
            ]),
            _buildSection(context, 'License & Identification', [
              _buildInfoRow('License Number', driver['license_number']),
              _buildInfoRow('License Expiry', driver['license_expiry_date']),
              _buildInfoRow('Badge Number', driver['badge_number']),
              _buildInfoRow('Badge Expiry', driver['badge_expiry_date']),
              _buildInfoRow('Alt ID Type', driver['alt_govt_id_type']),
              _buildInfoRow('Alt ID Number', driver['alt_govt_id_number']),
            ]),
            _buildVerificationSection(context, driver),
            _buildSection(context, 'Company Information', [
              _buildInfoRow('Company', tenant['name']),
              _buildInfoRow('Tenant ID', tenant['tenant_id']?.toString()),
              _buildInfoRow('Address', tenant['address']),
              _buildInfoRow('Induction Date', driver['induction_date']),
            ]),
            const SizedBox(height: 30),
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
      color: const Color(0xFF6C63FF),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: driver['photo_url'] != null ? NetworkImage(driver['photo_url']) : null,
              child: driver['photo_url'] == null 
                  ? Text(initial, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))) 
                  : null,
            ),
          ),
          const SizedBox(height: 15),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          if (code.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(code, style: const TextStyle(fontSize: 16, color: Colors.white70)),
            ),
          if (tenantName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(tenantName, style: const TextStyle(fontSize: 14, color: Colors.white60)),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          const Divider(thickness: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),
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
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
          Expanded(
            flex: 3, 
            child: Text(
              value ?? 'N/A', 
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333)), 
              textAlign: TextAlign.right
            )
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection(BuildContext context, Map<String, dynamic> driver) {
    return _buildSection(context, 'Verification Status', [
      _buildDocRow('Background Verification', driver['bg_verify_status'], driver['bg_expiry_date']),
      _buildDocRow('Police Verification', driver['police_verify_status'], driver['police_expiry_date']),
      _buildDocRow('Medical Verification', driver['medical_verify_status'], driver['medical_expiry_date']),
      _buildDocRow('Training Verification', driver['training_verify_status'], driver['training_expiry_date']),
      _buildDocRow('Eye Test', driver['eye_verify_status'], driver['eye_expiry_date']),
    ]);
  }

  Widget _buildDocRow(String label, String? status, String? expiry) {
    Color badgeColor = Colors.grey;
    if (status == 'Approved') badgeColor = Colors.green;
    else if (status == 'Pending') badgeColor = Colors.orange;
    else if (status == 'Rejected' || status == 'Expired') badgeColor = Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withOpacity(0.5)),
                ),
                child: Text(
                  status ?? 'N/A', 
                  style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ),
              if (expiry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Exp: $expiry', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ),
            ],
          )
        ],
      ),
    );
  }
}
