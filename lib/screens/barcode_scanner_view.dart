import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:product_scanner/api/product_api.dart';
import 'package:product_scanner/screens/product_details_page.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView>
    with TickerProviderStateMixin {
  late CameraController _cameraController;
  late BarcodeScanner _barcodeScanner;
  late AnimationController _scanAnimationController;
  late AnimationController _pulseController;
  bool _isDetecting = false;
  bool _isScanning = true;
  bool _barcodeDetected = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _barcodeScanner = BarcodeScanner();
    
    // Initialize animation controllers
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
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
      setState(() {
        _isScanning = true;
        _barcodeDetected = false;
      });
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
      
      // Trigger detection animation
      setState(() {
        _barcodeDetected = true;
        _isScanning = false;
      });
      
      // Add haptic feedback
      HapticFeedback.lightImpact();
      
      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        _cameraController.stopImageStream();

        // Wait for animation to complete before API call
        await Future.delayed(const Duration(milliseconds: 800));

        final product = await ProductApi.fetchProduct(barcode.rawValue ?? '');

        if (!mounted) return;

        if (product != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Product not found"),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
          );
          _resumeStream();
        }
      }
    }
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _pulseController.dispose();
    _cameraController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  Widget _buildScanningOverlay() {
    return Stack(
      children: [
        // Dark overlay with cutout
        Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _barcodeDetected ? Colors.green : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            )
                .animate(target: _barcodeDetected ? 1 : 0)
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1))
                .then()
                .shake(hz: 2, curve: Curves.easeInOut),
          ),
        ),
        
        // Scanning line animation
        if (_isScanning && !_barcodeDetected)
          Center(
            child: Container(
              width: 250,
              height: 250,
              child: AnimatedBuilder(
                animation: _scanAnimationController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _scanAnimationController.value * 220,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.red.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        
        // Corner indicators
        Center(
          child: Container(
            width: 250,
            height: 250,
            child: Stack(
              children: [
                // Top-left corner
                Positioned(
                  top: -3,
                  left: -3,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 4),
                        left: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ).animate().scale(delay: 200.ms).fadeIn(),
                ),
                // Top-right corner
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 4),
                        right: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ).animate().scale(delay: 400.ms).fadeIn(),
                ),
                // Bottom-left corner
                Positioned(
                  bottom: -3,
                  left: -3,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 4),
                        left: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ).animate().scale(delay: 600.ms).fadeIn(),
                ),
                // Bottom-right corner
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 4),
                        right: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ).animate().scale(delay: 800.ms).fadeIn(),
                ),
              ],
            ),
          ),
        ),
        
        // Success checkmark animation
        if (_barcodeDetected)
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            )
                .animate()
                .scale(begin: const Offset(0, 0), end: const Offset(1, 1))
                .fadeIn()
                .then()
                .shimmer(duration: 1000.ms, color: Colors.white.withOpacity(0.5)),
          ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _barcodeDetected 
                        ? "✓ Barcode Detected!" 
                        : "Point camera at barcode",
                    style: TextStyle(
                      color: _barcodeDetected ? Colors.green : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ).animate().slideY(begin: 1, delay: 1000.ms).fadeIn(),
          
          if (!_barcodeDetected)
            const SizedBox(height: 16),
          
          if (!_barcodeDetected)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.center_focus_strong,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            )
                .animate(delay: 1200.ms)
                .slideY(begin: 1)
                .fadeIn()
                .then()
                .shimmer(duration: 2000.ms, delay: 3000.ms),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .rotate(duration: 2000.ms),
              const SizedBox(height: 24),
              const Text(
                "Initializing Camera...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Product")
            .animate()
            .slideX(begin: -1, duration: 600.ms)
            .fadeIn(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ).animate().scale(delay: 300.ms),
      ),
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_cameraController)
                .animate()
                .fadeIn(duration: 800.ms),
          ),
          
          // Scanning overlay
          _buildScanningOverlay(),
          
          // Instructions
          _buildInstructions(),
        ],
      ),
    );
  }
}