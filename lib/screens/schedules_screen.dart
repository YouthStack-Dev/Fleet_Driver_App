import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/booking_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_drawer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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

  Future<void> _fetchBookings() async {
    await Provider.of<BookingProvider>(context, listen: false).fetchBookings(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedules'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active', icon: Icon(Icons.refresh)),
            Tab(text: 'Completed', icon: Icon(Icons.check)),
            Tab(text: 'Cancelled', icon: Icon(Icons.cancel)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBookings,
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
           if (provider.isLoading) {
             return const Center(child: CircularProgressIndicator());
           }
           
           if (provider.error != null) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(provider.error!, style: const TextStyle(color: Colors.red)),
                   const SizedBox(height: 10),
                   ElevatedButton(onPressed: _fetchBookings, child: const Text('Retry'))
                 ],
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
    );
  }

  Widget _buildList(List<dynamic> allBookings, int tabIndex) {
    final statuses = _tabStatuses[tabIndex]!;
    final bookings = allBookings.where((b) => statuses.contains(b['status'])).toList();
    
    // Sort logic from RN: Active -> By Status Index? Or just default.
    // We'll just show them as is or sort by date.

    if (bookings.isEmpty) {
      // Custom Empty State matching the screenshot
      final now = DateTime.now();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // Calendar Icon Lookalike
             Container(
               width: 80,
               height: 80,
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(12),
                 boxShadow: [
                   BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                 ]
               ),
               child: Column(
                 children: [
                   Container(
                     height: 24,
                     decoration: const BoxDecoration(
                       color: Color(0xFFFF5252), // Red header
                       borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                     ),
                     alignment: Alignment.center,
                     child: Text(
                       _getMonthName(now.month),
                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                     ),
                   ),
                   Expanded(
                     child: Center(
                       child: Text(
                         now.day.toString(),
                         style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                       ),
                     ),
                   )
                 ],
               ),
             ),
             const SizedBox(height: 24),
             Text(
               'No ${['active', 'completed', 'cancelled'][tabIndex]} schedules',
               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
             ),
             const SizedBox(height: 8),
             const Padding(
               padding: EdgeInsets.symmetric(horizontal: 40),
               child: Text(
                 'Your assigned routes for today will appear here',
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey, fontSize: 14),
               ),
             ),
          ],
        ),
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
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
    
    Color statusColor = Colors.grey;
    if (['Ongoing', 'Scheduled'].contains(status)) statusColor = Colors.green;
    if (status == 'Request') statusColor = Colors.orange;
    if (status == 'Rejected' || status == 'Cancelled') statusColor = Colors.red;
    if (status == 'Completed') statusColor = Colors.blue;

    bool canCancel = status == 'Request' || status == 'Approved' || status == 'Scheduled';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#$bookingId', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                )
              ],
            ),
            const Divider(),
            _buildLocationRow(Icons.place, 'Pickup', booking['pickup_location'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildLocationRow(Icons.flag, 'Drop', booking['drop_location'] ?? 'N/A'),
            
            if (booking['OTP'] != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.deepPurple[50],
                child: Text('OTP: ${booking['OTP']}', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, letterSpacing: 2), textAlign: TextAlign.center),
              )
            ],

            if (canCancel) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _handleCancel(bookingId.toString()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Cancel Booking'),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        )
      ],
    );
  }

  Future<void> _handleCancel(String bookingId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      if (mounted) {
        final success = await Provider.of<BookingProvider>(context, listen: false).cancelBooking(context, bookingId);
        if (success && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
        }
      }
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
