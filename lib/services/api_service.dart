import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3001';

  // Получение всех маркеров
  Future<List<MapMarker>> getMarkers() async {
    print('Fetching markers from server...');
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userRole = user?.userMetadata?['role'] as String? ?? 'Пользователь';
      
      final response = await http.get(
        Uri.parse('$baseUrl/markers'),
        headers: {
          'user-id': user?.id ?? '',
          'user-role': Uri.encodeComponent(userRole),
        },
      );
      
      print('GET /markers response status: ${response.statusCode}');
      print('GET /markers response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Parsed ${data.length} markers from response');
        
        final markers = await Future.wait(data.map((json) async {
          dynamic image;
          if (json['image_path'] != null) {
            try {
              final imageUrl = '$baseUrl/${json['image_path']}';
              print('Fetching image from: $imageUrl');
              final imageResponse = await http.get(Uri.parse(imageUrl));
              if (imageResponse.statusCode == 200) {
                final contentType = imageResponse.headers['content-type'];
                if (contentType?.startsWith('image/') ?? false) {
                  image = imageResponse.bodyBytes;
                  print('Successfully loaded image, size: ${image.length} bytes');
                } else {
                  print('Invalid content type for image: $contentType');
                }
              } else {
                print('Failed to load image: ${imageResponse.statusCode}');
              }
            } catch (e) {
              print('Error loading image: $e');
            }
          }

          final marker = MapMarker(
            id: json['id'],
            position: LatLng(json['lat'], json['lng']),
            note: json['note'],
            image: image,
            isCompleted: json['is_completed'] as bool,
            comment: json['comment'],
            userId: json['user_id'],
            userName: json['user_name'],
            userSurname: json['user_surname'],
            userPatronymic: json['user_patronymic'],
            userPhone: json['user_phone'],
          );
          print('Created marker: id=${marker.id}, position=${marker.position}, completed=${marker.isCompleted}');
          return marker;
        }));
        
        print('Returning ${markers.length} markers');
        return markers;
      }
      throw Exception('Failed to load markers: ${response.statusCode}');
    } catch (e) {
      print('Error in getMarkers: $e');
      rethrow;
    }
  }

  // Добавление нового маркера
  Future<void> addMarker(MapMarker marker, dynamic image) async {
    print('Adding new marker...');
    print('Marker data: position=${marker.position}, note=${marker.note}');
    
    final user = Supabase.instance.client.auth.currentUser;
    final userRole = user?.userMetadata?['role'] as String? ?? 'Пользователь';
    
    String? imagePath;
    if (image != null) {
      print('Uploading image...');
      final uploadResult = await _uploadImage(image);
      imagePath = uploadResult['filePath'];
      print('Image uploaded successfully, path: $imagePath');
    }
    
    print('Sending POST request to /markers...');
    final response = await http.post(
      Uri.parse('$baseUrl/markers'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'lat': marker.position.latitude,
        'lng': marker.position.longitude,
        'note': marker.note,
        'imagePath': imagePath,
        'userId': user?.id,
        'userRole': userRole,
        'userName': marker.userName,
        'userSurname': marker.userSurname,
        'userPatronymic': marker.userPatronymic,
        'userPhone': marker.userPhone,
      }),
    );
    
    print('POST /markers response status: ${response.statusCode}');
    print('POST /markers response body: ${response.body}');
    
    if (response.statusCode != 200) {
      throw Exception('Failed to add marker');
    }

    // Отправляем уведомление администраторам через Supabase Edge Function
    try {
      final userProfile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user?.id ?? '')
          .single();

      print('Отправка уведомления администраторам...');
      print('Данные пользователя: ${userProfile.toString()}');
      
      final notificationData = {
        'markerData': {
          'lat': marker.position.latitude,
          'lng': marker.position.longitude,
          'note': marker.note,
          'phone': userProfile['phone'] ?? '',
          'userName': '${userProfile['name'] ?? ''} ${userProfile['surname'] ?? ''}',
        }
      };
      print('Данные для уведомления: ${notificationData.toString()}');

      // Вызов Edge Function (название функции укажи как в Supabase, например resend-email)
      final response = await Supabase.instance.client.functions.invoke('resend-email', body: notificationData);
      print('Ответ от функции resend-email: ${response.data}');
    } catch (e) {
      print('Error sending notification to admins: $e');
      // Не прерываем выполнение, если отправка уведомления не удалась
    }
  }

  // Обновление статуса маркера
  Future<void> updateMarker(int id, bool isCompleted, String? comment) async {
    final response = await http.put(
      Uri.parse('$baseUrl/markers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'isCompleted': isCompleted,
        'comment': comment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update marker');
    }
  }

  // Загрузка изображения
  Future<Map<String, dynamic>> _uploadImage(dynamic image) async {
    print('Starting image upload...');
    try {
      late List<int> bytes;
      late String contentType;
      String filename = DateTime.now().millisecondsSinceEpoch.toString();

      if (image is File) {
        bytes = await image.readAsBytes();
        contentType = 'image/jpeg';
      } else if (image is Uint8List) {
        bytes = image;
        contentType = 'image/jpeg';
      } else {
        throw Exception('Unsupported image type');
      }

      print('Image size: ${bytes.length} bytes');

      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '$filename.jpg',
          contentType: MediaType.parse(contentType),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }
} 