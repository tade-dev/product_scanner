import 'package:flutter/material.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product['title'] ?? 'Product')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (product['images'] != null && product['images'].isNotEmpty)
              Image.network(product['images'][0]),
            SizedBox(height: 16),
            Text("Brand: ${product['brand'] ?? 'Unknown'}"),
            Text("Price: ${product['lowest_recorded_price'] ?? 'Unknown'}"),
          ],
        ),
      ),
    );
  }
}