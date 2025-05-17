import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final app = Alfred();
  final db = sqlite3.open('markers.db'); 

  app.all('*', (req, res) {
    res.headers.add('Access-Control-Allow-Origin', '*');
    res.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
    res.headers.add('Access-Control-Allow-Headers', 'Content-Type');
  });

 
  app.get('/markers', (req, res) {
    final markers = db.select('SELECT * FROM markers');
    return markers.map((row) => row.toMap()).toList();
  });

  app.post('/markers', (req, res) async {
    final data = await req.bodyAsJsonMap;
    db.execute(
      'INSERT INTO markers (lat, lng, note, image_path) VALUES (?, ?, ?, ?)',
      [data['lat'], data['lng'], data['note'], data['imagePath']],
    );
    return {'status': 'success', 'id': db.lastInsertRowId};
  });
  
  app.put('/markers/:id', (req, res) async {
    final id = req.params['id'];
    final data = await req.bodyAsJsonMap;
    db.execute(
      'UPDATE markers SET is_completed = ?, comment = ? WHERE id = ?',
      [data['isCompleted'] ? 1 : 0, data['comment'], id],
    );
    return {'status': 'updated'};
  });

  app.post('/upload', (req, res) async {
    final file = await req.body.asFile();
    final fileName = 'uploads/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(fileName).create(recursive: true);
    await file.saveTo(fileName);
    return {'path': fileName};
  });


  app.get('/uploads/*', (req, res) async {
    final file = File(req.uri.path.substring(1));
    if (await file.exists()) {
      await file.openRead().pipe(res.response);
    } else {
      throw AlfredException(404, 'File not found');
    }
  });

  await app.listen(3000);
  print('Server running on http://localhost:3000');
} 
