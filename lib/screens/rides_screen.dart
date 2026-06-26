import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/booking_provider.dart';
import '../providers/location_provider.dart';
import '../services/permission_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'chat_screen.dart';
import 'trip_history_screen.dart';

// ─── Light Theme Color Tokens ────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFFF4F6FA);   // Page background
  static const border     = Color(0xFFE8ECF4);    // Dividers / borders
  static const textPrimary   = Color(0xFF111827); // Dark headings
  static const textSecondary = Color(0xFF6B7280); // Sub-labels
  static const blue       = Color(0xFF1E6BFF);    // Primary blue
  static const blueBg     = Color(0xFFECF2FF);    // Blue tint
  static const green      = Color(0xFF16A34A);    // Success green
  static const greenBg    = Color(0xFFDCFCE7);
  static const amber      = Color(0xFFF59E0B);    // ETA / time
  static const amberBg    = Color(0xFFFFFBEB);
  static const red        = Color(0xFFDC2626);    // No Show / End Duty
  static const redBg      = Color(0xFFFEF2F2);
  static const teal       = Color(0xFF0D9488);    // Navigate button
  static const tealBg     = Color(0xFFCCFBF1);
  static const purple     = Color(0xFF7C3AED);    // Board button
}

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  final Map<dynamic, bool> _collapsedRoutes = {};

  @override
  void initState() {
    super.initState();
    print('UI: RidesScreen (Home) initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('UI: RidesScreen postFrameCallback - fetching trips');

      if (!mounted) return;
      await PermissionService().checkAndRequestAllPermissions(context);

      if (!mounted) return;
      final provider = Provider.of<BookingProvider>(context, listen: false);
      provider.clearData();
      _fetchRoutes();
    });
  }

  Future<void> _fetchRoutes() async {
    if (!mounted) return;
    final provider = Provider.of<BookingProvider>(context, listen: false);
    await provider.fetchTrips(status: 'ongoing');
    if (!mounted) return;
    if (provider.routes.isEmpty) {
      await provider.fetchTrips(status: 'upcoming');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));
    final provider = Provider.of<BookingProvider>(context);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: Consumer<LocationProvider>(
        builder: (context, locationProvider, _) {
          return Stack(
            children: [
              provider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: _C.blue, strokeWidth: 2.5))
                  : RefreshIndicator(
                      onRefresh: _fetchRoutes,
                      color: _C.blue,
                      backgroundColor: Colors.white,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        children: [
                          if (provider.error != null && provider.routes.isEmpty)
                            _buildErrorState(provider.error!)
                          else if (provider.routes.isEmpty)
                            _buildInnerEmptyState()
                          else
                            AnimationLimiter(
                              child: Column(
                                children: provider.routes.asMap().entries.map((entry) {
                                  return AnimationConfiguration.staggeredList(
                                    position: entry.key,
                                    duration: const Duration(milliseconds: 350),
                                    child: SlideAnimation(
                                      verticalOffset: 40.0,
                                      child: FadeInAnimation(
                                        child: _buildRouteCard(entry.value, provider),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),

              // GPS Permission Warning Banner
              if (!locationProvider.hasGpsPermission)
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: _buildGpsWarningBanner(),
                ),
              // Speed-limit violation banner
              if (locationProvider.isTracking && locationProvider.isSpeedLimitExceeded)
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: _buildSpeedAlert(locationProvider),
                ),
              // Live speed HUD
              if (locationProvider.isTracking)
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: _buildSpeedHud(locationProvider),
                ),
            ],
          );
        },
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _greeting(),
              style: GoogleFonts.poppins(
                  color: _C.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              "Today's Ride",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, color: _C.textPrimary, fontSize: 17, height: 1.2),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _C.border, height: 1),
      ),
      leading: IconButton(
        icon: const Icon(Icons.history_rounded, color: _C.textPrimary),
        tooltip: 'Trip History',
        onPressed: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TripHistoryScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1, 0), end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.swap_horiz_rounded, color: _C.amber),
          tooltip: 'Switch Company',
          onPressed: () => Navigator.pushNamed(context, '/switch-account'),
        ),
        IconButton(
          icon: const Icon(Icons.person_rounded, color: _C.blue),
          tooltip: 'Profile',
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _C.blue),
          tooltip: 'Refresh',
          onPressed: _fetchRoutes,
        ),
      ],
    );
  }

  // ─── Empty / Error States ───────────────────────────────────────────────────

  Widget _buildInnerEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: _C.blueBg, shape: BoxShape.circle),
            child: const Icon(Icons.map_outlined, color: _C.blue, size: 32),
          ),
          const SizedBox(height: 18),
          Text('No upcoming routes',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _C.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Your assigned routes and schedules for today will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: _C.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: _C.redBg, shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, color: _C.red, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Failed to load routes',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _C.textPrimary)),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _C.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchRoutes,
            icon: const Icon(Icons.replay_rounded, size: 18, color: Colors.white),
            label: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          )
        ],
      ),
    );
  }

  // ─── GPS Warning Banner ─────────────────────────────────────────────────────

  Widget _buildGpsWarningBanner() {
    return Container(
      decoration: BoxDecoration(
        color: _C.amberBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.amber.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
              child: const Icon(Icons.location_off_rounded, color: _C.amber, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GPS Disabled',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 12.5)),
                  Text('Enable location to track route progress.',
                      style: GoogleFonts.poppins(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => PermissionService().openSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 0,
              ),
              child: Text('Settings', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Route Card ─────────────────────────────────────────────────────────────

  Widget _buildRouteCard(dynamic route, BookingProvider provider) {
    final bool isOngoing  = route['status'] == 'Ongoing';
    final bool isAssigned = route['status'] == 'Driver Assigned';
    final stops     = route['stops'] as List? ?? [];
    final routeId   = route['route_id'];
    final logType   = route['log_type'] ?? 'IN';
    final shiftTime = route['shift_time'] ?? 'N/A';
    final bool hasEscort     = route['has_escort'] == true || route['escort_required'] == true;
    final bool escortBoarded = route['escort_boarded'] == true || route['escort_status'] == 'Boarded';
    final bool showEscortBoard = isOngoing && hasEscort && !escortBoarded;

    final bool isCollapsed = _collapsedRoutes[routeId] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Route Header (InkWell for collapsibility) ──────────────────────
          InkWell(
            onTap: () {
              setState(() {
                _collapsedRoutes[routeId] = !isCollapsed;
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isCollapsed ? const Radius.circular(18) : Radius.zero,
              bottomRight: isCollapsed ? const Radius.circular(18) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route icon box
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _C.blueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.alt_route_rounded, color: _C.blue, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Route #$routeId',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800, fontSize: 16, color: _C.textPrimary),
                            ),
                            if (hasEscort) ...[
                              const SizedBox(width: 6),
                              _buildChip('ESCORT', _C.tealBg, _C.teal, icon: Icons.security_rounded),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _buildChip(
                              logType == 'IN' ? 'Pickup' : 'Drop',
                              logType == 'IN' ? _C.greenBg : _C.amberBg,
                              logType == 'IN' ? _C.green   : _C.amber,
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.access_time_rounded, size: 13, color: _C.textSecondary),
                            const SizedBox(width: 3),
                            Text(shiftTime,
                                style: GoogleFonts.poppins(
                                    color: _C.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ON DUTY / ASSIGNED badge + Collapse Icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOngoing)
                        _buildChip('ON DUTY', _C.greenBg, _C.green, dot: true)
                      else if (isAssigned)
                        _buildChip('ASSIGNED', _C.blueBg, _C.blue, dot: true),
                      const SizedBox(width: 6),
                      Icon(
                        isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        color: _C.textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (!isCollapsed) ...[
            // ── Summary Row (Google Maps style, no vertical dividers) ──────────
            Container(
              decoration: BoxDecoration(
                color: _C.bg,
                border: Border.symmetric(horizontal: BorderSide(color: _C.border)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  _buildSummaryStatPill(Icons.people_alt_rounded, '${stops.length}', 'Passengers', _C.blue),
                  const SizedBox(width: 10),
                  _buildSummaryStatPill(Icons.route_rounded,
                      '${(route['summary']?['total_distance_km'] ?? 0).toStringAsFixed(1)} km', 'Distance', _C.green),
                  const SizedBox(width: 10),
                  _buildSummaryStatPill(Icons.timer_rounded,
                      '${(route['summary']?['total_time_minutes'] ?? 0).round()} min', 'ETA', _C.amber),
                ],
              ),
            ),

            // ── Passenger Stops ───────────────────────────────────────────────
            if (stops.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Current Stop (first non-completed stop)
                    () {
                      final currentIdx = stops.indexWhere(
                        (s) => s['status'] != 'Completed' && s['status'] != 'NoShow' && s['status'] != 'No Show' && s['status'] != 'No-Show',
                      );
                      final upcomingStops = stops
                          .asMap()
                          .entries
                          .where((e) =>
                              e.key != currentIdx &&
                              e.value['status'] != 'Completed' &&
                              e.value['status'] != 'NoShow' &&
                              e.value['status'] != 'No Show' &&
                              e.value['status'] != 'No-Show')
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentIdx >= 0) ...[
                            _buildSectionHeader(
                              'CURRENT STOP',
                              subtitle: '${stops[currentIdx]['employee_name'] ?? ''} • Stop ${currentIdx + 1} of ${stops.length}',
                              rightAction: _buildViewMapButton(stops[currentIdx]),
                            ),
                            const SizedBox(height: 10),
                            _buildCurrentStopCard(stops[currentIdx], route, provider, currentIdx),
                            const SizedBox(height: 18),
                          ],
                          if (upcomingStops.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Upcoming Stops (${upcomingStops.length})',
                              rightAction: _buildSortChip(),
                            ),
                            const SizedBox(height: 10),
                            ...upcomingStops.asMap().entries.map((e) {
                              final globalIdx = e.value.key;
                              final stop = e.value.value;
                              return _buildUpcomingStopTile(stop, route, provider, globalIdx + 1);
                            }),
                          ],
                          // Completed stops (just list without actions)
                          ...stops.asMap().entries.where((e) {
                            final s = e.value['status'];
                            return s == 'Completed' || s == 'NoShow' || s == 'No Show' || s == 'No-Show';
                          }).map((e) {
                            return _buildTimelineStopItem(e.value, route, provider, e.key, e.key == stops.length - 1);
                          }),
                        ],
                      );
                    }(),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Center(
                  child: Text('No stops assigned for this route.',
                      style: GoogleFonts.poppins(color: _C.textSecondary, fontSize: 13)),
                ),
              ),

            // ── Route Progress Mini-Timeline ──────────────────────────────────
            if (stops.isNotEmpty && isOngoing)
              _buildRouteProgressTimeline(stops),

            // ── Footer Actions ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isAssigned)
                    _buildPrimaryButton(
                      label: 'START DUTY',
                      icon: Icons.rocket_launch_rounded,
                      color: _C.blue,
                      onPressed: () => _handleStartDuty(routeId.toString(), provider),
                    ),
                  if (showEscortBoard) ...[
                    const SizedBox(height: 8),
                    _buildPrimaryButton(
                      label: 'BOARD ESCORT',
                      icon: Icons.security_rounded,
                      color: _C.teal,
                      onPressed: () => _handleEscortBoard(routeId.toString(), provider),
                    ),
                  ],
                  if (isOngoing) ...[
                    const SizedBox(height: 8),
                    _buildEndDutyButton(() => _handleEndDuty(routeId.toString(), provider)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Section Headers ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {String? subtitle, Widget? rightAction}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: subtitle != null ? 30 : 18,
          decoration: BoxDecoration(
            color: _C.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: _C.textSecondary,
                      letterSpacing: 0.8)),
              if (subtitle != null)
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13.5, color: _C.textPrimary)),
            ],
          ),
        ),
        if (rightAction != null) rightAction,
      ],
    );
  }

  /// Mini progress timeline shown between stops list and END DUTY.
  Widget _buildRouteProgressTimeline(List stops) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: _C.border, height: 24),
          Text('Route Progress',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 13, color: _C.textPrimary)),
          const SizedBox(height: 10),
          ...stops.asMap().entries.map((e) {
            final i = e.key;
            final stop = e.value;
            final s = stop['status'] ?? 'Scheduled';
            final bool done = s == 'Completed' || s == 'NoShow' || s == 'No Show' || s == 'No-Show';
            final bool active = !done && stops.indexWhere((x) {
              final xs = x['status'] ?? 'Scheduled';
              return xs != 'Completed' && xs != 'NoShow' && xs != 'No Show' && xs != 'No-Show';
            }) == i;
            final Color dotColor = done ? _C.green : (active ? _C.blue : _C.border);
            final Color textColor = active ? _C.textPrimary : (done ? _C.textSecondary : _C.textSecondary);
            final name = stop['employee_name'] ?? 'Stop ${i + 1}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: active ? _C.blue : (done ? _C.green : Colors.white),
                          shape: BoxShape.circle,
                          border: Border.all(color: dotColor, width: 2),
                        ),
                      ),
                      if (i < stops.length - 1)
                        Container(width: 2, height: 18, color: _C.border),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(width: 6),
                    Icon(s == 'Completed' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 13, color: s == 'Completed' ? _C.green : _C.red),
                  ],
                ],
              ),
            );
          }),
          Divider(color: _C.border, height: 16),
        ],
      ),
    );
  }

  Widget _buildEndDutyButton(VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: _C.red.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.flag_rounded, size: 17, color: Colors.white),
        label: Text('END DUTY',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildViewMapButton(dynamic stop) {
    final lat = stop['pickup_latitude'];
    final lng = stop['pickup_longitude'];
    final address = stop['pickup_location'] ?? '';
    return TextButton.icon(
      onPressed: () {
        if (lat != null && lng != null) _launchMaps(lat, lng, address);
      },
      icon: const Icon(Icons.map_outlined, size: 14, color: _C.blue),
      label: Text('View Map', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _C.blue)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildSortChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stop Order', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _C.textSecondary),
        ],
      ),
    );
  }

  // ─── Current Stop Card ───────────────────────────────────────────────────────

  Widget _buildCurrentStopCard(dynamic stop, dynamic route, BookingProvider provider, int index) {
    final passengerName = stop['employee_name'] ?? 'Passenger';
    final initial = passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P';
    final phone   = stop['employee_phone']?.toString() ?? '';
    final status  = stop['status'] ?? 'Scheduled';
    final eta     = stop['estimated_pick_up_time'] ?? '';
    final isOnBoard  = status == 'Ongoing';
    final address    = isOnBoard ? (stop['drop_location'] ?? '') : (stop['pickup_location'] ?? '');
    final double? lat = isOnBoard ? stop['drop_latitude']  : stop['pickup_latitude'];
    final double? lng = isOnBoard ? stop['drop_longitude'] : stop['pickup_longitude'];

    final bool showPickup = route['status'] == 'Ongoing' && status == 'Scheduled';
    final bool showDrop   = route['status'] == 'Ongoing' && status == 'Ongoing';
    final bool isOtpRequired = isOnBoard
        ? stop['is_deboarding_otp_required'] == true
        : stop['is_boarding_otp_required'] == true;

    final avatarColor = _avatarColor(initial);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blue timeline dot
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 10),
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: const BoxDecoration(color: _C.blue, shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 17, color: avatarColor)),
                ),
                const SizedBox(width: 10),
                // Name + phone block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(passengerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 18, color: _C.textPrimary, height: 1.2)),
                      if (eta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: _C.blueBg, borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 11, color: _C.blue),
                                  const SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ETA',
                                          style: GoogleFonts.poppins(
                                              fontSize: 8, color: _C.blue, fontWeight: FontWeight.bold)),
                                      Text(_formatTime(eta),
                                          style: GoogleFonts.poppins(
                                              fontSize: 10, color: _C.blue, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isOtpRequired) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: _C.amberBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _C.amber.withValues(alpha: 0.3))),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_rounded, size: 10, color: _C.amber),
                                    const SizedBox(width: 4),
                                    Text('OTP',
                                        style: GoogleFonts.poppins(
                                            fontSize: 9.5, color: _C.amber, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Status badge top-right + combined call & chat row
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge(status),
                    const SizedBox(height: 8),
                    // Combined Call + Chat mini-row
                    _buildCallChatRow(stop, phone),
                  ],
                ),
              ],
            ),
          ),

          // Address row with label
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnBoard ? 'Drop Address' : 'Pickup Address',
                      style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          color: _C.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.location_on_rounded, size: 14, color: _C.blue),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(address,
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: _C.textPrimary, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Navigate button
          if (lat != null && lng != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: ElevatedButton.icon(
                onPressed: () => _launchMaps(lat, lng, address),
                icon: const Icon(Icons.navigation_rounded, size: 15, color: Colors.white),
                label: Text(
                  'Navigate to ${isOnBoard ? "Drop" : "Pickup"}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  elevation: 0,
                ),
              ),
            ),

          // Board / Drop / NoShow — 48 px height buttons
          if (showPickup || showDrop)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  if (showPickup)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handlePickup(stop, route, provider),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                        label: Text('Board',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (showDrop)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleDrop(stop, route, provider),
                        icon: const Icon(Icons.logout_rounded, size: 15, color: Colors.white),
                        label: Text('Drop',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.purple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (showPickup) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleNoShow(stop, route, provider),
                        icon: Icon(Icons.cancel_outlined, size: 14, color: _C.red),
                        label: Text('No Show',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _C.red)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _C.red.withValues(alpha: 0.4)),
                          backgroundColor: _C.redBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Upcoming Stop Tile ──────────────────────────────────────────────────────

  Widget _buildUpcomingStopTile(dynamic stop, dynamic route, BookingProvider provider, int displayIndex) {
    final passengerName = stop['employee_name'] ?? 'Passenger';
    final initial = passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P';
    final address = stop['pickup_location'] ?? stop['drop_location'] ?? '';
    final eta     = stop['estimated_pick_up_time'] ?? '';
    final status  = stop['status'] ?? 'Scheduled';
    final avatarColor = _avatarColor(initial);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          // Index number
          Container(
            width: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('$displayIndex',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 13, color: _C.textSecondary)),
          ),
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: avatarColor.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 14, color: avatarColor)),
          ),
          const SizedBox(width: 10),
          // Name & address
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(passengerName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 13.5, color: _C.textPrimary)),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11, color: _C.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // ETA chip + status + arrow
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (eta.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _C.blueBg, borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      children: [
                        Text('ETA',
                            style: GoogleFonts.poppins(
                                fontSize: 8, color: _C.blue, fontWeight: FontWeight.bold)),
                        Text(_formatTime(eta),
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: _C.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                _buildStatusBadge(status),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _C.textSecondary, size: 20),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ─── Completed / NoShow Timeline Item ───────────────────────────────────────

  Widget _buildTimelineStopItem(dynamic stop, dynamic route, BookingProvider provider, int index, bool isLast) {
    final String status = stop['status'] ?? 'Scheduled';
    final bool isCompleted = status == 'Completed';
    final bool isNoShow    = ['NoShow', 'No Show', 'No-Show'].contains(status);

    Color dotColor;
    IconData dotIcon;
    if (isCompleted)       { dotColor = _C.green; dotIcon = Icons.check_circle_rounded; }
    else if (isNoShow)     { dotColor = _C.red;   dotIcon = Icons.cancel_rounded;        }
    else                   { dotColor = _C.amber;  dotIcon = Icons.radio_button_checked_rounded; }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 1.5),
                  ),
                  child: Icon(dotIcon, color: dotColor, size: 13),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: _C.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPassengerCard(stop, route, provider, dotColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(dynamic stop, dynamic route, BookingProvider provider, Color statusColor) {
    final String status  = stop['status'] ?? 'Scheduled';
    final bool isOnBoard = status == 'Ongoing';
    final String address = isOnBoard ? (stop['drop_location'] ?? '') : (stop['pickup_location'] ?? '');
    final double? lat    = isOnBoard ? stop['drop_latitude']  : stop['pickup_latitude'];
    final double? lng    = isOnBoard ? stop['drop_longitude'] : stop['pickup_longitude'];
    final String eta     = stop['estimated_pick_up_time'] ?? '';
    final bool showPickup = route['status'] == 'Ongoing' && status == 'Scheduled';
    final bool showDrop   = route['status'] == 'Ongoing' && status == 'Ongoing';
    final bool isOtpRequired = isOnBoard
        ? stop['is_deboarding_otp_required'] == true
        : stop['is_boarding_otp_required'] == true;

    final passengerName = stop['employee_name'] ?? 'Passenger';
    final initial = passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P';
    final avatarColor = _avatarColor(initial);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: avatarColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passengerName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 13.5, color: _C.textPrimary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(status),
                  const SizedBox(height: 6),
                  _buildCallChatRow(stop, stop['employee_phone']?.toString() ?? ''),
                ],
              ),
            ],
          ),
          if (eta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _C.blueBg, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 10, color: _C.blue),
                      const SizedBox(width: 4),
                      Text('ETA: ${_formatTime(eta)}',
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: _C.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (isOtpRequired) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _C.amberBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _C.amber.withValues(alpha: 0.3))),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, size: 10, color: _C.amber),
                        const SizedBox(width: 4),
                        Text('OTP Required',
                            style: GoogleFonts.poppins(
                                fontSize: 9.5, color: _C.amber, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (address.isNotEmpty && !['NoShow', 'No Show', 'No-Show'].contains(status)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: _C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
              child: Row(
                children: [
                  const Icon(Icons.place_rounded, size: 13, color: _C.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(address,
                        style: GoogleFonts.poppins(fontSize: 11.5, color: _C.textPrimary, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _launchMaps(lat, lng, address),
                  icon: const Icon(Icons.navigation_rounded, size: 14, color: Colors.white),
                  label: Text('NAVIGATE TO ${isOnBoard ? "DROP" : "PICKUP"}',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    elevation: 0,
                  ),
                ),
              ),
            ],
            if (showPickup) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handlePickup(stop, route, provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        elevation: 0,
                      ),
                      child: Text('BOARD PASSENGER',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleNoShow(stop, route, provider),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.red,
                        side: BorderSide(color: _C.red.withValues(alpha: 0.4)),
                        backgroundColor: _C.redBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child: Text('NO SHOW',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _C.red)),
                    ),
                  ),
                ],
              ),
            ],
            if (showDrop) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleDrop(stop, route, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    elevation: 0,
                  ),
                  child: Text('DROP PASSENGER',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Color _avatarColor(String initial) {
    final colors = [_C.blue, _C.green, _C.amber, _C.purple, _C.teal, _C.red, const Color(0xFFDB2777)];
    return colors[initial.codeUnitAt(0) % colors.length];
  }

  Widget _buildChip(String label, Color bg, Color fg,
      {IconData? icon, bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: GoogleFonts.poppins(
                  color: fg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg, fg;
    switch (status) {
      case 'Completed': bg = _C.greenBg;  fg = _C.green;  break;
      case 'Ongoing':   bg = _C.blueBg;   fg = _C.blue;   break;
      case 'NoShow':
      case 'No Show':
      case 'No-Show':   bg = _C.redBg;    fg = _C.red;    break;
      default:          bg = _C.amberBg;  fg = _C.amber;  break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(color: fg, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }

  /// Pill-style stat (no dividers) for the summary row
  Widget _buildSummaryStatPill(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13, color: _C.textPrimary, height: 1.2)),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 9.5, color: _C.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 14, color: _C.textPrimary)),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 10.5, color: _C.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 36, width: 1, color: _C.border);
  }

  Widget _buildPrimaryButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(vertical: 0),
        elevation: 0,
      ),
    );
  }

  /// Combined Call + Chat icon row displayed in the passenger card top-right.
  Widget _buildCallChatRow(dynamic stop, String phone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phone.isNotEmpty)
          _iconAction(
            icon: Icons.phone_rounded,
            color: _C.green,
            bg: _C.greenBg,
            onTap: () async {
              final url = Uri.parse('tel:$phone');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
          ),
        if (phone.isNotEmpty && stop['booking_id'] != null)
          const SizedBox(width: 6),
        if (stop['booking_id'] != null)
          _iconAction(
            icon: Icons.chat_bubble_outline_rounded,
            color: _C.blue,
            bg: _C.blueBg,
            onTap: () {
              final bookingId = stop['booking_id'];
              final int? id = bookingId is int ? bookingId : int.tryParse(bookingId.toString());
              if (id == null) return;
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => ChatScreen(
                    bookingId: id,
                    passengerName: stop['employee_name']?.toString(),
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _iconAction({required IconData icon, required Color color, required Color bg, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  Widget _buildChatButton(dynamic stop) {
    return _iconAction(
      icon: Icons.chat_bubble_outline_rounded,
      color: _C.blue,
      bg: _C.blueBg,
      onTap: () {
        final bookingId = stop['booking_id'];
        final int? id = bookingId is int ? bookingId : int.tryParse(bookingId.toString());
        if (id == null) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ChatScreen(
              bookingId: id,
              passengerName: stop['employee_name']?.toString(),
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
    );
  }

  // ─── Speed HUD (overlaps footer, Google Maps style) ─────────────────────────

  Widget _buildSpeedHud(LocationProvider locationProvider) {
    final speed    = locationProvider.currentSpeedKmh;
    final limit    = locationProvider.speedLimitKmh;
    final exceeded = locationProvider.isSpeedLimitExceeded;

    Color hudColor;
    if (exceeded)                  hudColor = _C.red;
    else if (speed >= limit * 0.9) hudColor = _C.amber;
    else                           hudColor = _C.teal;

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: hudColor, width: 3.5),
        boxShadow: [
          BoxShadow(color: hudColor.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: 2, offset: const Offset(0, -2)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(speed.toStringAsFixed(0),
              style: GoogleFonts.poppins(
                  color: hudColor, fontSize: 24, fontWeight: FontWeight.bold, height: 1.0)),
          Text('km/h',
              style: GoogleFonts.poppins(
                  color: _C.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSpeedAlert(LocationProvider locationProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _C.red.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.speed_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Speed Limit Exceeded!',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                Text(
                  '${locationProvider.currentSpeedKmh.toStringAsFixed(0)} km/h (Limit: ${locationProvider.speedLimitKmh.toStringAsFixed(0)} km/h)',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action Handlers ─────────────────────────────────────────────────────────

  Future<void> _handleStartDuty(String routeId, BookingProvider provider) async {
    final success = await provider.startDuty(routeId);
    if (success && mounted) {
      Provider.of<LocationProvider>(context, listen: false).setActiveRoute(routeId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duty Started!')));
    } else if (mounted) {
      _showErrorDialog(provider.error ?? 'Failed');
    }
  }

  Future<void> _handleEscortBoard(String routeId, BookingProvider provider) async {
    final otp = await _showOtpDialog(context, 'Escort');
    if (otp == null || !mounted) return;
    final result = await provider.escortBoard(routeId, otp);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escort boarded successfully!')));
    } else {
      if (result['errorCode'] == 'INVALID_OTP') {
        _showInvalidOtpDialog();
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to board escort');
      }
    }
  }

  Future<void> _handleEndDuty(String routeId, BookingProvider provider) async {
    final result = await provider.endDuty(routeId, null);
    if (result['success'] == true) {
      if (mounted) {
        Provider.of<LocationProvider>(context, listen: false).setActiveRoute(null);
        if (result['summary'] != null) {
          _showTripSummaryDialog(result['summary']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duty Ended!')));
        }
      }
    } else if (mounted) {
      if (result['errorCode'] == 'PENDING_BOOKINGS_EXIST') {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Cannot End Duty', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text(
              'You have pending bookings. Please complete all pickups/drops or mark as no-show before ending duty.',
              style: GoogleFonts.poppins(fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _C.blue)),
              )
            ],
          ),
        );
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to end duty');
      }
    }
  }

  void _showTripSummaryDialog(Map<String, dynamic> summary) {
    final routeCode = summary['route_code'] ?? '—';
    final boarded = summary['boarded_count'] ?? 0;
    final totalStops = summary['stops_count'] ?? 0;
    
    final double actualDist = (summary['actual_total_distance'] as num?)?.toDouble() ?? 0.0;
    final double estDist = (summary['estimated_total_distance'] as num?)?.toDouble() ?? 0.0;
    
    final double actualTime = (summary['actual_total_time'] as num?)?.toDouble() ?? 0.0;
    final double estTime = (summary['estimated_total_time'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Circular Checked Icon
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header Title
            Text(
              'Duty Completed Successfully!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Route: $routeCode',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            
            // Summary Stats Grid
            Row(
              children: [
                // Passengers Card
                Expanded(
                  child: _buildSummaryDialogCard(
                    icon: Icons.people_alt_rounded,
                    value: '$boarded / $totalStops',
                    label: 'Passengers Boarded',
                    color: const Color(0xFF1E6BFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Distance Card
                Expanded(
                  child: _buildSummaryDialogCard(
                    icon: Icons.route_rounded,
                    value: '${actualDist.toStringAsFixed(1)} km',
                    label: 'Actual Distance',
                    subValue: 'Est: ${estDist.toStringAsFixed(1)} km',
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 12),
                // Duration Card
                Expanded(
                  child: _buildSummaryDialogCard(
                    icon: Icons.timer_rounded,
                    value: '${actualTime.round()} min',
                    label: 'Actual Time',
                    subValue: 'Est: ${estTime.round()} min',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'DONE',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryDialogCard({
    required IconData icon,
    required String value,
    required String label,
    String? subValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 3),
            Text(
              subValue,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handlePickup(dynamic stop, dynamic route, BookingProvider provider) async {
    String? otp;
    if (stop['is_boarding_otp_required'] == true) {
      otp = await _showOtpDialog(context, stop['employee_name']);
      if (otp == null) return;
    }
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final pos = await locationProvider.getCurrentLocation();
    if (pos == null) {
      if (mounted) _showErrorDialog('Location not valid');
      return;
    }
    final result = await provider.startTrip(
        route['route_id'].toString(), stop['booking_id'].toString(), otp, pos.latitude, pos.longitude);
    if (result['success'] != true && mounted) {
      if (result['errorCode'] == 'INVALID_BOARDING_OTP') {
        _showInvalidOtpDialog();
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to start trip');
      }
    }
  }

  Future<void> _handleDrop(dynamic stop, dynamic route, BookingProvider provider) async {
    String? otp;
    if (stop['is_deboarding_otp_required'] == true) {
      otp = await _showOtpDialog(context, stop['employee_name']);
      if (otp == null) return;
    }
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final pos = await locationProvider.getCurrentLocation();
    if (pos == null) {
      if (mounted) _showErrorDialog('Location not valid');
      return;
    }
    final result = await provider.dropTrip(
        route['route_id'].toString(), stop['booking_id'].toString(), otp, pos.latitude, pos.longitude);
    if (result['success'] != true && mounted) {
      if (result['errorCode'] == 'INVALID_DEBOARDING_OTP') {
        _showInvalidOtpDialog();
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to drop trip');
      }
    }
  }

  Future<void> _handleNoShow(dynamic stop, dynamic route, BookingProvider provider) async {
    final TextEditingController reasonController = TextEditingController(text: 'Passenger did not arrive');
    String selectedReason = 'Passenger did not arrive';
    final List<String> presetReasons = [
      'Passenger did not arrive',
      'Phone not reachable / switched off',
      'Passenger cancelled verbally',
      'Driver waited (> 5 mins)',
      'Other',
    ];

    final reason = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              'Mark No Show Reason',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select a reason for marking ${stop['employee_name'] ?? 'passenger'} as no-show:',
                    style: GoogleFonts.poppins(fontSize: 12, color: _C.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ...presetReasons.map((r) {
                    final isSelected = selectedReason == r;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedReason = r;
                          if (r != 'Other') {
                            reasonController.text = r;
                          } else {
                            reasonController.text = '';
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _C.red.withOpacity(0.05) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? _C.red.withOpacity(0.3) : _C.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? _C.red : _C.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? _C.textPrimary : _C.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      style: GoogleFonts.poppins(fontSize: 12.5),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter custom reason...',
                        hintStyle: GoogleFonts.poppins(fontSize: 12, color: _C.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _C.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _C.red),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _C.textSecondary, fontSize: 13),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = reasonController.text.trim();
                  if (text.isEmpty) {
                    Navigator.pop(c, 'Passenger did not show up');
                  } else {
                    Navigator.pop(c, text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0,
                ),
                child: Text(
                  'Submit No Show',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      await provider.markNoShow(
        route['route_id'].toString(),
        stop['booking_id'].toString(),
        reason,
      );
    }
  }

  Future<void> _showInvalidOtpDialog() async {
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Invalid OTP', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _C.red)),
        content: Text('The OTP you entered is incorrect. Please try again.', style: GoogleFonts.poppins(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _C.blue)),
          ),
        ],
      ),
    );
  }

  /// Returns true when the raw API message is a "driver too far from stop" error.
  bool _isTooFarError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('too far') ||
        lower.contains('distance') ||
        lower.contains('meters') ||
        lower.contains('location') && lower.contains('far');
  }

  Future<void> _showErrorDialog(String message) async {
    final bool isTooFar = _isTooFarError(message);

    return showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isTooFar ? _C.amberBg : _C.redBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTooFar ? Icons.directions_walk_rounded : Icons.error_outline_rounded,
                  color: isTooFar ? _C.amber : _C.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                isTooFar ? 'You\'re Not Near the Stop' : 'Action Failed',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _C.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Body message
              Text(
                isTooFar
                    ? 'Please make your way to the passenger\'s pickup location before boarding.\n\nUse the Navigate button to get directions.'
                    : message,
                style: GoogleFonts.poppins(fontSize: 13, color: _C.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(c),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _C.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text('Dismiss',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _C.textSecondary)),
                    ),
                  ),
                  if (isTooFar) ...[ 
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(c),
                        icon: const Icon(Icons.navigation_rounded, size: 15, color: Colors.white),
                        label: Text('Navigate',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showOtpDialog(BuildContext context, String name) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => OtpDialogContent(employeeName: name),
    );
  }

  Future<void> _launchMaps(double lat, double lng, String? address) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Open Navigation', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Navigate to:\n${address ?? "Unknown Location"}', style: GoogleFonts.poppins(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _C.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openExternalMap(lat, lng, address);
            },
            child: Text('Open Maps', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _C.blue)),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalMap(double lat, double lng, String? address) async {
    final Uri directionsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    final Uri geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng${address != null ? "($address)" : ""}');
    try {
      if (await canLaunchUrl(directionsUrl)) {
        await launchUrl(directionsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _showErrorDialog('Could not open maps application');
      }
    } catch (e) {
      print('Error launching maps: $e');
      if (mounted) _showErrorDialog('Error launching maps: $e');
    }
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return 'N/A';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final min  = parts[1];
        final ampm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
        return '$displayHour:$min $ampm';
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }
}

// ─── OTP Dialog ───────────────────────────────────────────────────────────────

class OtpDialogContent extends StatefulWidget {
  final String employeeName;
  const OtpDialogContent({super.key, required this.employeeName});

  @override
  State<OtpDialogContent> createState() => _OtpDialogContentState();
}

class _OtpDialogContentState extends State<OtpDialogContent> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode  = FocusNode();
    _focusNode.addListener(() { if (mounted) setState(() {}); });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String otp       = _controller.text;
    final bool   isComplete = otp.length == 4;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E6BFF).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E6BFF).withValues(alpha: 0.15), width: 2),
                ),
                child: const Icon(Icons.lock_open_rounded, color: Color(0xFF1E6BFF), size: 34),
              ),
              const SizedBox(height: 18),
              Text('Security Verification',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold, color: _C.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Enter the 4-digit OTP for ${widget.employeeName} to confirm.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: _C.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 26),
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 0.0,
                      child: SizedBox(
                        width: 240,
                        height: 56,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          enableInteractiveSelection: false,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(4, (index) {
                          final bool isFocused = otp.length == index && _focusNode.hasFocus;
                          final bool hasValue  = otp.length > index;
                          final String digit   = hasValue ? otp[index] : '';

                          return Container(
                            width: 52,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused ? _C.blue : const Color(0xFFE2E8F0),
                                width: isFocused ? 2.0 : 1.5,
                              ),
                              boxShadow: isFocused
                                  ? [BoxShadow(color: _C.blue.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 4))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(digit,
                                style: GoogleFonts.poppins(
                                    fontSize: 22, fontWeight: FontWeight.bold, color: _C.textPrimary)),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(
                              fontSize: 13.5, fontWeight: FontWeight.bold, color: _C.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isComplete ? () => Navigator.pop(context, otp) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isComplete ? _C.blue : const Color(0xFFE2E8F0),
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Verify',
                          style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isComplete ? Colors.white : const Color(0xFF94A3B8))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
