import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _selectedRole;
  bool _showAdminCode = false;
  final List<String> _roles = ['Сотрудник', 'Пользователь'];
  final String _adminCode = '1234';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _adminCodeController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _patronymicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onRoleChanged(String? value) {
    setState(() {
      _selectedRole = value;
      _showAdminCode = value == 'Сотрудник';
      if (!_showAdminCode) {
        _adminCodeController.clear();
      }
    });
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSignUp && _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите роль')),
      );
      return;
    }

    if (_isSignUp && _showAdminCode && _adminCodeController.text != _adminCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный код сотрудника')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'role': _selectedRole,
            'name': _nameController.text.trim(),
            'surname': _surnameController.text.trim(),
            'patronymic': _patronymicController.text.trim(),
            'phone': _phoneController.text.trim(),
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Проверьте вашу почту для подтверждения регистрации')),
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${error.toString()}')),
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
    return Scaffold(
      body: Container(
        color: const Color.fromARGB(255, 254, 245, 245),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'animal map',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 44, 44, 44),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Электронная почта',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, введите email';
                      }
                      if (!value.contains('@')) {
                        return 'Пожалуйста, введите корректный email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, введите пароль';
                      }
                      if (value.length < 6) {
                        return 'Пароль должен быть не менее 6 символов';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Имя',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Телефон',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите телефон';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Выберите роль',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _roles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: _onRoleChanged,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, выберите роль';
                        }
                        return null;
                      },
                    ),
                    if (_showAdminCode) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adminCodeController,
                        decoration: InputDecoration(
                          labelText: 'Код администратора',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Пожалуйста, введите код администратора';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                          foregroundColor: const Color.fromARGB(255, 217, 217, 217),
                          fixedSize: const Size(300, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleAuth,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _isSignUp ? 'Зарегистрироваться' : 'Войти',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 217, 217, 217),
                          foregroundColor: const Color.fromARGB(255, 65, 65, 65),
                          fixedSize: const Size(300, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                            side: const BorderSide(
                              color: Color.fromARGB(255, 65, 65, 65),
                              width: 1.0,
                            ),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _selectedRole = null;
                            _showAdminCode = false;
                            _adminCodeController.clear();
                            _nameController.clear();
                            _surnameController.clear();
                            _patronymicController.clear();
                            _phoneController.clear();
                          });
                        },
                        child: Text(
                          _isSignUp
                              ? 'Уже есть аккаунт? Войти'
                              : 'Нет аккаунта? Зарегистрироваться',
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 