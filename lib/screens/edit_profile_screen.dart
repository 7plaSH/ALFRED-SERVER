import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _patronymicController;
  late final TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['name']);
    _surnameController = TextEditingController(text: widget.profile['surname']);
    _patronymicController = TextEditingController(text: widget.profile['patronymic'] ?? '');
    _phoneController = TextEditingController(text: widget.profile['phone']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _patronymicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      await Supabase.instance.client.from('profiles').update({
        'name': _nameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'patronymic': _patronymicController.text.trim(),
        'phone': _phoneController.text.trim(),
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль успешно обновлен')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при обновлении профиля: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование профиля'),
        backgroundColor: isDark ? Color.fromARGB(255, 57, 56, 56) : Color.fromARGB(255, 65, 65, 65),
        foregroundColor: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 217, 217, 217),
      ),
      body: Container(
        color: isDark ? Color.fromARGB(255, 3, 3, 3) : Color.fromARGB(255, 254, 245, 245),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Имя',
                    labelStyle: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                    filled: true,
                    fillColor: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 255, 255, 255),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите имя';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _surnameController,
                  decoration: InputDecoration(
                    labelText: 'Фамилия',
                    labelStyle: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                    filled: true,
                    fillColor: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 255, 255, 255),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите фамилию';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _patronymicController,
                  decoration: InputDecoration(
                    labelText: 'Отчество',
                    labelStyle: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                    filled: true,
                    fillColor: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 255, 255, 255),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Телефон',
                    labelStyle: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                    filled: true,
                    fillColor: isDark ? Color.fromARGB(255, 44, 44, 44) : Color.fromARGB(255, 255, 255, 255),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 0, 0, 0)),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите телефон';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Color.fromARGB(255, 57, 56, 56) : Color.fromARGB(255, 65, 65, 65),
                    foregroundColor: isDark ? Color.fromARGB(255, 255, 255, 255) : Color.fromARGB(255, 217, 217, 217),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Сохранить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 