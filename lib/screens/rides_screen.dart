import 'package:flutter/material.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/booking_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/app_drawer.dart';
import '../services/permission_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  // We track if we are viewing "ongoing" or "upcoming"
  // React Native logic: if ongoing exists, show it. Else show upcoming.
  // Provider handles this logic mostly, but we can refine fetch.

  @override
  void initState() {
    super.initState();
    print('UI: RidesScreen (Home) initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('UI: RidesScreen postFrameCallback - fetching trips');
      
      // Check permissions on Home load (RN parity: useEffect)
      // We don't block fetching, but we ensure permissions are active
      await PermissionService().checkAndRequestAllPermissions(context);

      final provider = Provider.of<BookingProvider>(context, listen: false);
      provider.clearData(); // Clear old data first
      _fetchRoutes();
    });
  }

  Future<void> _fetchRoutes() async {
    // Try fetching ongoing first
    final provider = Provider.of<BookingProvider>(context, listen: false);
    await provider.fetchTrips(status: 'ongoing');
    
    // If no routes, fetch upcoming. (Naive logic: if list is empty after ongoing fetch)
    if (provider.routes.isEmpty) {
      await provider.fetchTrips(status: 'upcoming');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BookingProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow body to scroll behind AppBar
      appBar: AppBar(
        title: const Text('My Schedules', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white.withOpacity(0.7), // Translucent white
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black), // Black Icon
            onPressed: _fetchRoutes,
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (provider.error != null && provider.routes.isEmpty)
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)),
                    ElevatedButton(onPressed: _fetchRoutes, child: const Text('Retry'))
                  ],
                ))
              : provider.routes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('No upcoming schedules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Your assigned routes for today will appear here',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
                        itemCount: provider.routes.length,
                        itemBuilder: (context, index) {
                          final route = provider.routes[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 400),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildRouteCard(route, provider),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildRouteCard(dynamic route, BookingProvider provider) {
    bool isOngoing = route['status'] == 'Ongoing';
    bool isAssigned = route['status'] == 'Driver Assigned'; // "Upcoming"
    
    // Parse route details
    final stops = route['stops'] as List? ?? [];
    final routeId = route['route_id'];
    final logType = route['log_type'] ?? 'IN'; // IN/OUT
    final shiftTime = route['shift_time'] ?? 'N/A';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Increased Roundness
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // Compact Header
            decoration: BoxDecoration(
              color: Colors.grey[50], 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), 
              border: Border(bottom: BorderSide(color: Colors.grey[200]!))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route #$routeId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        _buildBadge(logType == 'IN' ? 'Pickup' : 'Drop', 
                          logType == 'IN' ? Colors.green[100]! : Colors.orange[100]!, 
                          logType == 'IN' ? Colors.green[800]! : Colors.deepOrange[800]!
                        ),
                        const SizedBox(width: 8),
                         Text('🕐 $shiftTime', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                if (isOngoing)
                  _buildBadge('ON DUTY', Colors.green, Colors.white)
              ],
            ),
          ),
          
          // Stats Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Compact Stats
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 _buildStatItem(Icons.people, '${stops.length}', 'Passengers', Colors.blue),
                 _buildStatItem(Icons.straighten, '${(route['summary']?['total_distance_km'] ?? 0).toStringAsFixed(1)} km', 'Distance', Colors.green),
                 _buildStatItem(Icons.timer, '${(route['summary']?['total_time_minutes'] ?? 0).round()} min', 'Time', Colors.orange),
              ],
            ),
          ),
          
          // Passenger List
          if (stops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0), // Reduced from 16
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Passengers (${stops.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  ...stops.map((stop) => _buildPassengerItem(stop, route, provider)).toList(),
                ],
              ),
            )
          else 
            const Padding(padding: EdgeInsets.all(16), child: Text("No stops found.")),

          // Footer Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // Compact Footer
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 if (isAssigned)
                   ElevatedButton.icon(
                      onPressed: () => _handleStartDuty(routeId.toString(), provider),
                      icon: const Icon(Icons.rocket_launch),
                      label: const Text('START DUTY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                      ),
                   ),
                 
                 if (isOngoing)
                   ElevatedButton.icon(
                      onPressed: () => _handleEndDuty(routeId.toString(), provider),
                      icon: const Icon(Icons.flag),
                      label: const Text('END DUTY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                   )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPassengerItem(dynamic stop, dynamic route, BookingProvider provider) {
    bool isPickup = route['log_type'] == 'IN';
    String status = stop['status'] ?? 'Scheduled';
    
    // Dynamic Address Logic
    // If status is 'Ongoing' (On Board), show Drop Location. Otherwise Pickup.
    bool isOnBoard = status == 'Ongoing';
    
    String addressLabel = isOnBoard ? 'Drop Address:' : 'Pickup Address:';
    String address = isOnBoard ? (stop['drop_location'] ?? '') : (stop['pickup_location'] ?? '');
    double? lat = isOnBoard ? stop['drop_latitude'] : stop['pickup_latitude'];
    double? lng = isOnBoard ? stop['drop_longitude'] : stop['pickup_longitude'];
    
    String eta = stop['estimated_pick_up_time'] ?? '';
    bool isOtpRequired = isOnBoard 
        ? (stop['is_deboarding_otp_required'] == true) 
        : (stop['is_boarding_otp_required'] == true);
    
    // bool isCompleted = status == 'Completed' || status == 'Dropped' || status == 'PickedUp'; 
    // Typically: 'Scheduled', 'NoShow', 'Ongoing' (for passenger on board), 'Completed'
    
    // React Native logic: 
    // Pickup: Scheduled -> Ongoing (Picked up) -> Completed (Dropped off?) NO.
    // Pickup Flow: Scheduled -> [Pickup] -> Boarded -> [Drop at Office?] -> Completed.
    // Wait, typically corporate shuttle:
    // IN (Home to Office): Pickup Passenger -> Boarded. Route ends when all at office.
    // OUT (Office to Home): Pickup at Office -> Boarded -> Drop Passenger -> Completed.
    
    // Simplify based on buttons available:
    // If Scheduled: Show "Pickup" (if Route Ongoing)
    // If Ongoing (Passenger on board): Show "Drop" (if Route Ongoing)
    // If NoShow: dim.
    
    // Action logic from RN:
    // Pickup Button visible if route.status == 'Ongoing' && stop.status == 'Scheduled'
    // Drop Button visible if route.status == 'Ongoing' && stop.status == 'Ongoing'
    
    bool showPickup = route['status'] == 'Ongoing' && status == 'Scheduled';
    bool showDrop = route['status'] == 'Ongoing' && status == 'Ongoing'; // Passenger is "Ongoing" means on board
    // bool showNoShow = showPickup; // Unused

    return Container(
      margin: const EdgeInsets.only(bottom: 6), // Compact Margin
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Compact Padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop['employee_name'] ?? 'Passenger', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(stop['employee_phone'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 4), // Reduced spacing
          
          // ETA and OTP Badge Row
          Row(
            children: [
               if (eta.isNotEmpty) ...[
                 Text('🕐 ETA: ${_formatTime(eta)}', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                 const SizedBox(width: 8),
               ],
               if (isOtpRequired)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(4)),
                   child: Row(
                     children: [
                       const Icon(Icons.lock, size: 10, color: Colors.amber),
                       const SizedBox(width: 2),
                       Text('OTP Required', style: TextStyle(fontSize: 10, color: Colors.amber[900], fontWeight: FontWeight.bold)),
                     ],
                   ),
                 )
            ],
          ),
          const SizedBox(height: 4), // Reduced spacing
          
          if (!['NoShow', 'No Show', 'No-Show'].contains(status)) ...[
             // Address
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('📍 $addressLabel', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                 const SizedBox(height: 2),
                 Text(address, style: const TextStyle(fontSize: 13, color: Colors.black87)),
               ],
             ),
             const SizedBox(height: 12),

             // Actions Row - Full Width Buttons
             AnimatedSize(
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeInOut,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   if (lat != null && lng != null)
                     ElevatedButton.icon(
                        onPressed: () => _launchMaps(lat, lng, address),
                        icon: const Icon(Icons.navigation, size: 16, color: Colors.white),
                        label: Text('Navigate to ${isOnBoard ? 'Drop' : 'Pickup'}', style: const TextStyle(fontSize: 13, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan[600], // Match Screenshot Blue/Cyan
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                     ),
                   
                   const SizedBox(height: 8),
                   
                   if (showPickup) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handlePickup(stop, route, provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF), // Purple
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Start Pickup', style: TextStyle(fontSize: 13, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleNoShow(stop, route, provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[400], 
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                               child: const Text('No Show', style: TextStyle(fontSize: 13, color: Colors.white)),
                            ),
                          ),
                        ],
                      )
                   ],
                   
                   if (showDrop)
                      ElevatedButton(
                        onPressed: () => _handleDrop(stop, route, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF), // Purple
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                         child: const Text('Drop Off', style: TextStyle(fontSize: 13, color: Colors.white)),
                      ),
                 ],
               ),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg, 
        borderRadius: BorderRadius.circular(4)
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
        child: Text(text),
      ),
    );
  }
  
  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey[200]!;
    Color fg = Colors.grey[800]!;
    
    switch(status) {
      case 'Completed': bg = Colors.green[100]!; fg = Colors.green[800]!; break;
      case 'Ongoing': bg = Colors.blue[100]!; fg = Colors.blue[800]!; break; // On Board
      case 'NoShow': case 'No Show': case 'No-Show': bg = Colors.red[100]!; fg = Colors.red[800]!; break;
      case 'Scheduled': bg = Colors.orange[100]!; fg = Colors.orange[800]!; break;
    }
    
    return _buildBadge(status, bg, fg);
  }

  Future<void> _handleStartDuty(String routeId, BookingProvider provider) async {
    final success = await provider.startDuty(routeId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duty Started!')));
    } else if (mounted) {
       _showErrorDialog(provider.error ?? 'Failed');
    }
  }

  Future<void> _handleEndDuty(String routeId, BookingProvider provider) async {
    final result = await provider.endDuty(routeId, null);
    
    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duty Ended!')));
      }
    } else {
       if (mounted) {
         if (result['errorCode'] == 'PENDING_BOOKINGS_EXIST') {
           // Show Alert Dialog similar to React Native
           showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               title: const Text('Cannot End Duty'),
               content: const Text('You have pending bookings. Please complete all pickups/drops or mark as no-show before ending duty.'),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(ctx),
                   child: const Text('OK'),
                 )
               ],
             ),
           );
         } else {
           // Generic Error
           _showErrorDialog(result['error'] ?? 'Failed to end duty');
         }
       }
    }
  }

  Future<void> _handlePickup(dynamic stop, dynamic route, BookingProvider provider) async {
    // 1. Show OTP Dialog FIRST (Immediate UI response)
    String? otp;
    if (stop['is_boarding_otp_required'] == true) {
      otp = await _showOtpDialog(context, stop['employee_name']);
      if (otp == null) return; // Cancelled
    }

    // 2. Fetch Location SECOND (After UI interaction)
    // Show a loading indicator ideally, but provider handles async loading state well enough for now.
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final pos = await locationProvider.getCurrentLocation();
    
    if (pos == null) {
      if (mounted) _showErrorDialog('Location not valid');
      return;
    }

    final result = await provider.startTrip(
      route['route_id'].toString(), 
      stop['booking_id'].toString(), 
      otp, 
      pos.latitude, 
      pos.longitude
    );

    if (result['success'] != true && mounted) {
      if (result['errorCode'] == 'INVALID_BOARDING_OTP') {
        _showInvalidOtpDialog();
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to start trip');
      }
    }
  }

  Future<void> _handleDrop(dynamic stop, dynamic route, BookingProvider provider) async {
    // 1. Show OTP Dialog FIRST (Immediate UI response)
    String? otp;
    if (stop['is_deboarding_otp_required'] == true) {
      otp = await _showOtpDialog(context, stop['employee_name']);
      if (otp == null) return;
    }

    // 2. Fetch Location SECOND
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final pos = await locationProvider.getCurrentLocation();
    
    if (pos == null) {
       if (mounted) _showErrorDialog('Location not valid');
       return;
    }

    final result = await provider.dropTrip(
      route['route_id'].toString(), 
      stop['booking_id'].toString(), 
      otp, 
      pos.latitude, 
      pos.longitude
    );

    if (result['success'] != true && mounted) {
      if (result['errorCode'] == 'INVALID_DEBOARDING_OTP') {
        _showInvalidOtpDialog();
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to drop trip');
      }
    }
  }

  Future<void> _handleNoShow(dynamic stop, dynamic route, BookingProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text('Mark No Show'),
        content: Text('Mark ${stop['employee_name']} as No Show?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
       await provider.markNoShow(route['route_id'].toString(), stop['booking_id'].toString(), 'Passenger not found');
    }
  }

  Future<void> _showInvalidOtpDialog() async {
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Invalid OTP'),
        content: const Text('The OTP you entered is incorrect. Please try again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      )
    );
  }

  Future<void> _showErrorDialog(String message) async {
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Action Failed', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      )
    );
  }

  Future<String?> _showOtpDialog(BuildContext context, String name) async {
    String otp = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('Enter OTP for $name'),
        content: TextField(
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: (v) => otp = v,
          decoration: const InputDecoration(labelText: 'OTP', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, otp), child: const Text('Verify')),
        ],
      )
    );
  }

  Future<void> _launchMaps(double lat, double lng, String? address) async {
    // Show confirmation dialog first (RN Parity)
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Navigation'),
        content: Text('Navigate to:\n${address ?? "Unknown Location"}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openExternalMap(lat, lng, address);
            },
            child: const Text('Open Maps'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalMap(double lat, double lng, String? address) async {
    // Visual Parity: The user's screenshots show "Directions Mode" (Your Location -> Dest).
    // The 'geo' intent (Pin Mode) doesn't match this visual.
    // The 'https' URL intent launches Maps directly into Directions Mode with "Your Location" as default origin.
    
    final Uri directionsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    final Uri geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng${address != null ? "($address)" : ""}');

    try {
      if (await canLaunchUrl(directionsUrl)) {
        // Launch Directions Mode (Matches Screenshot 3)
        await launchUrl(directionsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUrl)) {
        // Fallback to Pin Mode
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
           _showErrorDialog('Could not open maps application');
        }
      }
    } catch (e) {
      print('Error launching maps: $e');
      if (mounted) {
        _showErrorDialog('Error launching maps: $e');
      }
    }
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor), // Reduced Icon Size
        const SizedBox(width: 6), // Spacing
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        // Label removed for parity
      ],
    );
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return 'N/A';
    try {
      // Handle "HH:MM:SS" or "HH:MM"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final min = parts[1];
        final ampm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
        return '$displayHour:$min $ampm';
      }
      // Handle simple ISO or Date format if needed (future proofing)
      return timeStr;
    } catch (_) {
      return timeStr; // Fallback to raw string
    }
  }
}
