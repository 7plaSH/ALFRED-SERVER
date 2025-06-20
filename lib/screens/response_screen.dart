import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/geocoding_utils.dart';
import 'package:latlong2/latlong.dart';

class ResponseScreen extends StatefulWidget {
  final String comment;
  final String userId;
  final LatLng position;
  final String? userName;
  final String? userSurname;
  final String? userPatronymic;
  final String? userPhone;

  const ResponseScreen({
    super.key,
    required this.comment,
    required this.userId,
    required this.position,
    this.userName,
    this.userSurname,
    this.userPatronymic,
    this.userPhone,
  });

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String _address = 'Загрузка адреса...';

  @override
  void initState() {
    super.initState();
    if (widget.userName == null && widget.userSurname == null && widget.userPatronymic == null) {
      _loadProfile();
    } else {
      _isLoading = false;
    }
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final address = await GeocodingUtils.getAddressFromLatLng(widget.position);
      if (mounted) {
        setState(() {
          _address = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = 'Не удалось загрузить адрес';
        });
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();
      setState(() {
        _profile = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProfileField(String value, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 217, 217, 217),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.black : const Color.fromARGB(255, 65, 65, 65),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField(String value, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.white,
        border: Border.all(color: const Color.fromARGB(255, 217, 217, 217)),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 65, 65, 65)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String fio = '';
    String phone = '';
    if (widget.userSurname != null || widget.userName != null || widget.userPatronymic != null) {
      fio = '${widget.userSurname ?? ''} ${widget.userName ?? ''} ${widget.userPatronymic ?? ''}'.trim();
    } else if (_profile != null) {
      fio = '${_profile!['surname']} ${_profile!['name']} ${_profile!['patronymic'] ?? ''}'.trim();
    }
    if (widget.userPhone != null && widget.userPhone!.isNotEmpty) {
      phone = widget.userPhone!;
    } else if (_profile != null && _profile!['phone'] != null) {
      phone = _profile!['phone'];
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 30),
                Flexible(
                  child: Text(
                    _address,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 30),
              ],
            ),
            Positioned(
              left: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 30,
                  color: isDark ? Color.fromARGB(255, 179, 179, 179) : Colors.black,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark
            ? const Color.fromARGB(255, 90, 90, 90)
            : const Color.fromARGB(255, 179, 179, 179),
        foregroundColor: isDark ? Colors.white : const Color.fromARGB(255, 65, 65, 65),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Container(
        color: isDark
            ? const Color.fromARGB(255, 179, 179, 179)
            : const Color.fromARGB(255, 254, 245, 245),
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (fio.isNotEmpty) ...[
                            _buildProfileField(fio, isDark),
                          ],
                          if (phone.isNotEmpty) ...[
                            _buildProfileField(phone, isDark),
                            const SizedBox(height: 12),
                          ],
                          _buildCommentField(widget.comment, isDark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                      foregroundColor: const Color.fromARGB(255, 217, 217, 217),
                      fixedSize: const Size(100, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Назад"),
                  ),
                ],
              ),
      ),
    );
  }
} 