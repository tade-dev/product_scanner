import 'package:flutter/material.dart';
import 'package:product_scanner/features/product/product_service.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.productName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Image.network(product.image, height: 200),
            const SizedBox(height: 20),
            Text(product.productName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Price: \$${product.price.toStringAsFixed(2)}"),
          ],
        ),
      ),
    );
  }
}