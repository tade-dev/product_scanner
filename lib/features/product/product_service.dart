import 'dart:convert';
import 'package:http/http.dart' as http;

class Product {
  final String productName;
  final String image;
  final double price;

  Product({required this.productName, required this.image, required this.price});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productName: json['productName'],
      image: json['image'],
      price: (json['price'] as num).toDouble(),
    );
  }
}

class ProductService {
  final String baseUrl = 'https://your-mockapi.com/products';

  Future<Product?> fetchProduct(String barcode) async {
    final response = await http.get(Uri.parse('$baseUrl?barcode=$barcode'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) return Product.fromJson(data[0]);
    }
    return null;
  }
}