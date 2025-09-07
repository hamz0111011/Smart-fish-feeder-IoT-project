import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/history_feeding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fish Feeder',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color.fromARGB(255, 159, 213, 252),
      ),
      home: const FishFeederScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FishFeederScreen extends StatefulWidget {
  const FishFeederScreen({super.key});

  @override
  State<FishFeederScreen> createState() => _FishFeederScreenState();
}

class _FishFeederScreenState extends State<FishFeederScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  bool _perangkatOnline = false;
  double _beratSekarang = 0.0;
  double _levelPakan = 0.0;
  bool _sedangMemberiPakan = false;
  bool _peringatanPakanHabis = false;
  bool _peringatanTimeout = false;
  String _jumlahPakanTerpilih = '0.3kg';
  bool _pakanSudahDipilih = false;
  String _waktuSekarang = "--:--:--";
  List<Map<String, dynamic>> _historyFeeding = [];

  @override
  void initState() {
    super.initState();
    _setupPendengarDatabase();
  }

  void _setupPendengarDatabase() {
    // Sensor data
    _databaseRef.child('sensors').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _beratSekarang = (data['weight'] ?? 0.0).toDouble();
          _levelPakan = (data['food_level'] ?? 0.0).toDouble();
        });
      }
    });

    // Pendengar untuk history feeding
    _databaseRef.child('feeding_history').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      if (mounted) {
        List<Map<String, dynamic>> tempHistory = [];
        data.forEach((key, value) {
          tempHistory.add({
            'timestamp': key.toString(),
            'amount': (value['amount'] ?? 0.0).toDouble(),
            'motor_duration': (value['motor_duration'] ?? 0.0).toDouble(),
            'throw_distance': (value['throw_distance'] ?? 0.0).toDouble(),
            'portion': value['portion']?.toString() ?? '0kg',
            'time': value['time']?.toString() ?? '--:--:--',
          });
        });
        setState(() {
          _historyFeeding = tempHistory;
        });
      }
    });

    // Waktu dan tanggal dari Firebase
    _databaseRef.child('time').onValue.listen((event) {
      if (mounted) {
        setState(() {
          _waktuSekarang = event.snapshot.value?.toString() ?? "--:--:--";
        });
      }
    });

    // Status
    _databaseRef.child('status').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _sedangMemberiPakan = data['feeding'] ?? false;
        });
      }
    });

    // Alerts
    _databaseRef.child('alerts').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _peringatanPakanHabis = data['low_food'] ?? false;
          _peringatanTimeout = data['feed_timeout'] ?? false;
        });
      }
    });

    // Connection status
    _databaseRef.child('.info/connected').onValue.listen((event) {
      if (mounted) {
        setState(() {
          _perangkatOnline = event.snapshot.value == true;
        });
      }
    });
  }

  Future<void> _pilihJumlahPakan(String jumlah) async {
    if (!_perangkatOnline) return;

    try {
      await _databaseRef.child('control').update({'feed_amount': jumlah});

      setState(() {
        _jumlahPakanTerpilih = jumlah;
        _pakanSudahDipilih = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jumlah pakan $jumlah dipilih'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih jumlah pakan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _mulaiMemberiPakan() async {
    if (_sedangMemberiPakan || !_perangkatOnline || !_pakanSudahDipilih) return;

    try {
      await _databaseRef.child('control').update({'feed': true});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perintah pakan $_jumlahPakanTerpilih dikirim'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim perintah: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fish Feeder'),
        centerTitle: true,
        elevation: 0,
        actions: [
          Icon(
            Icons.circle,
            color: _perangkatOnline ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKartuStatus(),
            const SizedBox(height: 20),
            _buildIndikatorPakan(),
            const SizedBox(height: 20),
            _buildInfoBeratDanWaktu(),
            const SizedBox(height: 20),
            _buildDataFeeding(),
            const SizedBox(height: 20),
            _buildPemilihJumlahPakan(),
            const SizedBox(height: 20),
            _buildTombolPakan(),
            const SizedBox(height: 20),
            _buildBagianPeringatan(),
            const SizedBox(height: 10),
            _buildDebugInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildKartuStatus() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Icon(
                  Icons.cloud,
                  size: 30,
                  color: _perangkatOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 5),
                Text(
                  _perangkatOnline ? 'TERHUBUNG' : 'OFFLINE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _perangkatOnline ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Icon(
                  Icons.power_settings_new,
                  size: 30,
                  color: _sedangMemberiPakan ? Colors.orange : Colors.green,
                ),
                const SizedBox(height: 5),
                Text(
                  _sedangMemberiPakan ? 'SEDANG BEKERJA' : 'SIAP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _sedangMemberiPakan ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndikatorPakan() {
    final persentaseKapasitas = _levelPakan.clamp(0, 100).toInt();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KAPASITAS PAKAN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 100,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        width: 100,
                        height: 150 * (persentaseKapasitas / 100),
                        decoration: BoxDecoration(
                          color: _warnaKapasitas(persentaseKapasitas),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _warnaKapasitas(persentaseKapasitas).withOpacity(0.8),
                              _warnaKapasitas(persentaseKapasitas),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Column(
                    children: [
                      Text(
                        '$persentaseKapasitas%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _warnaKapasitas(persentaseKapasitas),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusKapasitas(persentaseKapasitas),
                        style: TextStyle(
                          fontSize: 14,
                          color: _warnaKapasitas(persentaseKapasitas),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_peringatanPakanHabis)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: Text(
                    'PERINGATAN: PAKAN HAMPIR HABIS!',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBeratDanWaktu() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.scale, size: 30, color: Colors.blue),
                    const SizedBox(height: 5),
                    const Text(
                      'BERAT SEKARANG',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(_beratSekarang / 1000).toStringAsFixed(2)} kg',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.access_time, size: 30, color: Colors.blue),
                    const SizedBox(height: 5),
                    const Text(
                      'WAKTU SEKARANG',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _waktuSekarang,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPemilihJumlahPakan() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PILIH JUMLAH PAKAN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_buildTombolJumlah('0.3kg'), _buildTombolJumlah('0.5kg')],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _pakanSudahDipilih
                    ? 'Terpilih: $_jumlahPakanTerpilih'
                    : 'Silakan pilih jumlah pakan',
                style: TextStyle(
                  color: _pakanSudahDipilih ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTombolJumlah(String jumlah) {
    return ElevatedButton(
      onPressed: () => _pilihJumlahPakan(jumlah),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _jumlahPakanTerpilih == jumlah ? Colors.blue : Colors.grey[300],
        foregroundColor:
            _jumlahPakanTerpilih == jumlah ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(jumlah),
    );
  }

  Widget _buildTombolPakan() {
    return Center(
      child: ElevatedButton.icon(
        onPressed:
            _sedangMemberiPakan ||
                    !_perangkatOnline ||
                    _peringatanPakanHabis ||
                    !_pakanSudahDipilih
                ? null
                : _mulaiMemberiPakan,
        icon: _sedangMemberiPakan
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.fastfood),
        label: Text(
          _sedangMemberiPakan
              ? 'SEDANG MEMBERI PAKAN...'
              : !_perangkatOnline
                  ? 'PERANGKAT OFFLINE'
                  : _peringatanPakanHabis
                      ? 'PAKAN HAMPIR HABIS'
                      : !_pakanSudahDipilih
                          ? 'PILIH JUMLAH PAKAN'
                          : 'BERI PAKAN $_jumlahPakanTerpilih',
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: _sedangMemberiPakan
              ? Colors.orange
              : (!_perangkatOnline || _peringatanPakanHabis || !_pakanSudahDipilih)
                  ? Colors.grey
                  : Colors.blue,
          disabledBackgroundColor: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildBagianPeringatan() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PERINGATAN SISTEM',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_peringatanTimeout)
              ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('Timeout Pemberian Pakan'),
                subtitle: const Text(
                  'Proses pemberian pakan melebihi batas waktu',
                ),
                tileColor: Colors.red[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            if (_peringatanPakanHabis)
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: const Text('Pakan Hampir Habis'),
                subtitle: const Text('Segera isi ulang pakan'),
                tileColor: Colors.orange[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            if (!_peringatanTimeout && !_peringatanPakanHabis)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Tidak ada peringatan'),
                subtitle: const Text('Sistem berjalan normal'),
                tileColor: Colors.green[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataFeeding() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DATA PEMBERIAN PAKAN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildInfoFeeding('Jumlah', '${_historyFeeding.isNotEmpty ? _historyFeeding.last['amount'].toStringAsFixed(1) : '0'}g', Icons.scale),
                _buildInfoFeeding('Durasi', '${_historyFeeding.isNotEmpty ? _historyFeeding.last['motor_duration'].toStringAsFixed(1) : '0'}s', Icons.timer),
                _buildInfoFeeding('Porsi', _historyFeeding.isNotEmpty ? _historyFeeding.last['portion'] : '0kg', Icons.fastfood),
                _buildInfoFeeding('Terakhir', _historyFeeding.isNotEmpty ? _historyFeeding.last['time'] : '--:--:--', Icons.access_time),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryFeedingScreen(history: _historyFeeding),
                  ),
                );
              },
              child: const Text('Lihat History Lengkap'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoFeeding(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blue),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDebugInfo() {
    return Center(
      child: Text(
        'Data Sensor: ${_levelPakan.toStringAsFixed(1)}% | '
        'Berat: ${_beratSekarang.toStringAsFixed(0)}g | '
        'Waktu: $_waktuSekarang |',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  String _getStatusKapasitas(int persentase) {
    if (persentase > 90) return 'PENUH';
    if (persentase > 60) return 'CUKUP';
    if (persentase > 20) return 'SEDIKIT';
    if (persentase > 3) return 'HAMPIR HABIS';
    return 'KOSONG';
  }

  Color _warnaKapasitas(int persentase) {
    if (persentase > 60) return Colors.green;
    if (persentase > 30) return Colors.lightGreen;
    if (persentase > 15) return Colors.orange;
    return Colors.red;
  }
}