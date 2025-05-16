import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CityMap(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapMarker {
  final LatLng position;
  final String note;
  final File? image;
  final bool isCompleted; // false = красная (не выполнена), true = зеленая (выполнена)
  final String? comment;

  MapMarker({
    required this.position,
    required this.note,
    this.image,
    this.isCompleted = false,
    this.comment,
  });

  MapMarker copyWith({
    String? note,
    LatLng? position,
    File? image,
    bool? isCompleted,
    String? comment,
  }) {
    return MapMarker(
      note: note ?? this.note,
      position: position ?? this.position,
      image: image ?? this.image,
      isCompleted: isCompleted ?? this.isCompleted,
      comment: comment ?? this.comment,
    );
  }
}

class MyRequestsScreen extends StatelessWidget {
  final List<MapMarker> markers;
  final Function(MapMarker) onMarkerTap;

  const MyRequestsScreen({
    super.key,
    required this.markers,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 40),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: markers.isEmpty
          ? const Center(
              child: Text(
                'Нет созданных заявок',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: markers.length,
              itemBuilder: (context, index) {
                final marker = markers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: Colors.black,
                      size: 36,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Координаты: ${marker.position.latitude.toStringAsFixed(4)}, '
                          '${marker.position.longitude.toStringAsFixed(4)}',
                        ),
                        if (marker.comment != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Ответ: ${marker.comment}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: marker.isCompleted
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.access_time, color: Color.fromARGB(255, 208, 52, 28)),
                    onTap: () {
                      Navigator.pop(context);
                      onMarkerTap(marker);
                    },
                  ),
                );
              },
            ),
    );
  }
}

class CityMap extends StatefulWidget {
  const CityMap({super.key});
  
  @override
  State<CityMap> createState() => _CityMapState();
}

class _CityMapState extends State<CityMap> {
  final MapController mapController = MapController();
  final List<MapMarker> markers = [];
  final ImagePicker _picker = ImagePicker();
  bool isAddingMarker = false;
  File? _selectedImage;
  List<MapMarker> visibleMarkers = []; // Видимые маркеры
  bool showInfoButton = false;         // Показывать ли кнопку

  void _updateVisibleMarkers() {
  final bounds = mapController.camera.visibleBounds; // Получаем границы видимой области
  visibleMarkers = markers.where((marker) => bounds.contains(marker.position)).toList();

  setState(() {
    showInfoButton = visibleMarkers.isNotEmpty && visibleMarkers.isNotEmpty;
  });
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _toggleAddingMode() {
    setState(() {
      isAddingMarker = !isAddingMarker;
      if (!isAddingMarker) _selectedImage = null;
    });
  }

  Future<void> _addMarker(LatLng position) async {
    final note = await _showNoteDialog(context);
    if (note == null || note.isEmpty) return;

    setState(() {
      markers.add(MapMarker(
        position: position,
        note: note,
        image: _selectedImage,
      ));
      isAddingMarker = false;
      _selectedImage = null;
    });
  }

  Future<String?> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),   
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.all(20),
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 217, 217, 217), // Серый фон
            borderRadius: BorderRadius.circular(4.0), // Закругленные углы
          ),
          child: const Text(
            'Заявка',
            style: TextStyle(
              fontSize: 30,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 400,
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Надпись "Описание" над полем ввода
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: const Text(
                      'Описание',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Поле ввода с крестиком
                Row(
                  children: [
                    Expanded(
                    child: Container(
                      height: 35,
                      width: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Color.fromARGB(255, 217, 217, 217)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: TextField(
                        controller: controller,
                        cursorColor: Colors.black,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.only(left: 12, right: 12, top: 1, bottom: 2),
                          border: InputBorder.none,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Крестик для очистки
                  GestureDetector(
                    onTap: () {
                      controller.clear();
                      (context as Element).markNeedsBuild();
                    },
                    child: Container(
                      padding: EdgeInsets.all(1),
                      child: const Icon(Icons.cancel_outlined, size: 25, color: Colors.black),
                    ),
                  ),
                ],
              ),
                
                const SizedBox(height: 20),
                Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 217, 217, 217),
                      fixedSize: const Size(70, 70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Добавить фото',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  ],
                ),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Image.file(_selectedImage!, height: 100),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),  
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 102, 102, 102),
                    foregroundColor: Color.fromARGB(255, 217, 217, 217),
                    fixedSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Сохранить'),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 217, 217, 217),
                    foregroundColor: Color.fromARGB(255, 102, 102, 102),
                    fixedSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                      color: Color.fromARGB(255, 102, 102, 102), // Цвет контура
                      width: 1.0, // Толщина контура
                    ),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _showCommentDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),   
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.only(bottom: 10, top: 10, left: 20, right: 20),
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 217, 217, 217), // Серый фон
            borderRadius: BorderRadius.circular(4.0), // Закругленные углы
          ),
          child: const Text(
            'Ответить на заявку',
            style: TextStyle(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 400,
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Ваш комментарий',
            ),
            maxLines: 3,
          ),
        ),
        actions: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2),  
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 102, 102, 102),
                    foregroundColor: Color.fromARGB(255, 217, 217, 217),
                    fixedSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Сохранить'),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 217, 217, 217),
                    foregroundColor: Color.fromARGB(255, 102, 102, 102),
                    fixedSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                      color: Color.fromARGB(255, 102, 102, 102), // Цвет контура
                      width: 1.0, // Толщина контура
                    ),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _completeMarker(MapMarker marker, String comment) {
    final completedMarker = marker.copyWith(
      isCompleted: true, // Меняем статус
      comment: comment,  // Добавляем комментарий
    );

    // Обновляем данные (пример для локального списка):
    final index = markers.indexOf(marker);
    if (index != -1) {
      markers[index] = completedMarker;
    }
  }

  void _showMarkerInfo(BuildContext context, MapMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),   
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
        actionsAlignment: MainAxisAlignment.center,
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 217, 217, 217), // Серый фон
            borderRadius: BorderRadius.circular(4.0), // Закругленные углы
          ),
          child: Text(
            marker.isCompleted ? 'Заявка выполнена' : 'Заявка',
            style: TextStyle(
              fontSize: 30,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 400,
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Координаты: ${marker.position.latitude.toStringAsFixed(4)}, '
                  '${marker.position.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(marker.note),
                if (marker.image != null) ...[
                  const SizedBox(height: 12),
                  Image.file(marker.image!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: marker.isCompleted ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [
              if (!marker.isCompleted) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 65, 65, 65),
                      foregroundColor: Color.fromARGB(255, 217, 217, 217),
                      fixedSize: const Size(160, 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () async {
                      final comment = await _showCommentDialog(context);
                      if (comment != null && comment.isNotEmpty) {
                        Navigator.pop(context);
                        _completeMarker(marker, comment);
                      }
                    },
                    child: const Text('Ответить на заявку'),
                  ),
                ),
                Spacer(),
              ],
              Padding(
                padding: EdgeInsets.only(right: 2),
                child : TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 217, 217, 217),
                    foregroundColor: Color.fromARGB(255, 102, 102, 102),
                    fixedSize: const Size(100, 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                      color: Color.fromARGB(255, 102, 102, 102), // Цвет контура
                      width: 1.0, // Толщина контура
                    ),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVisibleMarkersInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),   
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
        actionsAlignment: MainAxisAlignment.center,
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 217, 217, 217), // Серый фон
            borderRadius: BorderRadius.circular(4.0), // Закругленные углы
          ),
          child: const Text(
            'Метки в зоне видимости',
            style: TextStyle(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 400,
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: visibleMarkers.map((marker) => Container(
                margin: const EdgeInsets.only(bottom: 8), // Отступ между блоками
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 179, 179, 179), // Тёмно-серый фон
                  borderRadius: BorderRadius.circular(30),
                ),
              child: ListTile(
                leading: Icon(Icons.location_on_outlined, size: 30, color: Colors.black),
                title: Text(
                  "${marker.position.latitude.toStringAsFixed(4)}, "
                  "${marker.position.longitude.toStringAsFixed(4)}",
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMarkerInfo(context, marker);
                },
              ),
            )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 65, 65, 65),
                    foregroundColor: Color.fromARGB(255, 217, 217, 217),
                    fixedSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Назад"),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    const ekbCenter = LatLng(56.8389, 60.6057);
    final ekbBounds = LatLngBounds(
      const LatLng(56.68, 60.45),
      const LatLng(57.00, 60.80),
    );

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: ekbCenter,
              initialZoom: 12.0,
              initialCameraFit: CameraFit.bounds(
                bounds: ekbBounds,
                padding: const EdgeInsets.all(50),
              ),
              minZoom: 9.0,
              maxZoom: 18.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom,
                scrollWheelVelocity: 0.002,
              ),
              cameraConstraint: CameraConstraint.contain(
                bounds: ekbBounds,
              ),
              onTap: isAddingMarker 
                  ? (_, point) => _addMarker(point)
                  : null,

              onPositionChanged: (_, __) => _updateVisibleMarkers(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ekb_map',
              ),
              MarkerLayer(
                markers: markers.map((marker) => Marker(
                  width: 40,
                  height: 30,
                  point: marker.position,
                  key: ValueKey(marker.hashCode),
                  child: GestureDetector(
                    onTap: () => _showMarkerInfo(context, marker),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: marker.isCompleted 
                          ? Colors.green 
                          : Color.fromARGB(255, 208, 52, 28),
                      size: 40,
                    ),
                  ),
                )).toList(),
              ),
                if (showInfoButton)
                  Positioned(
                    left: 10,
                    bottom: 140,
                    child: FloatingActionButton(
                      onPressed: () => _showVisibleMarkersInfo(context),
                      backgroundColor: Color.fromARGB(255, 175, 175, 175),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      child: const Icon(
                        Icons.list,
                        color: Colors.black,
                        size: 40,
                        ),
                    ),
                  ),
            ],
          ),
          Positioned(
          right: 16,
          bottom: 140, // Располагаем выше нижней панели
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Кнопка "+" (увеличение)
              FloatingActionButton(
                mini: false,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.zero,
                    bottomRight: Radius.zero,
                  ),
                ),
                backgroundColor: Color.fromARGB(255, 217, 217, 217),
                onPressed: () {
                  final currentZoom = mapController.camera.zoom;
                  mapController.move(
                    mapController.camera.center,
                    currentZoom + 1,
                  );
                },
                child: const Icon(Icons.add, color: Colors.black, size: 40),
              ),
              const SizedBox(height: 0),
              // Кнопка "-" (уменьшение)
              FloatingActionButton(
                mini: false,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.zero,
                    topRight: Radius.zero,
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                backgroundColor: Color.fromARGB(255, 217, 217, 217),
                onPressed: () {
                  final currentZoom = mapController.camera.zoom;
                  mapController.move(
                    mapController.camera.center,
                    currentZoom - 1,
                  );
                },
                child: const Icon(Icons.remove, color: Colors.black, size: 40),
              ),
            ],
          ),
          ),

          Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 100, // Высота панели
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 101, 98, 98), // Тёмно-серый цвет
              borderRadius: const BorderRadius.vertical( // Закругление только сверху
                top: Radius.circular(18.0), // Радиус закругления
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 217, 217, 217),
                        padding: EdgeInsets.all(13),
                        minimumSize: const Size(58, 58),
                        shape: const CircleBorder(),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MyRequestsScreen(
                              markers: markers,
                              onMarkerTap: (marker) {
                                mapController.move(marker.position, 15);
                                _showMarkerInfo(context, marker);
                              },
                            ),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.bookmark_outline_outlined,
                        color: Color.fromARGB(255, 44, 44, 44),
                        size: 45,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Мои заявки',
                      style: TextStyle(
                        color: Color.fromARGB(255, 201, 201, 201),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 217, 217, 217),
                        padding: EdgeInsets.zero, // Уменьшенные внутренние отступы
                        minimumSize: const Size(58, 58), // Общий размер кнопки
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: const CircleBorder(),
                      ),
                      onPressed: _toggleAddingMode,
                      child: Icon(
                        isAddingMarker ? Icons.close_outlined : Icons.add_circle_outline_rounded,
                        color: const Color.fromARGB(255, 44, 44, 44),
                        size: 56, // Размер иконки
                      ),
                    ),
                    const SizedBox(height: 1), // Увеличенный отступ
                    Text(
                      isAddingMarker ? 'Отменить' : 'Добавить', // Динамический текст
                      style: const TextStyle(
                        color: Color.fromARGB(255, 201, 201, 201), // Белый текст для лучшей читаемости на темном фоне
                        fontSize: 14, // Немного увеличенный размер
                      ),
                    ),
                  ],
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 217, 217, 217),
                        padding: EdgeInsets.all(13),
                        minimumSize: const Size(58, 58),
                        shape: const CircleBorder(),
                      ),
                      onPressed: () {
                      },
                      child: const Icon(
                        Icons.person_outline_outlined,
                        color: Color.fromARGB(255, 44, 44, 44),
                        size: 45,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Профиль',
                      style: TextStyle(
                        color: Color.fromARGB(255, 201, 201, 201),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}