import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductApi {
  static Future<Map<String, dynamic>?> fetchProduct(String barcode) async {
    final url = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['items'] != null && data['items'].isNotEmpty) {
        return data['items'][0];
      }
    }

    return null;
  }
}