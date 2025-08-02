import 'package:hive/hive.dart';

part 'scan_history.g.dart';

@HiveType(typeId: 0)
class ScanHistory extends HiveObject {
  @HiveField(0)
  final String barcode;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final DateTime scannedAt;

  ScanHistory({
    required this.barcode,
    required this.productName,
    required this.price,
    required this.scannedAt,
  });
}