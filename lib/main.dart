import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yhedzqbxiaqfovyxnoes.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InloZWR6cWJ4aWFxZm92eXhub2VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMTc0MjQsImV4cCI6MjA5NTc5MzQyNH0.BrZ9iplazm-e_2RNjyRJ-LErsGIX9_8pGEe9V6MpiR8',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ojek Online',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const RoleSelectionPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ========== HALAMAN PILIH ROLE ==========
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Peran')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage(role: 'driver')));
              },
              icon: const Icon(Icons.motorcycle),
              label: const Text('Masuk sebagai DRIVER', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage(role: 'rider')));
              },
              icon: const Icon(Icons.person),
              label: const Text('Masuk sebagai RIDER', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== HALAMAN LOGIN (UNIVERSAL) ==========
class LoginPage extends StatefulWidget {
  final String role;
  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan nomor HP')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (widget.role == 'driver') {
        // Cek atau buat driver
        final existing = await Supabase.instance.client
            .from('drivers')
            .select()
            .eq('phone', phone)
            .maybeSingle();
        if (existing == null) {
          await Supabase.instance.client.from('drivers').insert({
            'phone': phone,
            'name': 'Driver $phone',
            'status': 'offline',
            'last_lat': 0.0,
            'last_lng': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DriverHomePage(phone: phone)));
      } else {
        // Rider: cek atau buat di tabel riders (atau users). Buat tabel riders jika belum.
        // Sederhana: kita pakai tabel users untuk rider.
        await _ensureRidersTable();
        final existing = await Supabase.instance.client
            .from('riders')
            .select()
            .eq('phone', phone)
            .maybeSingle();
        if (existing == null) {
          await Supabase.instance.client.from('riders').insert({
            'phone': phone,
            'name': 'Rider $phone',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RiderHomePage(phone: phone)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal login: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureRidersTable() async {
    // Buat tabel riders jika belum ada
    try {
      await Supabase.instance.client.from('riders').select().limit(1);
    } catch (_) {
      await Supabase.instance.client.execute('''
        CREATE TABLE IF NOT EXISTS riders (
          phone TEXT PRIMARY KEY,
          name TEXT,
          created_at TIMESTAMP DEFAULT NOW()
        );
        ALTER TABLE riders DISABLE ROW LEVEL SECURITY;
      ''');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login ${widget.role == 'driver' ? 'Driver' : 'Rider'}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Masukkan nomor HP', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contoh: 081234567890', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('LOGIN / DAFTAR'),
                  ),
          ],
        ),
      ),
    );
  }
}

// ========== HALAMAN DRIVER (SAMA SEPERTI SEBELUMNYA, DIPERBAIKI) ==========
class DriverHomePage extends StatefulWidget {
  final String phone;
  const DriverHomePage({super.key, required this.phone});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool _isOnline = false;
  bool _isLoadingLocation = false;
  Timer? _locationTimer;
  Timer? _orderPollingTimer;
  List<Map<String, dynamic>> _availableOrders = [];
  bool _isLoadingOrders = false;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _loadDriverStatus();
    _requestPermissionsAndStart();
  }

  Future<void> _requestPermissionsAndStart() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _startLocationUpdates();
      _startOrderPolling();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi diperlukan')));
    }
  }

  Future<void> _loadDriverStatus() async {
    try {
      final data = await Supabase.instance.client
          .from('drivers')
          .select('status')
          .eq('phone', widget.phone)
          .single();
      setState(() => _isOnline = data['status'] == 'online');
    } catch (e) {
      print('Error load status: $e');
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_isOnline) await _updateLocation();
    });
    if (_isOnline) _updateLocation();
  }

  Future<void> _updateLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) await Geolocator.requestPermission();
      final position = await Geolocator.getCurrentPosition();
      await Supabase.instance.client.from('drivers').update({
        'last_lat': position.latitude,
        'last_lng': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('phone', widget.phone);
    } catch (e) {
      print('Update lokasi error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _startOrderPolling() {
    _orderPollingTimer?.cancel();
    _orderPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isOnline && _currentOrderId == null) await _fetchAvailableOrders();
    });
  }

  Future<void> _fetchAvailableOrders() async {
    if (_isLoadingOrders) return;
    setState(() => _isLoadingOrders = true);
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('status', 'waiting_for_driver')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _availableOrders = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      print('Error fetch orders: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);
    final newStatus = value ? 'online' : 'offline';
    try {
      await Supabase.instance.client
          .from('drivers')
          .update({'status': newStatus})
          .eq('phone', widget.phone);
      if (value) {
        await _updateLocation();
        await _fetchAvailableOrders();
      } else {
        setState(() => _availableOrders.clear());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ubah status: $e')));
      setState(() => _isOnline = !value);
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    if (_currentOrderId != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sedang mengantar order lain')));
      return;
    }
    final orderId = order['id'];
    try {
      final current = await Supabase.instance.client
          .from('orders')
          .select('status')
          .eq('id', orderId)
          .single();
      if (current['status'] != 'waiting_for_driver') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order sudah diambil driver lain')));
        await _fetchAvailableOrders();
        return;
      }
      await Supabase.instance.client.from('orders').update({
        'status': 'assigned',
        'driver_phone': widget.phone,
      }).eq('id', orderId);
      setState(() {
        _currentOrderId = orderId;
        _availableOrders.removeWhere((o) => o['id'] == orderId);
      });
      _showOrderDetail(order);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menerima order: $e')));
    }
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🛵 Jemput: ${order['pickup_address']}'),
            const SizedBox(height: 8),
            Text('🏁 Tujuan: ${order['dropoff_address']}'),
            const SizedBox(height: 8),
            Text('👤 Penumpang: ${order['rider_phone']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _completeOrder(order['id']);
            },
            child: const Text('SELESAIKAN'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOrder(String orderId) async {
    try {
      await Supabase.instance.client.from('orders').update({
        'status': 'completed',
      }).eq('id', orderId);
      setState(() => _currentOrderId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order selesai')));
      await _fetchAvailableOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal selesaikan: $e')));
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _orderPollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ojek Driver'),
        actions: [
          if (_isLoadingLocation)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Switch(value: _isOnline, onChanged: _toggleOnlineStatus, activeColor: Colors.green),
        ],
      ),
      body: _isOnline
          ? _isLoadingOrders
              ? const Center(child: CircularProgressIndicator())
              : _availableOrders.isEmpty
                  ? const Center(child: Text('Belum ada order. Tunggu sebentar...'))
                  : ListView.builder(
                      itemCount: _availableOrders.length,
                      itemBuilder: (context, index) {
                        final order = _availableOrders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.motorcycle, color: Colors.green),
                            title: Text('Jemput: ${order['pickup_address']}'),
                            subtitle: Text('Tujuan: ${order['dropoff_address']}'),
                            trailing: ElevatedButton(
                              onPressed: () => _acceptOrder(order),
                              child: const Text('TERIMA'),
                            ),
                          ),
                        );
                      },
                    )
          : const Center(child: Text('Aktifkan status ONLINE untuk melihat order', style: TextStyle(fontSize: 16))),
    );
  }
}

// ========== HALAMAN RIDER ==========
class RiderHomePage extends StatefulWidget {
  final String phone;
  const RiderHomePage({super.key, required this.phone});

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  bool _isOrdering = false;
  List<Map<String, dynamic>> _myOrders = [];
  Timer? _orderStatusTimer;

  @override
  void initState() {
    super.initState();
    _fetchMyOrders();
    _startOrderStatusPolling();
  }

  void _startOrderStatusPolling() {
    _orderStatusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchMyOrders();
    });
  }

  Future<void> _fetchMyOrders() async {
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('rider_phone', widget.phone)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _myOrders = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      print('Error fetch my orders: $e');
    }
  }

  Future<void> _placeOrder() async {
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi alamat jemput dan tujuan')));
      return;
    }
    setState(() => _isOrdering = true);
    try {
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      await Supabase.instance.client.from('orders').insert({
        'id': orderId,
        'rider_phone': widget.phone,
        'pickup_address': pickup,
        'dropoff_address': dropoff,
        'status': 'waiting_for_driver',
        'created_at': DateTime.now().toIso8601String(),
      });
      _pickupController.clear();
      _dropoffController.clear();
      await _fetchMyOrders();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order diproses, cari driver...')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal order: $e')));
    } finally {
      setState(() => _isOrdering = false);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting_for_driver': return '⏳ Mencari driver...';
      case 'assigned': return '🛵 Driver ditugaskan';
      case 'completed': return '✅ Selesai';
      default: return status;
    }
  }

  @override
  void dispose() {
    _orderStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ojek Rider')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pesan Ojek', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _pickupController,
              decoration: const InputDecoration(labelText: 'Alamat jemput', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dropoffController,
              decoration: const InputDecoration(labelText: 'Alamat tujuan', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            _isOrdering
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _placeOrder,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('CARI OJEK'),
                  ),
            const SizedBox(height: 30),
            const Text('Riwayat Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_myOrders.isEmpty)
              const Center(child: Text('Belum ada order', style: TextStyle(fontSize: 16)))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myOrders.length,
                itemBuilder: (context, index) {
                  final order = _myOrders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text('Dari: ${order['pickup_address']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ke: ${order['dropoff_address']}'),
                          Text('Status: ${_getStatusText(order['status'])}',
                              style: TextStyle(fontWeight: FontWeight.bold,
                                color: order['status'] == 'completed' ? Colors.green : Colors.orange)),
                          if (order['driver_phone'] != null && order['status'] == 'assigned')
                            Text('Driver: ${order['driver_phone']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}