import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../app_theme.dart';
import '../main.dart';
import '../widgets/spark_animation.dart'; // 1. Importar el widget reutilizable

class SetMasterPasswordScreen extends StatefulWidget {
  const SetMasterPasswordScreen({super.key});

  @override
  State<SetMasterPasswordScreen> createState() => _SetMasterPasswordScreenState();
}

class _SetMasterPasswordScreenState extends State<SetMasterPasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  bool _isPasswordObscured = true;

  // Requisitos y estado de la animación
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  double _passwordStrength = 0.0;
  int _glowTrigger = 0;

  final _uppercaseRegex = RegExp(r'[A-Z]');
  final _numberRegex = RegExp(r'[0-9]');
  final _symbolRegex = RegExp(r'[!@#$%^&*(),.?\":{}|<>]');

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordRequirements);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordRequirements);
    _passwordController.dispose();
    super.dispose();
  }

  void _updatePasswordRequirements() {
    final password = _passwordController.text;
    
    int metRequirements = 0;
    _hasMinLength = password.length >= 8;
    if (_hasMinLength) metRequirements++;
    _hasUppercase = password.contains(_uppercaseRegex);
    if (_hasUppercase) metRequirements++;
    _hasNumber = password.contains(_numberRegex);
    if (_hasNumber) metRequirements++;
    _hasSymbol = password.contains(_symbolRegex);
    if (_hasSymbol) metRequirements++;

    final newStrength = metRequirements / 4.0;

    if (newStrength > _passwordStrength) {
      setState(() {
        _glowTrigger++;
      });
    }

    setState(() {
      _passwordStrength = newStrength;
      if (_errorText != null) {
        _errorText = null;
      }
    });
  }

  String? _getValidationError() {
    // ... (lógica de validación sin cambios)
    if (!_hasMinLength) return 'La contraseña debe tener al menos 8 caracteres.';
    if (!_hasUppercase) return 'Debe contener al menos una letra mayúscula.';
    if (!_hasNumber) return 'Debe contener al menos un número.';
    if (!_hasSymbol) return 'Debe contener al menos un símbolo (ej. !@#\$%)';
    return null;
  }

  Future<void> _setMasterPassword() async {
    // ... (lógica de API sin cambios)
    final validationError = _getValidationError();

    if (validationError != null) {
      setState(() {
        _errorText = validationError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/settings/master-password'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'password': _passwordController.text}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MyHomePage(title: 'DataForge Studio')),
          );
        }
      } else {
        final body = jsonDecode(response.body);
        final message = body['message'] ?? 'Código de estado: ${response.statusCode}';
        throw Exception('Error al guardar la contraseña: $message');
      }
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    // ... (widget de requisitos sin cambios)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.check_circle_outline,
            color: isMet ? AppColors.primary : AppColors.onSurface.withOpacity(0.5),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? AppColors.onSurface : AppColors.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crear Contraseña Maestra',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Esta contraseña se usará para ejecutar queries. Es una configuración de un solo uso y no se puede recuperar o modificar. ¡Guárdala en un lugar seguro!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurface),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  decoration: InputDecoration(
                    labelText: 'Contraseña Maestra',
                    border: const OutlineInputBorder(),
                    errorText: _errorText,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordObscured = !_isPasswordObscured;
                        });
                      },
                    ),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                _buildRequirementRow('Mínimo 8 caracteres', _hasMinLength),
                _buildRequirementRow('Al menos una mayúscula (A-Z)', _hasUppercase),
                _buildRequirementRow('Al menos un número (0-9)', _hasNumber),
                _buildRequirementRow('Al menos un símbolo (!@#\$%)', _hasSymbol),
                const SizedBox(height: 16),
                
                // 2. Usar el nuevo widget SparkAnimation
                SparkAnimation(
                  glowTrigger: _glowTrigger,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: _passwordStrength),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, animatedStrength, child) {
                      return ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        child: LinearProgressIndicator(
                          value: animatedStrength,
                          minHeight: 12,
                          backgroundColor: AppColors.secondary.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(AppColors.secondary.withValues(blue: 2, red: 1.5, green: .5), AppColors.primary, animatedStrength)!,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _setMasterPassword,
                        child: const Text('Guardar y Continuar'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
