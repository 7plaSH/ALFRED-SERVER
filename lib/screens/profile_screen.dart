import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Пользователь не авторизован';
          _isLoading = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _profile = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка при загрузке профиля: $e';
        _isLoading = false;
      });
    }
  }

  void _showResponseDialog(BuildContext context, String comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 254, 245, 245),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        contentPadding: const EdgeInsets.all(20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),   
        titlePadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
        title: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 217, 217, 217),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: const Text(
            'Ответ на заявку',
            style: TextStyle(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Container(
          constraints: BoxConstraints(
            minWidth: 400,
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Text(
            comment,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                foregroundColor: const Color.fromARGB(255, 217, 217, 217),
                fixedSize: const Size(100, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: isDark ? Color.fromARGB(255, 57, 56, 56) : Color.fromARGB(255, 65, 65, 65),
        foregroundColor: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 217, 217, 217),
      ),
      body: Container(
        color: isDark ? Color.fromARGB(255, 3, 3, 3) : Color.fromARGB(255, 254, 245, 245),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : _profile == null
                    ? const Center(
                        child: Text('Профиль не найден'),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildProfileField('Имя', _profile!['name'], isDark),
                            _buildProfileField('Фамилия', _profile!['surname'], isDark),
                            _buildProfileField('Отчество', _profile!['patronymic'] ?? 'Не указано', isDark),
                            _buildProfileField('Телефон', _profile!['phone'], isDark),
                            const SizedBox(height: 8),
                            Center(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Color.fromARGB(255, 57, 56, 56) : Color.fromARGB(255, 65, 65, 65),
                                  foregroundColor: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 217, 217, 217),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditProfileScreen(profile: _profile!),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadProfile();
                                  }
                                },
                                child: const Text('Редактировать профиль'),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Тёмная тема',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                                Switch(
                                  value: themeNotifier.value == ThemeMode.dark,
                                  onChanged: (val) async {
                                    final prefs = await SharedPreferences.getInstance();
                                    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                                    await prefs.setBool('isDarkTheme', val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 65, 65, 65),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
} 