import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeocodingUtils {
  static final Map<String, String> _addressCache = {};

  static String _getCacheKey(LatLng position) {
    return '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
  }

  static Future<String> getAddressFromLatLng(LatLng position) async {
    final cacheKey = _getCacheKey(position);
    

    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey]!;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1'
        ),
        headers: {
          'User-Agent': 'MapProject/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        
        if (address != null) {
          String street = address['road'] ?? '';
          String houseNumber = address['house_number'] ?? '';
          
          if (street.isNotEmpty) {
            String result = street;
            if (houseNumber.isNotEmpty) {
              result += ', $houseNumber';
            }
            _addressCache[cacheKey] = result;
            return result;
          }
        }
      }
      return 'Адрес не найден';
    } catch (e) {
      print('Error getting address: $e');
      return 'Ошибка получения адреса';
    }
  }
} 