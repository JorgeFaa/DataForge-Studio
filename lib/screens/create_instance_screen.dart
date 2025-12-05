import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../app_theme.dart';
import '../widgets/spark_animation.dart';

class CreateInstanceScreen extends StatefulWidget {
  const CreateInstanceScreen({super.key});

  @override
  State<CreateInstanceScreen> createState() => _CreateInstanceScreenState();
}

class _CreateInstanceScreenState extends State<CreateInstanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbNameController = TextEditingController();
  final _userController = TextEditingController(text: 'postgres');
  final _passwordController = TextEditingController();

  String _selectedImageTag = 'latest'; // 1. Estado para el tag de la imagen
  final List<String> _imageTags = ['latest','17' ,'16', '15', '14', '13', '12', '11'];

  bool _isProcessing = false;
  bool _showSpinner = false;
  int _glowTrigger = 0;

  Future<void> _createDatabase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _glowTrigger++;
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    setState(() {
      _showSpinner = true;
    });

    try {
      // 2. Añadir el imageTag al cuerpo de la petición
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/databases'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'dbName': _dbNameController.text,
          'user': _userController.text,
          'password': _passwordController.text,
          'valid': true,
          'imageTag': _selectedImageTag,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        final body = jsonDecode(response.body);
        final message = body['message'] ?? 'Error del servidor';
        throw Exception('Error al crear la base de datos: $message (Código: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showSpinner = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Base de Datos'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _dbNameController,
                    decoration: const InputDecoration(labelText: 'Nombre de la Base de Datos'),
                    validator: (value) => value!.isEmpty ? 'El nombre no puede estar vacío' : null,
                  ),
                  const SizedBox(height: 16),
                  // 3. Dropdown para seleccionar el tag de la imagen
                  DropdownButtonFormField<String>(
                    initialValue: _selectedImageTag,
                    decoration: const InputDecoration(labelText: 'Versión de la Imagen (Tag)'),
                    items: _imageTags.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text('postgres:$value'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedImageTag = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _userController,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    validator: (value) => value!.isEmpty ? 'El usuario es obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña del Usuario'),
                    validator: (value) => value!.isEmpty ? 'La contraseña es obligatoria' : null,
                  ),
                  const SizedBox(height: 32),
                  SparkAnimation(
                    glowTrigger: _glowTrigger,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isProcessing ? null : _createDatabase,
                        child: _showSpinner
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : const Text('Crear Base de Datos'),
                      ),
                    ),
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
