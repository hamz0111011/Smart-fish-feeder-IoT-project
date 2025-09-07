import 'package:flutter/material.dart';

class HistoryFeedingScreen extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const HistoryFeedingScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History Pemberian Pakan'),
      ),
      body: history.isEmpty
          ? const Center(child: Text('Belum ada data history'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktu: ${item['time']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Jumlah: ${item['amount'].toStringAsFixed(1)}g'),
                            Text('Porsi: ${item['portion']}')
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Durasi: ${item['motor_duration'].toStringAsFixed(1)}s'),
                            Text('jarak lontar: ${item['throw_distance'].toStringAsFixed(1)}cm')
                          ],
                        ),
                        Text('ID: ${item['timestamp']}', 
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}