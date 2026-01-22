import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Nuevo
import 'package:latlong2/latlong.dart';      // Nuevo
import 'package:url_launcher/url_launcher.dart';

class MapWidget extends StatelessWidget {
  final double latitud;
  final double longitud;
  final String? titulo;

  const MapWidget({
    Key? key,
    required this.latitud,
    required this.longitud,
    this.titulo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (titulo != null) ...[
          Text(
            titulo!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003DA5)),
          ),
          const SizedBox(height: 16),
        ],
        
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF003DA5), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(latitud, longitud),
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tu_usuario.urban_report',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(latitud, longitud),
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openInOpenStreetMap(context),
          icon: const Icon(Icons.map),
          label: const Text('Abrir en navegador'),
        ),
      ],
    );
  }

  Future<void> _openInOpenStreetMap(BuildContext context) async {
    final url = Uri.parse('https://www.openstreetmap.org/?mlat=$latitud&mlon=$longitud#map=17/$latitud/$longitud');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa')),
      );
    }
  }
}