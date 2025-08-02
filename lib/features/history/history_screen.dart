import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:product_scanner/features/history/scan_history.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final historyBox = Hive.box<ScanHistory>('scan_history');

    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: ValueListenableBuilder(
        valueListenable: historyBox.listenable(),
        builder: (context, Box<ScanHistory> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("No history yet."));
          }
          final items = box.values.toList().reversed.toList();

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.productName),
                subtitle: Text('Scanned on: ${item.scannedAt.toLocal()}'),
                trailing: Text('\$${item.price.toStringAsFixed(2)}'),
              );
            },
          );
        },
      ),
    );
  }
}