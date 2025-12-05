import 'dart:async';
import 'dart:convert';
import 'package:data_forge_studio/widgets/app_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_theme.dart';
import 'models/database_model.dart';
import 'screens/create_instance_screen.dart';
import 'screens/database_detail_screen.dart';
import 'screens/set_master_password_screen.dart';

// Modelo para el endpoint de descubrimiento
class DiscoveredInstance {
  final String containerId;
  final String containerName;
  final String image;
  final String status;
  final String dbName;
  final String dbUser;
  final String dbPassword;
  final int hostPort;

  DiscoveredInstance.fromJson(Map<String, dynamic> json)
      : containerId = json['containerId'],
        containerName = json['containerName'],
        image = json['image'],
        status = json['status'],
        dbName = json['dbName'],
        dbUser = json['dbUser'],
        dbPassword = json['dbPassword'],
        hostPort = json['hostPort'];

  Map<String, dynamic> toJson() => {
        'containerId': containerId,
        'containerName': containerName,
        'image': image,
        'status': status,
        'dbName': dbName,
        'dbUser': dbUser,
        'dbPassword': dbPassword,
        'hostPort': hostPort,
      };
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataForge Studio',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingMessage = 'Iniciando...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _loadingMessage = 'Verificando estado de la API...';
      });
      final healthResponse = await http.get(Uri.parse('${ApiConfig.baseUrl}/actuator/health'));
      if (healthResponse.statusCode != 200) {
        throw Exception('La API no está disponible. Estado: ${healthResponse.statusCode}');
      }

      setState(() {
        _loadingMessage = 'Verificando conexión con Docker...';
      });
      final dockerResponse = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/status'));
      if (dockerResponse.statusCode != 200) {
        throw Exception('No se pudo conectar al daemon de Docker. Estado: ${dockerResponse.statusCode}');
      }

      setState(() {
        _loadingMessage = 'Verificando configuración...';
      });
      final isPasswordSetResponse = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/settings/master-password/is-set'));
      if (isPasswordSetResponse.statusCode != 200) {
        throw Exception('Error al verificar la configuración. Estado: ${isPasswordSetResponse.statusCode}');
      }

      final Map<String, dynamic> isPasswordSetBody = jsonDecode(isPasswordSetResponse.body);
      final isPasswordSet = isPasswordSetBody['isSet'] as bool;

      if (mounted) {
        if (isPasswordSet) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MyHomePage(title: 'DataForge Studio')),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SetMasterPasswordScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLoadingIndicator(), // Usar el nuevo widget
            const SizedBox(height: 20),
            Text(_loadingMessage),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = true;
  List<Database> _databases = [];
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();
  Color _appBarColor = AppColors.surface;

  @override
  void initState() {
    super.initState();
    _fetchDatabases();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    const double maxScroll = 200.0;
    final double offset = _scrollController.hasClients ? _scrollController.offset : 0;
    final double percentage = (offset / maxScroll).clamp(0.0, 1.0);
    final newColor = Color.lerp(AppColors.surface, AppColors.primary.withOpacity(0.8), percentage)!;

    if (_appBarColor != newColor) {
      setState(() {
        _appBarColor = newColor;
      });
    }
  }

  Future<void> _fetchDatabases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/databases'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _databases = data.map((json) => Database.fromJson(json)).toList();
        });
      } else {
        throw Exception('Error al cargar las bases de datos: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startDatabase(int dbId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/databases/$dbId/start'));
      if (response.statusCode == 200) {
        messenger.showSnackBar(SnackBar(content: Text(response.body), backgroundColor: Colors.green));
        _fetchDatabases();
      } else {
        throw Exception('Error al iniciar: ${response.body}');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _stopDatabase(int dbId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/databases/$dbId/stop'));
      if (response.statusCode == 200) {
        messenger.showSnackBar(SnackBar(content: Text(response.body), backgroundColor: AppColors.primary));
        _fetchDatabases();
      } else {
        throw Exception('Error al detener: ${response.body}');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _testConnection(int dbId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/databases/$dbId/test-connection'));
      if (response.statusCode == 200) {
        messenger.showSnackBar(SnackBar(content: Text(response.body), backgroundColor: Colors.green));
      } else {
        throw Exception('Error: ${response.body}');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _deleteDatabase(int dbId) async {
    final String? deleteType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gestionar Base de Datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_forever, color: AppColors.error),
              title: const Text('Borrar completamente'),
              subtitle: const Text('Elimina la conexión y el contenedor de Docker.'),
              onTap: () => Navigator.of(context).pop('delete_full'),
            ),
            ListTile(
              leading: Icon(Icons.link_off, color: AppColors.primary),
              title: const Text('Desgestionar'),
              subtitle: const Text('Elimina la conexión de la app, pero mantiene el contenedor.'),
              onTap: () => Navigator.of(context).pop('unmanage_only'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ],
      ),
    );

    if (deleteType == null) return;

    String url;
    if (deleteType == 'unmanage_only') {
      url = '${ApiConfig.baseUrl}/databases/$dbId?deleteContainer=false';
    } else {
      url = '${ApiConfig.baseUrl}/databases/$dbId?deleteContainer=true';
    }

    try {
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _databases.removeWhere((db) => db.id == dbId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operación completada con éxito.'), backgroundColor: Colors.green),
        );
      } else {
        final errorMessage = response.body.isNotEmpty ? response.body : 'Código de estado: ${response.statusCode}';
        throw Exception('Error: $errorMessage');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  void _navigateToCreateInstance() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateInstanceScreen()),
    );
    if (result == true) {
      _fetchDatabases();
    }
  }

  void _navigateToDetail(Database db) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DatabaseDetailScreen(database: db)),
    );
  }

  Future<void> _showAdoptDialog() async {
    final result = await showDialog(
      context: context,
      builder: (_) => const _AdoptInstanceDialog(),
    );
    if (result == true) {
      _fetchDatabases();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _appBarColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Adoptar Instancia Existente',
            onPressed: _showAdoptDialog,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateInstance,
        tooltip: 'Crear Base de Datos',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(); // Usar el nuevo widget
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: AppColors.error)));
    }
    if (_databases.isEmpty) {
      return const Center(child: Text('No hay bases de datos. Presiona + para crear una nueva.'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _databases.length,
      itemBuilder: (context, index) {
        final db = _databases[index];
        final bool isRunning = db.status == 'running';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
            onTap: () => _navigateToDetail(db),
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRunning ? Colors.green : AppColors.error,
                boxShadow: [BoxShadow(color: (isRunning ? Colors.green : AppColors.error).withOpacity(0.5), blurRadius: 4.0)],
              ),
            ),
            title: Text(db.dbName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              isRunning ? '${db.user}@${db.host}:${db.port}' : 'Estado: Detenido',
              style: TextStyle(color: isRunning ? null : AppColors.error.withOpacity(0.8)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.play_arrow_rounded, color: Colors.green), tooltip: 'Iniciar Instancia', onPressed: () => _startDatabase(db.id)),
                IconButton(icon: const Icon(Icons.stop_rounded, color: AppColors.error), tooltip: 'Detener Instancia', onPressed: () => _stopDatabase(db.id)),
                IconButton(icon: const Icon(Icons.bolt, color: AppColors.primary), tooltip: 'Probar Conexión', onPressed: isRunning ? () => _testConnection(db.id) : null),
                IconButton(icon: Icon(Icons.delete_outline, color: AppColors.error.withOpacity(0.8)), tooltip: 'Borrar', onPressed: () => _deleteDatabase(db.id)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdoptInstanceDialog extends StatefulWidget {
  const _AdoptInstanceDialog();

  @override
  State<_AdoptInstanceDialog> createState() => _AdoptInstanceDialogState();
}

class _AdoptInstanceDialogState extends State<_AdoptInstanceDialog> {
  bool _isLoadingList = true;
  bool _isAdopting = false;
  List<DiscoveredInstance> _discoveredInstances = [];
  DiscoveredInstance? _selectedInstance;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDiscoveredInstances();
  }

  Future<void> _fetchDiscoveredInstances() async {
    setState(() {
      _isLoadingList = true;
      _error = null;
    });
    try {
      final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/databases/discover'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _discoveredInstances = data.map((json) => DiscoveredInstance.fromJson(json)).toList();
        });
      } else {
        throw Exception('Error al buscar instancias: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingList = false;
      });
    }
  }

  Future<void> _adoptInstance() async {
    if (_selectedInstance == null) return;

    setState(() {
      _isAdopting = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/databases/adopt'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(_selectedInstance!.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception('Error al adoptar: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isAdopting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isLoadingList) {
      content = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: const AppLoadingIndicator()), // Usar el nuevo widget
      );
    } else if (_error != null) {
      content = Text(_error!, style: const TextStyle(color: AppColors.error));
    } else if (_discoveredInstances.isEmpty) {
      content = const Text('No se encontraron instancias de PostgreSQL no gestionadas.');
    } else {
      content = SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _discoveredInstances.length,
          itemBuilder: (context, index) {
            final instance = _discoveredInstances[index];
            return RadioListTile<DiscoveredInstance>(
              title: Text(instance.containerName),
              subtitle: Text('Imagen: ${instance.image}, DB: ${instance.dbName}'),
              value: instance,
              groupValue: _selectedInstance,
              onChanged: (value) => setState(() => _selectedInstance = value),
            );
          },
        ),
      );
    }

    return AlertDialog(
      title: const Text('Adoptar Instancia Existente'),
      content: content,
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: (_selectedInstance == null || _isAdopting) ? null : _adoptInstance,
          child: _isAdopting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Text('Adoptar'),
        ),
      ],
    );
  }
}
