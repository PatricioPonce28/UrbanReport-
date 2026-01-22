import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:typed_data';

class EditReportScreen extends StatefulWidget {
  final Map<String, dynamic> reporte;

  const EditReportScreen({super.key, required this.reporte});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  late final TextEditingController _tituloController;
  late final TextEditingController _descripcionController;
  
  late String _categoria;
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _currentFotoUrl;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _hasChangedImage = false;

  final List<Map<String, dynamic>> _categorias = [
    {'value': 'bache', 'label': 'Bache', 'icon': Icons.warning_amber},
    {'value': 'luminaria', 'label': 'Luminaria dañada', 'icon': Icons.lightbulb_outline},
    {'value': 'basura', 'label': 'Acumulación de basura', 'icon': Icons.delete_outline},
    {'value': 'alcantarilla', 'label': 'Alcantarilla obstruida', 'icon': Icons.water_damage_outlined},
    {'value': 'otro', 'label': 'Otro', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.reporte['titulo']);
    _descripcionController = TextEditingController(text: widget.reporte['descripcion']);
    _categoria = widget.reporte['categoria'];
    _currentFotoUrl = widget.reporte['foto_url'];
    
    if (widget.reporte['latitud'] != null && widget.reporte['longitud'] != null) {
      _currentPosition = Position(
        latitude: widget.reporte['latitud'],
        longitude: widget.reporte['longitud'],
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = image.name;
          _hasChangedImage = true;
        });
      } else {
        setState(() {
          _imageFile = File(image.path);
          _hasChangedImage = true;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      if (kIsWeb) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Permiso de ubicación denegado');
          }
        }
      } else {
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
          content: Text('Ubicación actualizada'),
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
        if (_imageBytes == null || _imageName == null) return null;
        
        final fileExt = _imageName!.split('.').last;
        final fileName = '$userId/$timestamp.$fileExt';

        await _supabase.storage.from('report-photos').uploadBinary(
          fileName,
          _imageBytes!,
          fileOptions: FileOptions(
            contentType: 'image/$fileExt',
            upsert: true,
          ),
        );

        return _supabase.storage.from('report-photos').getPublicUrl(fileName);
      } else {
        if (_imageFile == null) return null;
        
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '$userId/$timestamp.$fileExt';

        final bytes = await _imageFile!.readAsBytes();
        
        await _supabase.storage.from('report-photos').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$fileExt',
            upsert: true,
          ),
        );

        return _supabase.storage.from('report-photos').getPublicUrl(fileName);
      }
    } catch (e) {
      print('Error al subir imagen: $e');
      return null;
    }
  }

  Future<void> _updateReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? fotoUrl = _currentFotoUrl;

      // Si cambió la imagen, subir la nueva
      if (_hasChangedImage) {
        final newUrl = await _uploadImage();
        if (newUrl != null) {
          fotoUrl = newUrl;
        }
      }

      // Actualizar el reporte
      await _supabase.from('reportes').update({
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'categoria': _categoria,
        'latitud': _currentPosition?.latitude,
        'longitud': _currentPosition?.longitude,
        'foto_url': fotoUrl,
      }).eq('id', widget.reporte['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte actualizado exitosamente'),
          backgroundColor: Color(0xFF00A650),
        ),
      );

      Navigator.pop(context, true); // Retornar true para indicar que hubo cambios
    } catch (e) {
      print('Error al actualizar reporte: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _hasChangedImage 
        ? (kIsWeb ? _imageBytes != null : _imageFile != null)
        : _currentFotoUrl != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Reporte'),
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
                        child: _hasChangedImage
                            ? (kIsWeb
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
                                  ))
                            : Image.network(
                                _currentFotoUrl!,
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
                      label: Text(hasImage ? 'Cambiar Foto' : 'Agregar Foto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A650),
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
                                  'Ubicación',
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

              // Botón de actualizar
              ElevatedButton(
                onPressed: _isLoading ? null : _updateReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF003DA5),
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
                        'Actualizar Reporte',
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