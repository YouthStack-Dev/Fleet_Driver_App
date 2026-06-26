import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/booking_provider.dart';
import '../widgets/app_drawer.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Mapping tabs to statuses
  final Map<int, List<String>> _tabStatuses = {
    0: ['Ongoing', 'Scheduled', 'Request'], // Active
    1: ['Completed', 'No-Show'], // Completed
    2: ['Cancelled'], // Cancelled
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBookings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    await Provider.of<BookingProvider>(context, listen: false).fetchBookings(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051424),
      appBar: AppBar(
        title: Text(
          'My Schedules',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFD4E4FA)),
        ),
        backgroundColor: const Color(0xFF122131),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD4E4FA)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2E7CFF)),
            onPressed: _fetchBookings,
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF2E7CFF),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF8C90A0),
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
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
                color: const Color(0xFF2E7CFF).withOpacity(0.04),
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
                color: const Color(0xFF2E7CFF).withOpacity(0.02),
              ),
            ),
          ),
          
          Consumer<BookingProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF2E7CFF),
                    strokeWidth: 3,
                  ),
                );
              }
              
              if (provider.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF122131),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFFB4AB).withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB4AB).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error_outline_rounded, color: Color(0xFFFFB4AB), size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load schedules',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFFD4E4FA)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFC2C6D7)),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchBookings,
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7CFF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildList(provider.bookings, 0),
                  _buildList(provider.bookings, 1),
                  _buildList(provider.bookings, 2),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> allBookings, int tabIndex) {
    final statuses = _tabStatuses[tabIndex]!;
    final bookings = allBookings.where((b) => statuses.contains(b['status'])).toList();

    if (bookings.isEmpty) {
      final now = DateTime.now();
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Calendar Custom Illustration Card
                Container(
                  width: 90,
                  height: 95,
                  decoration: BoxDecoration(
                    color: const Color(0xFF122131),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ]
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 28,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getMonthName(now.month).toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 11,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            now.day.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 34, 
                              fontWeight: FontWeight.bold, 
                              color: const Color(0xFFD4E4FA),
                              height: 1.0,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'No ${['active', 'completed', 'cancelled'][tabIndex]} schedules',
                  style: GoogleFonts.poppins(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: const Color(0xFFD4E4FA),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Your assigned routes and bookings for this list will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: const Color(0xFFC2C6D7), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildBookingCard(booking),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(dynamic booking) {
    final status = booking['status'] ?? 'Unknown';
    final bookingId = booking['booking_id'];
    final date = booking['booking_date'] ?? 'N/A';
    
    Color statusTextColor = Colors.grey;
    Color statusBgColor = const Color(0xFF1E293B);
    if (['Ongoing', 'Scheduled'].contains(status)) {
      statusTextColor = const Color(0xFF10B981);
      statusBgColor = const Color(0xFF10B981).withOpacity(0.12);
    } else if (status == 'Request') {
      statusTextColor = const Color(0xFFF59E0B);
      statusBgColor = const Color(0xFFF59E0B).withOpacity(0.12);
    } else if (status == 'Rejected' || status == 'Cancelled') {
      statusTextColor = const Color(0xFFEF4444);
      statusBgColor = const Color(0xFFEF4444).withOpacity(0.12);
    } else if (status == 'Completed') {
      statusTextColor = const Color(0xFF3B82F6);
      statusBgColor = const Color(0xFF3B82F6).withOpacity(0.12);
    }

    bool canCancel = status == 'Request' || status == 'Approved' || status == 'Scheduled';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF122131),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$bookingId', 
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, 
                        fontSize: 15.5,
                        color: const Color(0xFFD4E4FA),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF8C90A0)),
                        const SizedBox(width: 6),
                        Text(
                          date, 
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFC2C6D7), 
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusTextColor.withOpacity(0.3), width: 0.8),
                  ),
                  child: Text(
                    status.toUpperCase(), 
                    style: GoogleFonts.poppins(
                      color: statusTextColor, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 14),
            const Divider(thickness: 1.0, color: Color(0xFF334155)),
            const SizedBox(height: 14),
            
            // Pickup to Drop Timeline Routing Layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Visual Vertical Timeline Line
                  Column(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF10B981), size: 12),
                      Container(
                        width: 1.5,
                        height: 38,
                        color: const Color(0xFF334155),
                      ),
                      const Icon(Icons.place_rounded, color: Color(0xFFEF4444), size: 14),
                    ],
                  ),
                  const SizedBox(width: 14),
                  
                  // Locations Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PICKUP LOCATION', 
                          style: GoogleFonts.poppins(fontSize: 9.5, color: const Color(0xFF8C90A0), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking['pickup_location'] ?? 'N/A', 
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFD4E4FA)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'DROP LOCATION', 
                          style: GoogleFonts.poppins(fontSize: 9.5, color: const Color(0xFF8C90A0), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking['drop_location'] ?? 'N/A', 
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFD4E4FA)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // OTP Code block
            if (booking['OTP'] != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7CFF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E7CFF).withOpacity(0.2), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Color(0xFF2E7CFF), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'OTP CODE :  ',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2E7CFF), 
                        fontWeight: FontWeight.bold, 
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _formatOTP(booking['OTP'].toString()), 
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2E7CFF), 
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              )
            ],
 
            // Actions Button (Cancel Booking)
            if (canCancel) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleCancel(bookingId.toString()),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text('Cancel Booking', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.04),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  String _formatOTP(String otp) {
    if (otp.length == 4) {
      return '${otp[0]} ${otp[1]} ${otp[2]} ${otp[3]}';
    }
    return otp;
  }

  Future<void> _handleCancel(String bookingId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF122131),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Text(
              'Cancel Booking', 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFFD4E4FA)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this booking?',
          style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFFC2C6D7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('No', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF8C90A0))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Yes, Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
          ),
        ],
      )
    );

    if (confirm == true) {
      if (mounted) {
        final success = await Provider.of<BookingProvider>(context, listen: false).cancelBooking(context, bookingId);
        if (success && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Booking cancelled successfully', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
               backgroundColor: const Color(0xFFEF4444),
               behavior: SnackBarBehavior.floating,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             )
           );
        }
      }
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
