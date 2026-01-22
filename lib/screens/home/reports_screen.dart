import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:typed_data';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  
  String _categoria = 'bache';
  File? _imageFile;
  Uint8List? _imageBytes; // Para Flutter Web
  String? _imageName; // Nombre del archivo para Web
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isLoadingLocation = false;

  final List<Map<String, dynamic>> _categorias = [
    {'value': 'bache', 'label': 'Bache', 'icon': Icons.warning_amber},
    {'value': 'luminaria', 'label': 'Luminaria dañada', 'icon': Icons.lightbulb_outline},
    {'value': 'basura', 'label': 'Acumulación de basura', 'icon': Icons.delete_outline},
    {'value': 'alcantarilla', 'label': 'Alcantarilla obstruida', 'icon': Icons.water_damage_outlined},
    {'value': 'otro', 'label': 'Otro', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera, // Cambiar a gallery para Web
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      if (kIsWeb) {
        // Para Flutter Web, leer como bytes
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = image.name;
        });
      } else {
        // Para móvil, usar File
        setState(() => _imageFile = File(image.path));
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // En Web, la geolocalización funciona diferente
      if (kIsWeb) {
        // Para Web, Geolocator funciona pero de forma simplificada
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Permiso de ubicación denegado');
          }
        }
      } else {
        // Para móvil, verificar servicios
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Los servicios de ubicación están desactivados');
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Permiso de ubicación denegado');
          }
        }

        if (permission == LocationPermission.deniedForever) {
          throw Exception('Permiso de ubicación denegado permanentemente');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _currentPosition = position);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación obtenida correctamente'),
          backgroundColor: Color(0xFF00A650),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener ubicación: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

Future<String?> _uploadImage() async {
  try {
    final userId = _supabase.auth.currentUser!.id;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (kIsWeb) {
      // Para Flutter Web
      if (_imageBytes == null || _imageName == null) return null;
      
      final fileExt = _imageName!.split('.').last;
      final fileName = '$userId/$timestamp.$fileExt';

      // Subir bytes directamente
      final response = await _supabase.storage
          .from('report-photos')
          .uploadBinary(
            fileName,
            _imageBytes!,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true, // Permite sobrescribir si existe
            ),
          );

      // Obtener URL pública
      final publicUrl = _supabase.storage
          .from('report-photos')
          .getPublicUrl(fileName);

      return publicUrl;
    } else {
      // Para móvil
      if (_imageFile == null) return null;
      
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = '$userId/$timestamp.$fileExt';

      // Leer archivo como bytes
      final bytes = await _imageFile!.readAsBytes();
      
      // Subir bytes
      final response = await _supabase.storage
          .from('report-photos')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      // Obtener URL pública
      final publicUrl = _supabase.storage
          .from('report-photos')
          .getPublicUrl(fileName);

      return publicUrl;
    }
  } catch (e) {
    print('Error al subir imagen: $e');
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al subir imagen: ${e.toString()}'),
        backgroundColor: const Color(0xFFE31E24),
        duration: const Duration(seconds: 4),
      ),
    );
    return null;
  }
}

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Subir imagen si existe
      String? fotoUrl;
      if ((kIsWeb && _imageBytes != null) || (!kIsWeb && _imageFile != null)) {
        fotoUrl = await _uploadImage();
      }

      // Crear reporte
      await _supabase.from('reportes').insert({
        'usuario_id': _supabase.auth.currentUser!.id,
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'categoria': _categoria,
        'latitud': _currentPosition?.latitude,
        'longitud': _currentPosition?.longitude,
        'foto_url': fotoUrl,
      });

      if (!mounted) return;

      // Limpiar formulario
      _formKey.currentState!.reset();
      _tituloController.clear();
      _descripcionController.clear();
      setState(() {
        _imageFile = null;
        _imageBytes = null;
        _imageName = null;
        _currentPosition = null;
        _categoria = 'bache';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte enviado exitosamente'),
          backgroundColor: Color(0xFF00A650),
        ),
      );
    } catch (e) {
      print('Error al enviar reporte: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar reporte: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = kIsWeb ? _imageBytes != null : _imageFile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Reporte'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título del problema',
                  hintText: 'Ej: Bache en Av. América',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El título es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categoría
              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categorias.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['value'],
                    child: Row(
                      children: [
                        Icon(cat['icon'], size: 20),
                        const SizedBox(width: 12),
                        Text(cat['label']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _categoria = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción detallada',
                  hintText: 'Describe el problema en detalle...',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La descripción es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Foto
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (hasImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.memory(
                                _imageBytes!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                _imageFile!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(hasImage ? Icons.refresh : Icons.photo_library),
                      label: Text(hasImage ? 'Cambiar Foto' : 'Seleccionar Foto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A650),
                      ),
                    ),
                    if (kIsWeb)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'En web: selecciona desde tu galería',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ubicación
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_currentPosition != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF00A650)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ubicación capturada',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                                  'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_currentPosition == null ? Icons.my_location : Icons.refresh),
                      label: Text(
                        _currentPosition == null
                            ? 'Obtener Ubicación'
                            : 'Actualizar Ubicación',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDB913),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botón de envío
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Enviar Reporte',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}