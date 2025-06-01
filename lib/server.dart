import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final app = Alfred();
  final db = sqlite3.open('markers.db'); // Постоянное хранилище

  // Включение CORS
  app.all('*', (req, res) {
    res.headers.add('Access-Control-Allow-Origin', '*');
    res.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
    res.headers.add('Access-Control-Allow-Headers', 'Content-Type');
  });

  // Получение всех маркеров
  app.get('/markers', (req, res) {
    final markers = db.select('SELECT * FROM markers');
    return markers.map((row) => {
      'id': row['id'],
      'lat': row['lat'],
      'lng': row['lng'],
      'note': row['note'],
      'image_path': row['image_path'],
      'is_completed': row['is_completed'] == 1,
      'comment': row['comment']
    }).toList();
  });

  // Добавление нового маркера
  app.post('/markers', (req, res) async {
    final data = await req.bodyAsJsonMap;
    db.execute(
      'INSERT INTO markers (lat, lng, note, image_path) VALUES (?, ?, ?, ?)',
      [data['lat'], data['lng'], data['note'], data['imagePath']],
    );
    return {'status': 'success', 'id': db.lastInsertRowId};
  });

  // Обновление маркера (например, отметка о выполнении)
  app.put('/markers/:id', (req, res) async {
    final id = req.params['id'];
    final data = await req.bodyAsJsonMap;
    db.execute(
      'UPDATE markers SET is_completed = ?, comment = ? WHERE id = ?',
      [data['isCompleted'] ? 1 : 0, data['comment'], id],
    );
    return {'status': 'updated'};
  });

  // Загрузка изображений
  app.post('/upload', (req, res) async {
    final body = await req.body;
    if (body is! HttpBodyFileUpload) {
      throw AlfredException(400, 'No file uploaded');
    }
    
    final fileName = 'uploads/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Directory('uploads').create(recursive: true);
    final file = await File(fileName).create(recursive: true);
    await file.writeAsBytes(body.content);
    return {'path': fileName};
  });

  // Статика для загруженных файлов
  app.get('/uploads/*', (req, res) async {
    final file = File(req.uri.path.substring(1));
    if (await file.exists()) {
      res.headers.contentType = ContentType.parse('image/jpeg');
      await file.openRead().pipe(res);
    } else {
      throw AlfredException(404, 'File not found');
    }
  });

  await app.listen(3000);
  print('Server running on http://localhost:3000');
}  
