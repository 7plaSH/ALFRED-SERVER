import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;

void main() async {
  final app = Alfred();
  final db = sqlite3.open('markers.db');


  db.execute('''
    CREATE TABLE IF NOT EXISTS markers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      note TEXT NOT NULL,
      image_path TEXT,
      is_completed INTEGER DEFAULT 0,
      comment TEXT,
      user_id TEXT NOT NULL,
      user_role TEXT NOT NULL,
      user_name TEXT,
      user_surname TEXT,
      user_patronymic TEXT,
      user_phone TEXT
    )
  ''');

 
  final uploadDir = Directory('uploads');
  if (!await uploadDir.exists()) {
    await uploadDir.create(recursive: true);
  }


  app.all('*', (req, res) {
    res.headers.add('Access-Control-Allow-Origin', '*');
    res.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, user-id, user-role');
    
    if (req.method.toUpperCase() == 'OPTIONS') {
      return {'status': 'ok'};
    }
  });


  app.get('/markers', (req, res) {
    String? getHeaderValue(dynamic value) {
      if (value is List && value.isNotEmpty) {
        return value.first as String;
      }
      return value as String?;
    }

    final userRole = Uri.decodeComponent(getHeaderValue(req.headers['user-role']) ?? '');
    final userId = getHeaderValue(req.headers['user-id']);
    
    String query = 'SELECT * FROM markers';
    List<dynamic> params = [];
    
    if (userRole == 'Пользователь') {
      query += ' WHERE user_id = ?';
      params.add(userId);
    }
    
    final markers = db.select(query, params);
    return markers.map((row) => {
      'id': row['id'],
      'lat': row['lat'],
      'lng': row['lng'],
      'note': row['note'],
      'image_path': row['image_path'],
      'is_completed': row['is_completed'] == 1,
      'comment': row['comment'],
      'user_id': row['user_id'],
      'user_role': row['user_role'],
      'user_name': row['user_name'],
      'user_surname': row['user_surname'],
      'user_patronymic': row['user_patronymic'],
      'user_phone': row['user_phone'],
    }).toList();
  });


  app.post('/markers', (req, res) async {
    try {
      print('Received POST request to /markers');
      final data = await req.bodyAsJsonMap;
      print('Request data: $data');
      
      final stmt = db.prepare(
        'INSERT INTO markers (lat, lng, note, image_path, user_id, user_role, user_name, user_surname, user_patronymic, user_phone) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
      );
      
      stmt.execute([
        data['lat'],
        data['lng'],
        data['note'],
        data['imagePath'],
        data['userId'],
        data['userRole'],
        data['userName'],
        data['userSurname'],
        data['userPatronymic'],
        data['userPhone'],
      ]);
      
      final id = db.lastInsertRowId;
      print('Marker added with ID: $id');
      
      final newMarker = db.select(
        'SELECT * FROM markers WHERE id = ?',
        [id]
      ).first;
      
      print('New marker data: $newMarker');
      return {
        'status': 'success',
        'id': id,
        'marker': {
          'id': newMarker['id'],
          'lat': newMarker['lat'],
          'lng': newMarker['lng'],
          'note': newMarker['note'],
          'image_path': newMarker['image_path'],
          'is_completed': newMarker['is_completed'] == 1,
          'comment': newMarker['comment'],
          'user_id': newMarker['user_id'],
          'user_role': newMarker['user_role'],
          'user_name': newMarker['user_name'],
          'user_surname': newMarker['user_surname'],
          'user_patronymic': newMarker['user_patronymic'],
          'user_phone': newMarker['user_phone'],
        }
      };
    } catch (e) {
      print('Error adding marker: $e');
      throw AlfredException(500, 'Failed to add marker: $e');
    }
  });


  app.put('/markers/:id', (req, res) async {
    final id = req.params['id'];
    final data = await req.bodyAsJsonMap;
    db.execute(
      'UPDATE markers SET is_completed = ?, comment = ? WHERE id = ?',
      [data['isCompleted'] ? 1 : 0, data['comment'], id],
    );

    // Если маркер отмечен как выполненный (is_completed == true), запускаем отложенное удаление
    if (data['isCompleted'] == true) {
      Future.delayed(const Duration(minutes: 3), () {
        print('Удаляем маркер с id: $id через 3 минуты после ответа');
        db.execute('DELETE FROM markers WHERE id = ?', [id]);
      });
    }

    return {'status': 'updated'};
  });

  app.post('/upload', (req, res) async {
    print('Received upload request');
    try {
      final body = await req.body;
      print('Request body type: ${body.runtimeType}');
      print('Request body: $body');

      if (body is Map && body['file'] is HttpBodyFileUpload) {
        final fileUpload = body['file'] as HttpBodyFileUpload;
        print('Got file upload: ${fileUpload.filename}, content type: ${fileUpload.contentType}');
        
      
        if (fileUpload.contentType == null || !fileUpload.contentType!.mimeType.startsWith('image/')) {
          throw 'Invalid content type: ${fileUpload.contentType?.mimeType}';
        }
        
        
        final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(fileUpload.filename)}';
        final filePath = path.normalize(path.join('uploads', fileName));
        print('Saving file to: $filePath');
        
        // Создаем директорию, если её нет
        final uploadDir = Directory(path.dirname(filePath));
        if (!await uploadDir.exists()) {
          await uploadDir.create(recursive: true);
        }
        
        final file = File(filePath);
        await file.writeAsBytes(fileUpload.content as List<int>);
        
        print('File saved successfully');
        return {
          'success': true,
          'filePath': filePath.replaceAll(Platform.pathSeparator, '/'),
        };
      }
      
      print('Invalid file format');
      throw 'Invalid file format';
    } catch (e) {
      print('Error handling file upload: $e');
      return {
        'success': false,
        'error': 'Error handling file upload: $e',
      };
    }
  });


  app.get('/uploads/*', (req, res) async {
    try {
      final filePath = path.normalize(req.uri.path.substring(1));
      print('GET ${req.uri.path} - Requested file: $filePath');
      
      final file = File(filePath);
      print('Absolute file path: ${file.absolute.path}');
      
      if (await file.exists()) {
        final ext = path.extension(filePath).toLowerCase();
        final contentType = switch (ext) {
          '.jpg' || '.jpeg' => 'image/jpeg',
          '.png' => 'image/png',
          '.gif' => 'image/gif',
          _ => 'application/octet-stream',
        };
        
        print('File exists, serving with content type: $contentType');
        final fileSize = await file.length();
        print('File size: $fileSize bytes');
        
        res.headers.contentType = ContentType.parse(contentType);
        res.headers.add('Cache-Control', 'public, max-age=31536000');
        await file.openRead().pipe(res);
        print('File served successfully');
        return;
      }
      
      print('File not found at path: ${file.absolute.path}');
      throw AlfredException(404, 'File not found');
    } catch (e) {
      print('Error serving file: $e');
      throw AlfredException(500, 'Error serving file');
    }
  });


  await app.listen(3001);
  print('Server running on port 3001');
}  
