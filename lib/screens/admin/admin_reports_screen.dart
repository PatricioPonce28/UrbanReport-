import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = true;
  String _filtroEstado = 'todos';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('reportes')
          .select('*, profiles!inner(name)')
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

  Future<void> _updateEstado(String reporteId, String nuevoEstado) async {
    try {
      await _supabase
          .from('reportes')
          .update({'estado': nuevoEstado})
          .eq('id', reporteId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado actualizado exitosamente'),
          backgroundColor: Color(0xFF00A650),
        ),
      );

      _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar estado: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    }
  }

  Future<void> _deleteReport(String reporteId, String titulo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Reporte'),
        content: Text('¿Estás seguro de que deseas eliminar "$titulo"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE31E24),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('reportes').delete().eq('id', reporteId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte eliminado exitosamente'),
          backgroundColor: Color(0xFF00A650),
        ),
      );

      _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar reporte: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    var filtered = _reportes;

    // Filtrar por estado
    if (_filtroEstado != 'todos') {
      filtered = filtered.where((r) => r['estado'] == _filtroEstado).toList();
    }

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final titulo = (r['titulo'] ?? '').toLowerCase();
        final descripcion = (r['descripcion'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return titulo.contains(query) || descripcion.contains(query);
      }).toList();
    }

    return filtered;
  }

  Color _getEstadoColor(String estado) {
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

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'en_proceso':
        return 'En Proceso';
      case 'resuelto':
        return 'Resuelto';
      default:
        return estado;
    }
  }

  IconData _getCategoriaIcon(String categoria) {
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
        return Icons.more_horiz;
    }
  }

  String _getCategoriaLabel(String categoria) {
    switch (categoria) {
      case 'bache':
        return 'Bache';
      case 'luminaria':
        return 'Luminaria';
      case 'basura':
        return 'Basura';
      case 'alcantarilla':
        return 'Alcantarilla';
      default:
        return 'Otro';
    }
  }

  void _showReportDetail(Map<String, dynamic> reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003DA5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoriaIcon(reporte['categoria']),
                      color: const Color(0xFF003DA5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reporte['titulo'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Por: ${reporte['profiles']['name'] ?? 'Usuario'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Estado actual
              const Text(
                'Estado Actual',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003DA5),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _getEstadoColor(reporte['estado']),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _getEstadoLabel(reporte['estado']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cambiar estado
              const Text(
                'Cambiar Estado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003DA5),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _EstadoButton(
                    label: 'Pendiente',
                    estado: 'pendiente',
                    color: const Color(0xFFFDB913),
                    currentEstado: reporte['estado'],
                    onPressed: () {
                      _updateEstado(reporte['id'], 'pendiente');
                      Navigator.pop(context);
                    },
                  ),
                  _EstadoButton(
                    label: 'En Proceso',
                    estado: 'en_proceso',
                    color: const Color(0xFF003DA5),
                    currentEstado: reporte['estado'],
                    onPressed: () {
                      _updateEstado(reporte['id'], 'en_proceso');
                      Navigator.pop(context);
                    },
                  ),
                  _EstadoButton(
                    label: 'Resuelto',
                    estado: 'resuelto',
                    color: const Color(0xFF00A650),
                    currentEstado: reporte['estado'],
                    onPressed: () {
                      _updateEstado(reporte['id'], 'resuelto');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const Divider(height: 32),

              // Detalles
              _DetailRow(
                icon: Icons.category,
                label: 'Categoría',
                value: _getCategoriaLabel(reporte['categoria']),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.description,
                label: 'Descripción',
                value: reporte['descripcion'],
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.calendar_today,
                label: 'Fecha',
                value: _formatDate(reporte['created_at']),
              ),
              const SizedBox(height: 16),
              if (reporte['latitud'] != null && reporte['longitud'] != null)
                _DetailRow(
                  icon: Icons.location_on,
                  label: 'Ubicación',
                  value: 'Lat: ${reporte['latitud'].toStringAsFixed(6)}\n'
                      'Lng: ${reporte['longitud'].toStringAsFixed(6)}',
                ),
              const SizedBox(height: 24),

              // Foto
              if (reporte['foto_url'] != null) ...[
                const Text(
                  'Fotografía',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003DA5),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    reporte['foto_url'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.error_outline, size: 48),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Botón eliminar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteReport(reporte['id'], reporte['titulo']);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar Reporte'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE31E24),
                    side: const BorderSide(color: Color(0xFFE31E24)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Buscador
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar reportes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                // Filtro de estado
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        isSelected: _filtroEstado == 'todos',
                        onTap: () => setState(() => _filtroEstado = 'todos'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pendientes',
                        color: const Color(0xFFFDB913),
                        isSelected: _filtroEstado == 'pendiente',
                        onTap: () => setState(() => _filtroEstado = 'pendiente'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'En Proceso',
                        color: const Color(0xFF003DA5),
                        isSelected: _filtroEstado == 'en_proceso',
                        onTap: () => setState(() => _filtroEstado = 'en_proceso'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Resueltos',
                        color: const Color(0xFF00A650),
                        isSelected: _filtroEstado == 'resuelto',
                        onTap: () => setState(() => _filtroEstado = 'resuelto'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay reportes',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final reporte = _filteredReports[index];
                            return _ReportCard(
                              reporte: reporte,
                              onTap: () => _showReportDetail(reporte),
                              getCategoriaIcon: _getCategoriaIcon,
                              getCategoriaLabel: _getCategoriaLabel,
                              getEstadoColor: _getEstadoColor,
                              getEstadoLabel: _getEstadoLabel,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}

// Widgets auxiliares
class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? const Color(0xFF003DA5)) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _EstadoButton extends StatelessWidget {
  final String label;
  final String estado;
  final Color color;
  final String currentEstado;
  final VoidCallback onPressed;

  const _EstadoButton({
    required this.label,
    required this.estado,
    required this.color,
    required this.currentEstado,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = estado == currentEstado;
    return ElevatedButton(
      onPressed: isSelected ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
      ),
      child: Text(label),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> reporte;
  final VoidCallback onTap;
  final IconData Function(String) getCategoriaIcon;
  final String Function(String) getCategoriaLabel;
  final Color Function(String) getEstadoColor;
  final String Function(String) getEstadoLabel;

  const _ReportCard({
    required this.reporte,
    required this.onTap,
    required this.getCategoriaIcon,
    required this.getCategoriaLabel,
    required this.getEstadoColor,
    required this.getEstadoLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF003DA5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  getCategoriaIcon(reporte['categoria']),
                  color: const Color(0xFF003DA5),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporte['titulo'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Por: ${reporte['profiles']['name'] ?? 'Usuario'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: getEstadoColor(reporte['estado']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        getEstadoLabel(reporte['estado']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF003DA5), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}