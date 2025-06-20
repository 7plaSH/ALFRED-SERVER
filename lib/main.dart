import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/api_service.dart';
import 'screens/auth_screen.dart';
import 'config/supabase_config.dart';
import 'screens/profile_screen.dart';
import 'utils/geocoding_utils.dart';
import 'screens/response_screen.dart';
import 'screens/image_view_screen.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.blue,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Color.fromARGB(255, 3, 3, 3),
  appBarTheme: AppBarTheme(
    backgroundColor: Color.fromARGB(255, 57, 56, 56),
    foregroundColor: Color.fromARGB(255, 255, 255, 255),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
    bodyMedium: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
    bodySmall: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
    titleLarge: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
    titleMedium: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
    titleSmall: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
  ),
  iconTheme: const IconThemeData(color: Color.fromARGB(255, 255, 255, 255)),
  colorScheme: ColorScheme.dark(
    primary: Color.fromARGB(255, 33, 150, 243),
    secondary: Color.fromARGB(255, 3, 169, 244),
    background: Color.fromARGB(255, 3, 3, 3),
    surface: Color.fromARGB(255, 44, 44, 44),
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkTheme') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final AuthChangeEvent event = data.event;
    final Session? session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      try {
        final userData = session.user.userMetadata;
        
        final existingProfile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();

        if (existingProfile == null) {
          await Supabase.instance.client.from('profiles').insert({
            'id': session.user.id,
            'name': userData?['name'] ?? '',
            'surname': userData?['surname'] ?? '',
            'patronymic': userData?['patronymic'] ?? '',
            'phone': userData?['phone'] ?? '',
            'email': session.user.email ?? '',
          });
        }
      } catch (e) {
        print('Error creating profile: $e');
      }
    }
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: currentMode,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            return const CityMap();
          }
        }
        return const AuthScreen();
      },
    );
  }
}

class MapMarker {
  final LatLng position;
  final String note;
  final dynamic image;
  final bool isCompleted;
  final String? comment;
  final int? id;
  final String? userName;
  final String? userSurname;
  final String? userPatronymic;
  final String? userId;
  final String? userPhone;

  MapMarker({
    required this.position,
    required this.note,
    this.image,
    this.isCompleted = false,
    this.comment,
    this.id,
    this.userName,
    this.userSurname,
    this.userPatronymic,
    this.userId,
    this.userPhone,
  });

  MapMarker copyWith({
    String? note,
    LatLng? position,
    dynamic image,
    bool? isCompleted,
    String? comment,
    int? id,
    String? userName,
    String? userSurname,
    String? userPatronymic,
    String? userId,
    String? userPhone,
  }) {
    return MapMarker(
      note: note ?? this.note,
      position: position ?? this.position,
      image: image ?? this.image,
      isCompleted: isCompleted ?? this.isCompleted,
      comment: comment ?? this.comment,
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userSurname: userSurname ?? this.userSurname,
      userPatronymic: userPatronymic ?? this.userPatronymic,
      userId: userId ?? this.userId,
      userPhone: userPhone ?? this.userPhone,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 40, color: isDark ? Color.fromARGB(255, 117, 117, 117) : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: isDark ? Color.fromARGB(255, 51, 51, 51) : Color.fromARGB(255, 230, 230, 230),
      ),
      backgroundColor: isDark ? Color.fromARGB(255, 51, 51, 51) : Color.fromARGB(255, 230, 230, 230),
      body: markers.isEmpty
          ? Center(
              child: Text(
                'Нет созданных заявок',
                style: TextStyle(fontSize: 18, color: isDark ? Color.fromARGB(255, 255, 255, 255) : Colors.black),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: markers.length,
              itemBuilder: (context, index) {
                final marker = markers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isDark ? Color.fromARGB(255, 217, 217, 217) : Color.fromARGB(255, 179, 179, 179),
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: isDark ? Color.fromARGB(255, 0, 0, 0) : Colors.black,
                      size: 36,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: marker.comment != null ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            marker.comment != null ? 'Выполнено' : 'Активно',
                            style: TextStyle(
                              color: isDark ? Color.fromARGB(255, 0, 0, 0) : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FutureBuilder<String>(
                          future: GeocodingUtils.getAddressFromLatLng(marker.position),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.hasData ? snapshot.data! : 'Загрузка адреса...',
                              style: TextStyle(fontSize: 16, color: isDark ? Color.fromARGB(255, 0, 0, 0) : Colors.black),
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      if (marker.comment != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResponseScreen(
                              comment: marker.comment!,
                              userId: marker.userId ?? '',
                              position: marker.position,
                              userName: marker.userName,
                              userSurname: marker.userSurname,
                              userPatronymic: marker.userPatronymic,
                              userPhone: marker.userPhone,
                            ),
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                        onMarkerTap(marker);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class UserInfoText extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const UserInfoText({super.key, this.profile});

  String _getValue(String key) {
    if (profile == null) return '';
    final value = profile![key];
    if (value == null) return '';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_getValue('surname')} ${_getValue('name')} ${_getValue('patronymic')}'.trim(),
      style: const TextStyle(fontSize: 16),
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
  List<MapMarker> markers = [];
  final ImagePicker _picker = ImagePicker();
  bool isAddingMarker = false;
  dynamic _selectedImage;
  List<MapMarker> visibleMarkers = [];
  bool showInfoButton = false;
  final ApiService _apiService = ApiService();
  Map<LatLng, List<MapMarker>> clusters = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _refreshTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _loadMarkers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMarkers() async {
    try {
      print('Loading markers from server...');
      final loadedMarkers = await _apiService.getMarkers();
      print('Loaded ${loadedMarkers.length} markers from server');
      for (var marker in loadedMarkers) {
        print('Marker: position=${marker.position}, note=${marker.note}, completed=${marker.isCompleted}');
      }
      
      setState(() {
        markers = loadedMarkers;
      });
      _updateClusters();
      print('Updated markers list, total markers: ${markers.length}');
    } catch (e) {
      print('Error loading markers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке маркеров: $e')),
        );
      }
    }
  }

  void _updateClusters() {
    if (!mounted) return;
    
    final bounds = mapController.camera.visibleBounds;
    final zoom = mapController.camera.zoom;
    final clusterDistance = 16000 / zoom;
    final minClusterSize = zoom <= 10.0 ? 5 : 2;
    
    print('Updating clusters. Zoom: $zoom, Distance: $clusterDistance');
    print('Visible bounds: ${bounds.southWest} to ${bounds.northEast}');
    print('Total markers: ${markers.length}');
    
    final visibleMarkersList = markers.where((marker) => bounds.contains(marker.position)).toList();
    print('Visible markers: ${visibleMarkersList.length}');
    
    final newClusters = <LatLng, List<MapMarker>>{};
    
    final center = bounds.center;
    visibleMarkersList.sort((a, b) {
      final distA = Distance().distance(center, a.position);
      final distB = Distance().distance(center, b.position);
      return distA.compareTo(distB);
    });
    
    for (final marker in visibleMarkersList) {
      bool addedToCluster = false;
      
      LatLng? closestCluster;
      double? minDistance;
      
      for (final clusterCenter in newClusters.keys) {
        final distance = Distance().distance(clusterCenter, marker.position);
        if (distance < clusterDistance && (minDistance == null || distance < minDistance)) {
          minDistance = distance;
          closestCluster = clusterCenter;
        }
      }
      
      if (closestCluster != null) {
        if (!newClusters[closestCluster]!.any((m) => m.id == marker.id)) {
          newClusters[closestCluster]!.add(marker);
          print('Added marker to existing cluster at $closestCluster. Distance: $minDistance');
        }
        addedToCluster = true;
      }
      
      if (!addedToCluster) {
        newClusters[marker.position] = [marker];
        print('Created new cluster at ${marker.position}');
      }
    }
    
    final finalClusters = <LatLng, List<MapMarker>>{};
    final processedClusters = <LatLng>{};
    
    for (final entry in newClusters.entries) {
      if (processedClusters.contains(entry.key)) continue;
      
      var currentCluster = entry.value;
      var currentCenter = entry.key;
      processedClusters.add(currentCenter);
      
      for (final otherEntry in newClusters.entries) {
        if (entry.key == otherEntry.key || processedClusters.contains(otherEntry.key)) continue;
        
        final distance = Distance().distance(currentCenter, otherEntry.key);
        if (distance < clusterDistance) {
          for (final marker in otherEntry.value) {
            if (!currentCluster.any((m) => m.id == marker.id)) {
              currentCluster.add(marker);
            }
          }
          processedClusters.add(otherEntry.key);
          
          double totalLat = 0;
          double totalLng = 0;
          for (final marker in currentCluster) {
            totalLat += marker.position.latitude;
            totalLng += marker.position.longitude;
          }
          currentCenter = LatLng(
            totalLat / currentCluster.length,
            totalLng / currentCluster.length,
          );
        }
      }
      
      // Если кластер маленький (2-4 метки) и зум достаточно большой, распадаем его на отдельные маркеры
      if (currentCluster.length <= 4 && zoom > 15.0) {
        for (final marker in currentCluster) {
          finalClusters[marker.position] = [marker];
        }
      } else if (currentCluster.length >= minClusterSize) {
        finalClusters[currentCenter] = currentCluster;
      } else if (zoom <= 10.0) {
        // При малом зуме добавляем маленькие кластеры к ближайшим большим
        LatLng? closestBigCluster;
        double? minDistance;
        
        for (final bigCluster in finalClusters.entries) {
          if (bigCluster.value.length >= minClusterSize) {
            final distance = Distance().distance(currentCenter, bigCluster.key);
            if (minDistance == null || distance < minDistance) {
              minDistance = distance;
              closestBigCluster = bigCluster.key;
            }
          }
        }
        
        if (closestBigCluster != null) {
          finalClusters[closestBigCluster]!.addAll(currentCluster);
        } else {
          finalClusters[currentCenter] = currentCluster;
        }
      } else {
        for (final marker in currentCluster) {
          finalClusters[marker.position] = [marker];
        }
      }
    }
    
    print('Created ${finalClusters.length} clusters');
    for (final entry in finalClusters.entries) {
      print('Cluster at ${entry.key}: ${entry.value.length} markers');
      for (final marker in entry.value) {
        print('  - Marker at ${marker.position}');
      }
    }
    
    setState(() {
      clusters = finalClusters;
      visibleMarkers = visibleMarkersList;
      showInfoButton = visibleMarkersList.isNotEmpty;
    });
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выборе изображения: $e')),
        );
      }
    }
  }

  void _toggleAddingMode() {
    print('Toggling adding mode. Current state: $isAddingMarker');
    setState(() {
      isAddingMarker = !isAddingMarker;
      if (!isAddingMarker) {
        _selectedImage = null;
        print('Exiting adding mode, cleared selected image');
      } else {
        print('Entering adding mode');
      }
    });
  }

  Future<String?> _showNoteDialog(BuildContext context, LatLng position) async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Color.fromARGB(255, 175, 175, 175) : Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.all(20),
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Color.fromARGB(255, 90, 90, 90) : Color.fromARGB(255, 217, 217, 217),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            'Заявка',
            style: TextStyle(
              fontSize: 30,
              color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 300,
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Адрес',
                    style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 0, 0, 0)),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 40,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Color.fromARGB(255, 217, 217, 217) : Color.fromARGB(255, 255, 255, 255),
                    border: Border.all(color: Color.fromARGB(255, 217, 217, 217)),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: FutureBuilder<String>(
                    future: GeocodingUtils.getAddressFromLatLng(position),
                    builder: (context, snapshot) {
                      return TextField(
                        controller: TextEditingController(text: snapshot.data ?? 'Загрузка адреса...'),
                        readOnly: true,
                        cursorColor: Color.fromARGB(255, 0, 0, 0),
                        style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 12),
                          border: InputBorder.none,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Описание',
                    style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 0, 0, 0)),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 40,
                  width: 400,
                  decoration: BoxDecoration(
                    color: isDark ? Color.fromARGB(255, 217, 217, 217) : Color.fromARGB(255, 255, 255, 255),
                    border: Border.all(color: Color.fromARGB(255, 217, 217, 217)),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: TextField(
                    controller: controller,
                    cursorColor: Color.fromARGB(255, 0, 0, 0),
                    style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 12),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.cancel_outlined, size: 20, color: Color.fromARGB(255, 0, 0, 0)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          controller.clear();
                          (context as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 217, 217, 217),
                        fixedSize: const Size(70, 70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: Color.fromARGB(255, 0, 0, 0),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Добавить фото',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                  ],
                ),
                if (_selectedImage != null)
                  _buildImagePreview(),
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
                        color: Color.fromARGB(255, 102, 102, 102),
                        width: 1.0,
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

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: kIsWeb
          ? FutureBuilder<Uint8List>(
              future: _selectedImage!.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(
                    snapshot.data!,
                    height: 100,
                    fit: BoxFit.cover,
                  );
                }
                return const CircularProgressIndicator();
              },
            )
          : Image.file(
              File(_selectedImage!.path),
              height: 100,
              fit: BoxFit.cover,
            ),
    );
  }

  Future<String?> _showCommentDialog(BuildContext context) async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Color.fromARGB(255, 175, 175, 175) : Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),   
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.only(bottom: 10, top: 10, left: 20, right: 20),
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Color.fromARGB(255, 90, 90, 90) : Color.fromARGB(255, 217, 217, 217),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            'Ответить на заявку',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
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
            decoration: InputDecoration(
              labelText: 'Комментарий',
              labelStyle: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
              filled: true,
              fillColor: isDark ? Color.fromARGB(255, 217, 217, 217) : Color.fromARGB(255, 255, 255, 255),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: isDark ? Color.fromARGB(255, 102, 102, 102) : Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: isDark ? Color.fromARGB(255, 102, 102, 102) : Colors.grey),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear, color: Color.fromARGB(255, 0, 0, 0)),
                onPressed: () {
                  controller.clear();
                },
              ),
            ),
            style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
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
                      color: Color.fromARGB(255, 102, 102, 102),
                      width: 1.0,
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

  void _completeMarker(MapMarker marker, String comment) async {
    try {
      if (marker.id == null) {
        print('Error: Marker ID is null');
        return;
      }
      await _apiService.updateMarker(marker.id!, true, comment);
      await _loadMarkers();
    } catch (e) {
      print('Error completing marker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при обновлении маркера: $e')),
        );
      }
    }
  }

  void _showMarkerInfo(BuildContext context, MapMarker marker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client.auth.currentUser?.id != null
            ? Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', Supabase.instance.client.auth.currentUser!.id)
                .single()
            : Future.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          final userRole = Supabase.instance.client.auth.currentUser?.userMetadata?['role'] as String? ?? 'Пользователь';
          final canRespond = userRole == 'Сотрудник';
          
          return AlertDialog(
            backgroundColor: isDark ? Color.fromARGB(255, 175, 175, 175) : Color.fromARGB(255, 254, 245, 245),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
            contentPadding: const EdgeInsets.all(16),
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            titlePadding: EdgeInsets.zero,
            actionsPadding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
            actionsAlignment: MainAxisAlignment.center,
            title: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Color.fromARGB(255, 90, 90, 90) : Color.fromARGB(255, 217, 217, 217),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                marker.isCompleted ? 'Заявка выполнена' : 'Заявка',
                style: TextStyle(
                  fontSize: 30,
                  color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 300,
                  maxWidth: 380,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заявитель',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Color.fromARGB(255, 217, 217, 217) : Color.fromARGB(255, 255, 255, 255),
                        border: Border.all(color: Color.fromARGB(255, 217, 217, 217)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Builder(
                        builder: (context) {
                          final surname = (marker.userSurname ?? '').toString();
                          final name = (marker.userName ?? '').toString();
                          final patronymic = (marker.userPatronymic ?? '').toString();
                          final fio = ('$surname $name $patronymic').trim();
                          return Text(
                            fio.isNotEmpty ? fio : 'Не указано',
                            style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 0, 0, 0)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Адрес',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Color.fromARGB(255, 217, 217, 217) : Color.fromARGB(255, 255, 255, 255),
                        border: Border.all(color: Color.fromARGB(255, 217, 217, 217)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: FutureBuilder<String>(
                        future: GeocodingUtils.getAddressFromLatLng(marker.position),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.hasData ? snapshot.data! : 'Загрузка адреса...',
                            style: TextStyle(fontSize: 16, color: isDark ? Color.fromARGB(255, 0, 0, 0) : Color.fromARGB(255, 0, 0, 0)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Описание',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Color.fromARGB(255, 217, 217, 217) : Color.fromARGB(255, 255, 255, 255),
                        border: Border.all(color: Color.fromARGB(255, 217, 217, 217)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        marker.note,
                        style: TextStyle(fontSize: 16, color: isDark ? Color.fromARGB(255, 0, 0, 0) : Color.fromARGB(255, 0, 0, 0)),
                      ),
                    ),
                    if (marker.image != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageViewScreen(image: marker.image),
                            ),
                          );
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: marker.image is Uint8List
                                ? Image.memory(
                                    marker.image as Uint8List,
                                    fit: BoxFit.cover,
                                  )
                                : marker.image is File
                                    ? Image.file(
                                        marker.image as File,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        marker.image.toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Text('Ошибка загрузки изображения'),
                                          );
                                        },
                                      ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: marker.isCompleted || !canRespond ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: [
                  if (!marker.isCompleted && canRespond) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                          foregroundColor: const Color.fromARGB(255, 217, 217, 217),
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
                    const Spacer(),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 217, 217, 217),
                        foregroundColor: const Color.fromARGB(255, 102, 102, 102),
                        fixedSize: const Size(100, 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 102, 102, 102),
                            width: 1.0,
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
          );
        },
      ),
    );
  }

  void _showVisibleMarkersInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Color.fromARGB(255, 179, 179, 179) : Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),   
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
        actionsAlignment: MainAxisAlignment.center,
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Color.fromARGB(255, 90, 90, 90) : Color.fromARGB(255, 217, 217, 217),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            'Метки в зоне видимости',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: visibleMarkers.map((marker) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Color.fromARGB(255, 200, 200, 200) : Color.fromARGB(255, 179, 179, 179),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ListTile(
                  leading: Icon(Icons.location_on_outlined, size: 30, color: Colors.black),
                  title: FutureBuilder<String>(
                    future: GeocodingUtils.getAddressFromLatLng(marker.position),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.hasData ? snapshot.data! : 'Загрузка адреса...',
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      );
                    },
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

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выходе из системы: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
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
              minZoom: 9.0,
              maxZoom: 18.0,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(56.50, 60.20),  // юго-западная точка (включая ближайшие города)
                  const LatLng(57.20, 61.00),  // северо-восточная точка (включая ближайшие города)
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                scrollWheelVelocity: 0.002,
              ),
              onTap: isAddingMarker 
                  ? (_, point) => _addMarker(point)
                  : null,
              onPositionChanged: (_, __) {
                print('Map position changed');
                _updateClusters();
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(isDark),
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.ekb_map',
                tileProvider: CancellableNetworkTileProvider(),
                retinaMode: true,
              ),
              MarkerLayer(
                markers: clusters.entries.map((entry) {
                  final markers = entry.value;
                  if (markers.length == 1) {
                    final marker = markers.first;
                    return Marker(
                      width: 70,
                      height: 52,
                      point: marker.position,
                      child: GestureDetector(
                        onTap: () => _showMarkerInfo(context, marker),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: marker.isCompleted 
                                    ? const Color.fromARGB(255, 120, 233, 100)
                                    : const Color.fromARGB(255, 208, 52, 28),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.black,
                              size: 40,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    final center = entry.key;
                    return Marker(
                      width: 80,
                      height: 80,
                      point: center,
                      child: GestureDetector(
                        onTap: () {
                          print('Cluster tapped: ${markers.length} markers');
                          final bounds = LatLngBounds.fromPoints(markers.map((m) => m.position).toList());
                          final padding = 0.2;
                          final zoom = mapController.camera.zoom;
                          final newZoom = zoom + 2;
                          
                          mapController.move(
                            center,
                            newZoom,
                          );
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 65, 65, 65),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              markers.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }).toList(),
              ),
            ],
          ),
          if (showInfoButton)
            Positioned(
              left: 10,
              bottom: 140,
              child: FloatingActionButton(
                onPressed: () => _showVisibleMarkersInfo(context),
                backgroundColor: isDark ? Color.fromARGB(255, 117, 117, 117) : Color.fromARGB(255, 175, 175, 175),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                child: Icon(
                  Icons.list,
                  color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
                  size: 40,
                ),
              ),
            ),
          Positioned(
          right: 16,
          bottom: 140,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                backgroundColor: isDark ? Color.fromARGB(255, 90, 90, 90) : Color.fromARGB(255, 217, 217, 217),
                onPressed: () {
                  final currentZoom = mapController.camera.zoom;
                  mapController.move(
                    mapController.camera.center,
                    currentZoom + 1,
                  );
                },
                child: Icon(Icons.add, color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0), size: 40),
              ),
              const SizedBox(height: 0),
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
                backgroundColor: isDark ? Color.fromARGB(255, 90, 90, 90) : Color.fromARGB(255, 217, 217, 217),
                onPressed: () {
                  final currentZoom = mapController.camera.zoom;
                  mapController.move(
                    mapController.camera.center,
                    currentZoom - 1,
                  );
                },
                child: Icon(Icons.remove, color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0), size: 40),
              ),
            ],
          ),
          ),

          Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? Color.fromARGB(255, 0, 0, 0) : Color.fromARGB(255, 101, 98, 98),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18.0),
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
                        backgroundColor: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 217, 217, 217),
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
                      child: Icon(
                        Icons.bookmark_outline_outlined,
                        color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
                        size: 45,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Мои заявки',
                      style: TextStyle(
                        color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 201, 201, 201),
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
                        backgroundColor: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 217, 217, 217),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(58, 58),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: const CircleBorder(),
                      ),
                      onPressed: _toggleAddingMode,
                      child: Icon(
                        isAddingMarker ? Icons.close_outlined : Icons.add_circle_outline_rounded,
                        color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isAddingMarker ? 'Отменить' : 'Добавить',
                      style: TextStyle(
                        color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 201, 201, 201),
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
                        backgroundColor: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 217, 217, 217),
                        padding: EdgeInsets.all(13),
                        minimumSize: const Size(58, 58),
                        shape: const CircleBorder(),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.person_outline_outlined,
                        color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
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

  Future<void> _addMarker(LatLng position) async {
    print('_addMarker called with position: $position');
    final note = await _showNoteDialog(context, position);
    print('Note from dialog: $note');
    if (note == null || note.isEmpty) {
      print('Note is empty, returning');
      return;
    }

    try {
      print('Creating marker object...');
      // Получаем данные текущего пользователя
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Получаем профиль пользователя
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final marker = MapMarker(
        position: position,
        note: note,
        userName: profile['name'],
        userSurname: profile['surname'],
        userPatronymic: profile['patronymic'],
        userId: user.id,
        userPhone: profile['phone'],
      );

      print('Calling API to add marker...');
      dynamic imageData;
      if (_selectedImage != null) {
        if (kIsWeb) {
          imageData = await _selectedImage!.readAsBytes();
        } else {
          imageData = File(_selectedImage!.path);
        }
      }
      
      await _apiService.addMarker(marker, imageData);
      print('API call successful');

      setState(() {
        isAddingMarker = false;
        _selectedImage = null;
      });

      await _loadMarkers();
    } catch (e) {
      print('Error adding marker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при добавлении маркера: $e')),
        );
      }
    }
  }
}