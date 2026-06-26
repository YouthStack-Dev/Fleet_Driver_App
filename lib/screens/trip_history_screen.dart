import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/route_service.dart';

// ─── Same light-theme tokens as RidesScreen ──────────────────────────────────
class _C {
  static const bg            = Color(0xFFF4F6FA);
  static const border        = Color(0xFFE8ECF4);
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const blue          = Color(0xFF1E6BFF);
  static const blueBg        = Color(0xFFECF2FF);
  static const green         = Color(0xFF16A34A);
  static const greenBg       = Color(0xFFDCFCE7);
  static const amber         = Color(0xFFF59E0B);
  static const amberBg       = Color(0xFFFFFBEB);
  static const red           = Color(0xFFDC2626);
  static const redBg         = Color(0xFFFEF2F2);
}

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final RouteService _routeService = RouteService();

  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  Map<String, dynamic>? _summary;
  List<dynamic> _bookings = [];
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayRange(DateTimeRange range) {
    final startFmt = _displaySingleDate(range.start);
    final endFmt = _displaySingleDate(range.end);
    return '$startFmt - $endFmt';
  }

  String _displaySingleDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _fetchHistory() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await _routeService.getDriverHistoryReport(
        startDate: _fmtDate(_selectedRange.start),
        endDate:   _fmtDate(_selectedRange.end),
      );
      if (result['success'] == true) {
        setState(() {
          _summary = result['summary'];
          _bookings = result['bookings'] ?? [];
          _routes = _groupBookingsIntoRoutes(_bookings);
        });
      } else {
        setState(() => _error = result['error'] ?? 'Failed to load history');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _groupBookingsIntoRoutes(List<dynamic> bookings) {
    final Map<dynamic, List<dynamic>> grouped = {};
    for (final b in bookings) {
      final rId = b['route_id'] ?? 0;
      grouped.putIfAbsent(rId, () => []).add(b);
    }

    final List<Map<String, dynamic>> routeList = [];
    grouped.forEach((rId, routeBookings) {
      final first = routeBookings.first;
      
      routeBookings.sort((a, b) {
        final orderA = a['order_in_route'] as int? ?? 0;
        final orderB = b['order_in_route'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      final stops = routeBookings.map((b) {
        final statusStr = b['booking_status'] ?? 'Scheduled';
        return {
          'employee_name': b['employee_name'] ?? 'Passenger',
          'pickup_location': b['pickup_location'] ?? '',
          'drop_location': b['drop_location'] ?? '',
          'estimated_pick_up_time': b['estimated_pickup_time'] ?? '',
          'status': statusStr,
        };
      }).toList();

      final routeCode = first['route_code'] ?? 'Route #$rId';
      final isOut = routeCode.toString().toUpperCase().contains('OUT') || 
                    (first['drop_location'] != null && first['pickup_location'] == null);

      final double? distKm = first['actual_total_distance_km'] is num
          ? (first['actual_total_distance_km'] as num).toDouble()
          : (first['estimated_total_distance_km'] is num
              ? (first['estimated_total_distance_km'] as num).toDouble()
              : null);

      routeList.add({
        'route_id': rId,
        'route_code': routeCode,
        'log_type': isOut ? 'OUT' : 'IN',
        'shift_time': first['estimated_pickup_time'] ?? '',
        'status': first['route_status'] ?? 'Completed',
        'stops': stops,
        'summary': {
          'total_distance_km': distKm,
          'total_time_minutes': first['actual_total_time_minutes'],
        }
      });
    });

    // Sort routes descending by route_id
    routeList.sort((a, b) {
      final idA = a['route_id'] as int? ?? 0;
      final idB = b['route_id'] as int? ?? 0;
      return idB.compareTo(idA);
    });

    return routeList;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context:     context,
      initialDateRange: _selectedRange,
      firstDate:   DateTime.now().subtract(const Duration(days: 365)),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _C.blue, onPrimary: Colors.white, surface: Colors.white, onSurface: _C.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedRange) {
      setState(() => _selectedRange = picked);
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white, statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildDateStrip(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Trip History',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, color: _C.textPrimary, fontSize: 17)),
          Text('Completed routes report',
              style: GoogleFonts.poppins(
                  color: _C.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _C.blue),
          tooltip: 'Refresh',
          onPressed: _fetchHistory,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _C.border, height: 1),
      ),
    );
  }

  Widget _buildDateStrip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: _C.blue),
                    const SizedBox(width: 10),
                    Text(_displayRange(_selectedRange),
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 13, color: _C.textPrimary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _C.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    if (_summary == null || _summary!.isEmpty) return const SizedBox.shrink();

    final totalRoutes   = _summary!['total_routes'] ?? 0;
    final totalBookings = _summary!['total_bookings'] ?? 0;
    final completed     = _summary!['completed'] ?? 0;
    final noShow        = _summary!['no_show'] ?? 0;
    final cancelled     = _summary!['cancelled'] ?? 0;
    final totalKm       = _summary!['total_actual_km'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Summary',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 13.5, color: _C.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem('Routes', '$totalRoutes', _C.blue),
              _summaryItem('Bookings', '$totalBookings', _C.green),
              _summaryItem('Completed', '$completed', _C.green),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryItem('No Show', '$noShow', _C.red),
              _summaryItem('Cancelled', '$cancelled', _C.textSecondary),
              _summaryItem('Total Dist.', '${(totalKm is num ? totalKm.toDouble() : 0.0).toStringAsFixed(1)} km', _C.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, fontSize: 13, color: _C.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 9, fontWeight: FontWeight.w600, color: _C.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _C.blue, strokeWidth: 2.5));
    if (_error != null) return _buildErrorState();
    if (_routes.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _routes.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildSummaryPanel();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildRouteCard(_routes[i - 1]),
        );
      },
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final routeId   = route['route_id'] ?? '—';
    final routeCode = route['route_code'] ?? 'Route #$routeId';
    final logType   = route['log_type'] ?? 'IN';
    final shiftTime = route['shift_time'] ?? '';
    final stops     = route['stops'] as List? ?? [];

    final int completed = stops.where((s) => s['status'] == 'Completed').length;
    final int noShow = stops.where((s) {
      final st = s['status'] ?? '';
      return st == 'NoShow' || st == 'No Show' || st == 'No-Show';
    }).length;

    final double? distKm = route['summary']?['total_distance_km'] is num
        ? (route['summary']['total_distance_km'] as num).toDouble()
        : null;
    final int? mins = route['summary']?['total_time_minutes'] is num
        ? (route['summary']['total_time_minutes'] as num).round()
        : null;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _C.greenBg, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.check_circle_rounded, color: _C.green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routeCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800, fontSize: 14.5, color: _C.textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chip(logType == 'IN' ? 'Pickup' : 'Drop',
                              logType == 'IN' ? _C.greenBg : _C.amberBg,
                              logType == 'IN' ? _C.green   : _C.amber),
                          if (shiftTime.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.access_time_rounded, size: 12, color: _C.textSecondary),
                            const SizedBox(width: 3),
                            Text(shiftTime,
                                style: GoogleFonts.poppins(
                                    fontSize: 11.5, color: _C.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _chip('COMPLETED', _C.greenBg, _C.green, dot: true),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _C.bg,
              border: Border.symmetric(horizontal: BorderSide(color: _C.border)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                _statPill(Icons.people_alt_rounded, '${stops.length}', 'Total', _C.blue),
                const SizedBox(width: 8),
                _statPill(Icons.check_circle_rounded, '$completed', 'Boarded', _C.green),
                const SizedBox(width: 8),
                _statPill(Icons.cancel_rounded, '$noShow', 'No Show',
                    noShow > 0 ? _C.red : _C.textSecondary),
                if (distKm != null) ...[
                  const SizedBox(width: 8),
                  _statPill(Icons.route_rounded,
                      '${distKm.toStringAsFixed(1)} km', 'Distance', _C.amber),
                ],
              ],
            ),
          ),
          if (stops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: stops.asMap().entries.map((e) {
                  final i    = e.key;
                  final stop = e.value;
                  final st   = stop['status'] ?? '';
                  final isDone   = st == 'Completed';
                  final isNoShow = st == 'NoShow' || st == 'No Show' || st == 'No-Show';
                  final name     = stop['employee_name'] ?? 'Passenger';
                  final address  = stop['pickup_location'] ?? stop['drop_location'] ?? '';
                  final eta      = stop['estimated_pick_up_time'] ?? '';

                  final Color dotColor = isDone ? _C.green : (isNoShow ? _C.red : _C.amber);
                  final IconData dotIcon = isDone
                      ? Icons.check_circle_rounded
                      : (isNoShow ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Icon(dotIcon, color: dotColor, size: 18),
                            if (i < stops.length - 1)
                              Container(width: 1.5, height: 20, color: _C.border),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(name,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: _C.textPrimary)),
                                  ),
                                  _chip(
                                    isDone ? 'Boarded' : (isNoShow ? 'No Show' : st),
                                    isDone ? _C.greenBg : (isNoShow ? _C.redBg : _C.amberBg),
                                    isDone ? _C.green   : (isNoShow ? _C.red   : _C.amber),
                                  ),
                                ],
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 11, color: _C.textSecondary),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                              fontSize: 11, color: _C.textSecondary)),
                                    ),
                                  ],
                                ),
                              ],
                              if (eta.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 11, color: _C.textSecondary),
                                    const SizedBox(width: 3),
                                    Text(_formatTime(eta),
                                        style: GoogleFonts.poppins(
                                            fontSize: 11, color: _C.textSecondary)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (mins != null)
            Container(
              decoration: BoxDecoration(
                color: _C.blueBg,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: _C.blue),
                  const SizedBox(width: 6),
                  Text('Total route time: $mins min',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: _C.blue, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: _C.blueBg, shape: BoxShape.circle),
              child: const Icon(Icons.history_rounded, color: _C.blue, size: 34),
            ),
            const SizedBox(height: 18),
            Text('No trips in this range',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _C.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'No completed routes found for the selected range.\nTry a different range.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _C.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.calendar_today_rounded, size: 14, color: _C.blue),
              label: Text('Pick another range',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: _C.blue, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _C.blue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: _C.redBg, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, color: _C.red, size: 30),
            ),
            const SizedBox(height: 16),
            Text('Failed to load history',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _C.textPrimary)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: _C.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchHistory,
              icon: const Icon(Icons.replay_rounded, size: 16, color: Colors.white),
              label: Text('Retry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m  = dt.minute.toString().padLeft(2, '0');
      final p  = dt.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $p';
    } catch (_) { return raw; }
  }

  Widget _chip(String label, Color bg, Color fg, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: GoogleFonts.poppins(
                  color: fg, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 12,
                          color: _C.textPrimary, height: 1.1)),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 8.5, color: _C.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
