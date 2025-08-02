import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:product_scanner/api/product_api.dart';
import 'package:product_scanner/screens/product_details_page.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  late CameraController _cameraController;
  late BarcodeScanner _barcodeScanner;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _barcodeScanner = BarcodeScanner();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.back);
    _cameraController = CameraController(backCamera, ResolutionPreset.medium);
    await _cameraController.initialize();

    _cameraController.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;
      _processCameraImage(image).then((_) {
        _isDetecting = false;
      });
    });

    if (mounted) setState(() {});
  }

  void _resumeStream() async {
    if (!_cameraController.value.isStreamingImages) {
      await _cameraController.startImageStream(_processCameraImage);
      setState(() {
        _isDetecting = true;
      });
    }
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
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
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
      final barcode = barcodes.first;
      log('Detected barcode: ${barcode.rawValue}');
      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        _cameraController.stopImageStream();

        final product = await ProductApi.fetchProduct(barcode.rawValue ?? '');

        if (!mounted) return;

        if (product != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Product not found")));
          _resumeStream();
        }
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) return Container();

    return Scaffold(
      appBar: AppBar(title: Text("Scan Product")),
      body: CameraPreview(_cameraController),
    );
  }
}