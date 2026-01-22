import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapViewScreen  extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = true;
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _loadReportes();
  }

  Future<void> _loadReportes() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Cargar solo reportes con ubicación
      final data = await _supabase
          .from('reportes')
          .select()
          .eq('usuario_id', userId)
          .not('latitud', 'is', null)
          .not('longitud', 'is', null)
          .order('created_at', ascending: false);

      setState(() {
        _reportes = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar reportes: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredReportes {
    if (_filtroEstado == 'todos') return _reportes;
    return _reportes.where((r) => r['estado'] == _filtroEstado).toList();
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return const Color(0xFFFDB913);
      case 'en_proceso':
        return const Color(0xFF003DA5);
      case 'resuelto':
        return const Color(0xFF00A650);
      default:
        return Colors.grey;
    }
  }

  void _showReporteDetail(Map<String, dynamic> reporte) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reporte['titulo'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getColorEstado(reporte['estado']),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                reporte['estado'].toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              reporte['descripcion'] ?? '',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (reporte['foto_url'] != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  reporte['foto_url'],
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcular centro del mapa
    LatLng centerMap = const LatLng(-0.1807, -78.4678); // Quito por defecto
    
    if (_filteredReportes.isNotEmpty) {
      double avgLat = _filteredReportes
          .map((r) => r['latitud'] as double)
          .reduce((a, b) => a + b) / _filteredReportes.length;
      double avgLng = _filteredReportes
          .map((r) => r['longitud'] as double)
          .reduce((a, b) => a + b) / _filteredReportes.length;
      centerMap = LatLng(avgLat, avgLng);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportes,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildFilterChip('Todos', 'todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Pendientes', 'pendiente'),
                const SizedBox(width: 8),
                _buildFilterChip('En Proceso', 'en_proceso'),
                const SizedBox(width: 8),
                _buildFilterChip('Resueltos', 'resuelto'),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReportes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay reportes con ubicación',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: centerMap,
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.quito.app',
                          ),
                          MarkerLayer(
                            markers: _filteredReportes.map((reporte) {
                              final lat = reporte['latitud'] as double;
                              final lng = reporte['longitud'] as double;
                              final estado = reporte['estado'] as String;

                              return Marker(
                                point: LatLng(lat, lng),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showReporteDetail(reporte),
                                  child: Icon(
                                    Icons.location_on,
                                    color: _getColorEstado(estado),
                                    size: 40,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
          ),

          // Leyenda
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(
                  color: const Color(0xFFFDB913),
                  label: 'Pendiente',
                ),
                _LegendItem(
                  color: const Color(0xFF003DA5),
                  label: 'En Proceso',
                ),
                _LegendItem(
                  color: const Color(0xFF00A650),
                  label: 'Resuelto',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filtroEstado == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filtroEstado = value);
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF003DA5).withOpacity(0.2),
      checkmarkColor: const Color(0xFF003DA5),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF003DA5) : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}