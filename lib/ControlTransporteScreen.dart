import 'package:flutter/material.dart';
import 'formulario_225.dart';

class ControlTransporteScreen extends StatefulWidget {
  const ControlTransporteScreen({super.key});

  @override
  State<ControlTransporteScreen> createState() => _ControlTransporteScreenState();
}

class _ControlTransporteScreenState extends State<ControlTransporteScreen> {
  final List<Map<String, dynamic>> _registros = [];

  void _abrirFormulario() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FormularioTransporteScreen()),
    );

    if (resultado != null) {
      setState(() {
        _registros.add(resultado);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Transporte - Azunosa'),
        backgroundColor: const Color(0xFF0F1E36),
        foregroundColor: Colors.white,
      ),
      body: _registros.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay registros todavía',
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona "F-OA-225" en el menú o presiona "+"',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _registros.length,
              itemBuilder: (context, index) {
                final item = _registros[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Color(0xFF2E7D32)),
                    title: Text('Placa: ${item['placa']}'),
                    subtitle: Text('Fecha: ${item['fecha']} - Finca: ${item['finca']}'),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}