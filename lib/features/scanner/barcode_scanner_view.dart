import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:product_scanner/features/history/scan_history.dart';
import 'package:product_scanner/features/product/product_details_page.dart';
import 'package:product_scanner/features/product/product_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late CameraController _cameraController;
  late BarcodeScanner _barcodeScanner;
  bool _isScanning = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.ean13, BarcodeFormat.upca]);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    _cameraController = CameraController(backCamera, ResolutionPreset.medium);

    await _cameraController.initialize();
    await _cameraController.startImageStream(_processCameraImage);

    setState(() => _isInitialized = true);
  }

  InputImageRotation _getRotation() {
    
    final orientations = {
      DeviceOrientation.portraitUp: InputImageRotation.rotation0deg,
      DeviceOrientation.landscapeLeft: InputImageRotation.rotation90deg,
      DeviceOrientation.portraitDown: InputImageRotation.rotation180deg,
      DeviceOrientation.landscapeRight: InputImageRotation.rotation270deg,
    };
    
    return orientations[_cameraController.value.deviceOrientation] ?? 
           InputImageRotation.rotation0deg;
  }

  InputImageFormat _getImageFormat(CameraImage image) {
    switch (image.format.raw) {
      case 35:
        return InputImageFormat.yuv420;
      case 17: 
        return InputImageFormat.nv21;
      default:
        return InputImageFormat.yuv420;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isScanning) return;

    _isScanning = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final InputImageRotation rotation = _getRotation();
      final InputImageFormat format = _getImageFormat(image);
      
      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        final barcodeValue = barcodes.first.rawValue;

        if (barcodeValue != null) {
          HapticFeedback.mediumImpact();
          await _cameraController.stopImageStream();
          await _handleProduct(barcodeValue);
        }
      }
    } catch (e) {
      debugPrint("Error during barcode scan: $e");
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _handleProduct(String barcode) async {
    final product = await ProductService().fetchProduct(barcode);

    if (!mounted) return;

    if (product != null) {
      final historyBox = Hive.box<ScanHistory>('scan_history');
      final entry = ScanHistory(
        barcode: barcode,
        productName: product.productName,
        price: product.price,
        scannedAt: DateTime.now(),
      );
      await historyBox.add(entry);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ).then((_) => _resumeStream());
    } else {
      _showNotFoundSheet(barcode);
    }
  }

  void _showNotFoundSheet(String barcode) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("❌ Product not found", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Barcode: $barcode"),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resumeStream();
              },
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  void _resumeStream() {
    _cameraController.startImageStream(_processCameraImage);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Product')),
      body: _isInitialized
          ? Stack(
              children: [
                CameraPreview(_cameraController),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}