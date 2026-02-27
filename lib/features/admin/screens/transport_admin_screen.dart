import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';

class TransportAdminScreen extends StatefulWidget {
  const TransportAdminScreen({super.key});

  @override
  State<TransportAdminScreen> createState() => _TransportAdminScreenState();
}

class _TransportAdminScreen {
  final String busNumber;
  final String driver;
  final String driverMobile;
  final String route;
  final int capacity;
  final int assigned;
  final String status;
  _TransportAdminScreen({
    required this.busNumber,
    required this.driver,
    required this.driverMobile,
    required this.route,
    required this.capacity,
    required this.assigned,
    required this.status,
  });
}

class _TransportAdminScreenState extends State<TransportAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final List<_TransportAdminScreen> _buses = [
    _TransportAdminScreen(busNumber: 'SIA-001', driver: 'Ramesh Kumar', driverMobile: '+91 98765 43210', route: 'Zone A – North', capacity: 40, assigned: 38, status: 'Active'),
    _TransportAdminScreen(busNumber: 'SIA-002', driver: 'Suresh Yadav', driverMobile: '+91 97654 32109', route: 'Zone B – East', capacity: 40, assigned: 35, status: 'Active'),
    _TransportAdminScreen(busNumber: 'SIA-003', driver: 'Mahesh Verma', driverMobile: '+91 96543 21098', route: 'Zone C – West', capacity: 45, assigned: 20, status: 'Maintenance'),
    _TransportAdminScreen(busNumber: 'SIA-004', driver: 'Dinesh Singh', driverMobile: '+91 95432 10987', route: 'Zone D – South', capacity: 45, assigned: 42, status: 'Active'),
    _TransportAdminScreen(busNumber: 'SIA-005', driver: 'Vijay Sharma', driverMobile: '+91 94321 09876', route: 'Zone E – Centre', capacity: 50, assigned: 47, status: 'Active'),
  ];

  final List<Map<String, String>> _routes = [
    {'zone': 'Zone A', 'areas': 'Rajpur, Saket, Vasant Kunj', 'stops': '12', 'time': '7:10 AM'},
    {'zone': 'Zone B', 'areas': 'Lajpat Nagar, CR Park, Kalkaji', 'stops': '10', 'time': '7:20 AM'},
    {'zone': 'Zone C', 'areas': 'Dwarka, Janakpuri, Uttam Nagar', 'stops': '15', 'time': '7:05 AM'},
    {'zone': 'Zone D', 'areas': 'Saket, Hauz Khas, Malviya Nagar', 'stops': '8', 'time': '7:30 AM'},
    {'zone': 'Zone E', 'areas': 'Connaught Place, Karol Bagh', 'stops': '6', 'time': '7:40 AM'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Transport Management',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700, fontSize: 20)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Fleet & Drivers'), Tab(text: 'Routes')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connect to Spring Boot /api/transport to add bus'), backgroundColor: AppColors.navy),
        ),
        icon: const Icon(Icons.add),
        label: Text('Add Bus', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildFleetTab(), _buildRoutesTab()],
      ),
    );
  }

  Widget _buildFleetTab() {
    final active = _buses.where((b) => b.status == 'Active').length;
    final maint = _buses.length - active;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary
        Row(children: [
          _statChip('Total Buses', '${_buses.length}', Icons.directions_bus, AppColors.navy),
          const SizedBox(width: 12),
          _statChip('Active', '$active', Icons.check_circle_outline, AppColors.success),
          const SizedBox(width: 12),
          _statChip('Maintenance', '$maint', Icons.build_circle_outlined, AppColors.warning),
        ]),
        const SizedBox(height: 20),
        ..._buses.map((b) => Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
                      ),
                      child: const Icon(Icons.directions_bus, color: AppColors.navy, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.busNumber,
                            style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.navy)),
                        Text(b.route,
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (b.status == 'Active' ? AppColors.success : AppColors.warning)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(b.status,
                          style: GoogleFonts.nunitoSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: b.status == 'Active' ? AppColors.success : AppColors.warning)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _infoTile(Icons.person_outlined, 'Driver', b.driver),
                    ),
                    Expanded(
                      child: _infoTile(Icons.phone_outlined, 'Mobile', b.driverMobile),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Capacity bar
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Capacity: ${b.assigned}/${b.capacity}',
                            style: GoogleFonts.nunitoSans(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: b.assigned / b.capacity,
                            minHeight: 8,
                            backgroundColor: AppColors.border,
                            color: b.assigned >= b.capacity ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                        const PopupMenuItem(value: 'students', child: Text('View Students')),
                        const PopupMenuItem(value: 'maintenance', child: Text('Mark Maintenance')),
                      ],
                      onSelected: (v) => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$v — connect to Spring Boot /api/transport'),
                            backgroundColor: AppColors.navy),
                      ),
                    ),
                  ]),
                ]),
              ),
            )),
      ]),
    );
  }

  Widget _buildRoutesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Route Information',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text('All pickup and drop zones for the current academic year.',
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        ..._routes.map((r) => Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLG)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: AppColors.navy.withOpacity(0.1),
                  child: Text(r['zone']!.split(' ').last,
                      style: GoogleFonts.cormorantGaramond(
                          color: AppColors.navy, fontWeight: FontWeight.w700)),
                ),
                title: Text(r['zone']!,
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, color: AppColors.navy)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['areas']!,
                      style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${r['stops']!} stops · First pick-up: ${r['time']!}',
                      style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 12)),
                ]),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit Route')),
                    PopupMenuItem(value: 'stops', child: Text('View Stops')),
                  ],
                  onSelected: (_) {},
                ),
              ),
            )),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) => Expanded(
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMD)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(label,
                  style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 11),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );

  Widget _infoTile(IconData icon, String label, String value) => Row(children: [
        Icon(icon, size: 16, color: AppColors.textLight),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.nunitoSans(color: AppColors.textLight, fontSize: 11)),
          Text(value, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ]);
}
