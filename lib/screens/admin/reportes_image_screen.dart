import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportesScreen extends StatefulWidget {
  const AdminReportesScreen({super.key});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    try {
      final response = await _supabase
          .from('reportes')
          .select('''
            *,
            usuarios:usuario_id (
              nombre,
              email
            )
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _reportes = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar reportes: $e');
      setState(() => _isLoading = false);
    }
  }

  // Widget para mostrar la imagen
  Widget _buildImagenReporte(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Sin imagen', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 40),
                SizedBox(height: 8),
                Text('Error al cargar'),
              ],
            ),
          );
        },
      ),
    );
  }

  // Icono según categoría
  IconData _getIconForCategoria(String categoria) {
    switch (categoria) {
      case 'bache':
        return Icons.warning_amber;
      case 'luminaria':
        return Icons.lightbulb_outline;
      case 'basura':
        return Icons.delete_outline;
      case 'alcantarilla':
        return Icons.water_damage_outlined;
      default:
        return Icons.report_problem;
    }
  }

  // Color según categoría
  Color _getColorForCategoria(String categoria) {
    switch (categoria) {
      case 'bache':
        return Colors.orange;
      case 'luminaria':
        return Colors.yellow.shade700;
      case 'basura':
        return Colors.brown;
      case 'alcantarilla':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Texto de categoría
  String _getLabelForCategoria(String categoria) {
    switch (categoria) {
      case 'bache':
        return 'Bache';
      case 'luminaria':
        return 'Luminaria';
      case 'basura':
        return 'Basura';
      case 'alcantarilla':
        return 'Alcantarilla';
      case 'otro':
        return 'Otro';
      default:
        return 'Desconocido';
    }
  }

  // Formatear fecha
  String _formatFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Ciudadanos'),
        backgroundColor: const Color(0xFF00A650),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportes,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No hay reportes aún',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarReportes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reportes.length,
                    itemBuilder: (context, index) {
                      final reporte = _reportes[index];
                      final usuario = reporte['usuarios'] as Map<String, dynamic>?;
                      
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Encabezado con categoría y fecha
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getIconForCategoria(reporte['categoria'] ?? 'otro'),
                                        color: _getColorForCategoria(reporte['categoria'] ?? 'otro'),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getLabelForCategoria(reporte['categoria'] ?? 'otro'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getColorForCategoria(reporte['categoria'] ?? 'otro'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _formatFecha(
                                      DateTime.parse(reporte['created_at']).toLocal(),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Título
                              Text(
                                reporte['titulo'] ?? 'Sin título',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Descripción
                              Text(
                                reporte['descripcion'] ?? 'Sin descripción',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 16),

                              // IMAGEN DEL REPORTE
                              if (reporte['foto_url'] != null) ...[
                                _buildImagenReporte(reporte['foto_url']),
                                const SizedBox(height: 16),
                              ],

                              // Información de ubicación
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Lat: ${reporte['latitud']?.toStringAsFixed(6) ?? 'N/A'}, '
                                      'Lng: ${reporte['longitud']?.toStringAsFixed(6) ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Información del usuario
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Color(0xFF00A650),
                                      child: Icon(Icons.person, size: 18, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            usuario?['nombre'] ?? 'Usuario',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            usuario?['email'] ?? 'Sin email',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Botones de acción (opcional)
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        // Ver en mapa
                                        _mostrarEnMapa(
                                          reporte['latitud'],
                                          reporte['longitud'],
                                        );
                                      },
                                      icon: const Icon(Icons.map, size: 16),
                                      label: const Text('Ver en mapa'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        // Marcar como resuelto
                                        _marcarResuelto(reporte['id']);
                                      },
                                      icon: const Icon(Icons.check_circle, size: 16),
                                      label: const Text('Resolver'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00A650),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  // Función para mostrar en mapa (puedes implementar)
  void _mostrarEnMapa(double? latitud, double? longitud) {
    if (latitud == null || longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ubicación disponible')),
      );
      return;
    }
    
    // Aquí puedes navegar a una pantalla de mapa
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => MapaScreen(latitud: latitud, longitud: longitud),
    // ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ubicación: $latitud, $longitud')),
    );
  }

  // Función para marcar como resuelto
  Future<void> _marcarResuelto(int reporteId) async {
    try {
      await _supabase
          .from('reportes')
          .update({'estado': 'resuelto'})
          .eq('id', reporteId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte marcado como resuelto'),
          backgroundColor: Color(0xFF00A650),
        ),
      );
      
      _cargarReportes(); // Recargar lista
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}