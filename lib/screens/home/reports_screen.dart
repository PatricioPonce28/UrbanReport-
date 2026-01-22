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
  Uint8List? _imageBytes;
  String? _imageName;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isLoadingLocation = false;

  final List<Map<String, dynamic>> _categorias = [
    {'value': 'bache', 'label': 'Bache', 'icon': Icons.warning_amber_rounded},
    {'value': 'luminaria', 'label': 'Luminaria dañada', 'icon': Icons.lightbulb_rounded},
    {'value': 'basura', 'label': 'Acumulación de basura', 'icon': Icons.delete_rounded},
    {'value': 'alcantarilla', 'label': 'Alcantarilla obstruida', 'icon': Icons.water_damage_rounded},
    {'value': 'otro', 'label': 'Otro', 'icon': Icons.more_horiz_rounded},
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
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
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
        });
      } else {
        setState(() => _imageFile = File(image.path));
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
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

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están desactivados');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _currentPosition = position);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ubicación capturada correctamente'),
            backgroundColor: const Color(0xFF00A650),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener ubicación: $e'),
            backgroundColor: const Color(0xFFE31E24),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<String?> _uploadImage() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      String fileName;
      Uint8List? bytes;

      if (kIsWeb) {
        if (_imageBytes == null || _imageName == null) return null;
        final fileExt = _imageName!.split('.').last;
        fileName = '$userId/$timestamp.$fileExt';
        bytes = _imageBytes;
      } else {
        if (_imageFile == null) return null;
        final fileExt = _imageFile!.path.split('.').last;
        fileName = '$userId/$timestamp.$fileExt';
        bytes = await _imageFile!.readAsBytes();
      }

      await _supabase.storage
          .from('report-photos')
          .uploadBinary(
            fileName,
            bytes!,
            fileOptions: FileOptions(contentType: 'image/${fileName.split('.').last}', upsert: true),
          );

      return _supabase.storage.from('report-photos').getPublicUrl(fileName);
    } catch (e) {
      print('Error al subir imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen'),
            backgroundColor: const Color(0xFFE31E24),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? fotoUrl;
      if ((kIsWeb && _imageBytes != null) || (!kIsWeb && _imageFile != null)) {
        fotoUrl = await _uploadImage();
      }

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
        SnackBar(
          content: const Text('¡Reporte enviado con éxito!'),
          backgroundColor: const Color(0xFF00A650),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al enviar el reporte'),
            backgroundColor: const Color(0xFFE31E24),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = kIsWeb ? _imageBytes != null : _imageFile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Problema', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF003DA5),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF4FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header motivacional
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF003DA5), Color(0xFF005BFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003DA5).withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.report_problem_rounded, size: 48, color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Ayúdanos a mejorar Quito',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tu reporte hace la diferencia',
                          style: TextStyle(fontSize: 15, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Título
                  TextFormField(
                    controller: _tituloController,
                    decoration: InputDecoration(
                      labelText: 'Título del reporte',
                      hintText: 'Ej: Bache grande en la Av. América',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) => value?.trim().isEmpty ?? true ? 'El título es requerido' : null,
                  ),
                  const SizedBox(height: 20),

                  // Categoría
                  DropdownButtonFormField<String>(
                    value: _categoria,
                    decoration: InputDecoration(
                      labelText: 'Categoría del problema',
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _categorias.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat['value'],
                        child: Row(
                          children: [
                            Icon(cat['icon'], color: const Color(0xFF003DA5), size: 22),
                            const SizedBox(width: 12),
                            Text(cat['label']),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => value != null ? setState(() => _categoria = value) : null,
                  ),
                  const SizedBox(height: 20),

                  // Descripción
                  TextFormField(
                    controller: _descripcionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Describe el problema',
                      hintText: 'Detalla lo que viste, ubicación aproximada, tamaño, etc...',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value?.trim().isEmpty ?? true ? 'La descripción es requerida' : null,
                  ),
                  const SizedBox(height: 24),

                  // Sección Foto
                  _buildSectionCard(
                    title: 'Fotografía (opcional pero muy útil)',
                    child: Column(
                      children: [
                        if (hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF00A650), width: 2),
                              ),
                              child: kIsWeb
                                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                  : Image.file(_imageFile!, fit: BoxFit.cover),
                            ),
                          ),
                        if (hasImage) const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00A650), Color(0xFF008037)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF00A650).withOpacity(0.3), blurRadius: 10),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: Icon(hasImage ? Icons.refresh_rounded : Icons.add_a_photo_rounded, color: Colors.white),
                            label: Text(hasImage ? 'Cambiar Foto' : 'Agregar Foto', style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                            ),
                          ),
                        ),
                        if (kIsWeb)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'En web: selecciona desde tu galería',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sección Ubicación
                  _buildSectionCard(
                    title: 'Ubicación (importante para procesar rápido)',
                    child: Column(
                      children: [
                        if (_currentPosition != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDB913).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF00A650)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Ubicación capturada\nLat: ${_currentPosition!.latitude.toStringAsFixed(6)}  •  Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF003DA5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_currentPosition != null) const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFDB913), Color(0xFFFFA000)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFFDB913).withOpacity(0.3), blurRadius: 10),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                            icon: _isLoadingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                  )
                                : Icon(_currentPosition == null ? Icons.my_location_rounded : Icons.refresh_rounded, color: Colors.white),
                            label: Text(
                              _currentPosition == null ? 'Obtener mi ubicación' : 'Actualizar ubicación',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Botón Enviar
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE31E24), Color(0xFFB71C1C)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFE31E24).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Text(
                              'Enviar Reporte',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003DA5),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ],
    );
  }
}