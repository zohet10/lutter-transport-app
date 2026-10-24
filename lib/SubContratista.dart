import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormatoSubcontratistaScreen extends StatefulWidget {
  const FormatoSubcontratistaScreen({super.key});

  @override
  State<FormatoSubcontratistaScreen> createState() =>
      _FormatoSubcontratistaScreenState();
}

class _FormatoSubcontratistaScreenState
    extends State<FormatoSubcontratistaScreen> {

  // ============================================================
  // COLORES - IGUALES A LOS OTROS FORMATOS
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  // ================= MÓDULO 1: TRANSPORTISTAS =================

  final _formTransportistaKey = GlobalKey<FormState>();

  final TextEditingController _nombreTransportistaController =
      TextEditingController();

  final TextEditingController _dniController =
      TextEditingController();

  final TextEditingController _placaController =
      TextEditingController();

  bool _guardandoTransportista = false;

  // ================= MÓDULO 2: SUBCONTRATISTAS =================

  final _formSubcontratistaKey = GlobalKey<FormState>();

  final TextEditingController _nombreSubcontratistaController =
      TextEditingController();

  bool _guardandoSubcontratista = false;

  @override
  void dispose() {
    _nombreTransportistaController.dispose();
    _dniController.dispose();
    _placaController.dispose();
    _nombreSubcontratistaController.dispose();
    super.dispose();
  }

  // ============================================================
  // GUARDAR TRANSPORTISTA
  // ============================================================

  Future<void> _guardarTransportista() async {
    if (!_formTransportistaKey.currentState!.validate()) {
      return;
    }

    setState(() => _guardandoTransportista = true);

    try {
      await FirebaseFirestore.instance
          .collection('transportistas')
          .add({
        'nombre':
            _nombreTransportistaController.text.trim(),

        'dni':
            _dniController.text.trim().isNotEmpty
                ? _dniController.text.trim()
                : 'No proporcionado',

        'placa':
            _placaController.text.trim().toUpperCase(),

        'fechaRegistro':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Transportista guardado exitosamente!',
          ),
          backgroundColor: colorVerde,
        ),
      );

      _nombreTransportistaController.clear();
      _dniController.clear();
      _placaController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar transportista: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardandoTransportista = false);
      }
    }
  }

  // ============================================================
  // GUARDAR SUBCONTRATISTA
  // ============================================================

  Future<void> _guardarSubcontratista() async {
    if (!_formSubcontratistaKey.currentState!.validate()) {
      return;
    }

    setState(() => _guardandoSubcontratista = true);

    try {
      await FirebaseFirestore.instance
          .collection('subcontratistas')
          .add({
        'nombre':
            _nombreSubcontratistaController.text.trim(),

        'fechaRegistro':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Subcontratista guardado exitosamente!',
          ),
          backgroundColor: colorVerde,
        ),
      );

      _nombreSubcontratistaController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar subcontratista: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardandoSubcontratista = false);
      }
    }
  }

  // ============================================================
  // ELIMINAR TRANSPORTISTA
  // ============================================================

  Future<void> _eliminarTransportista(
    String docId,
    String placa,
  ) async {
    final confirmar = await _mostrarConfirmacion(
      '¿Desea eliminar el transportista con placa $placa?',
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance
          .collection('transportistas')
          .doc(docId)
          .delete();

      _mostrarMensaje(
        'Transportista eliminado',
        Colors.orange,
      );
    }
  }

  // ============================================================
  // ELIMINAR SUBCONTRATISTA
  // ============================================================

  Future<void> _eliminarSubcontratista(
    String docId,
    String nombre,
  ) async {
    final confirmar = await _mostrarConfirmacion(
      '¿Desea eliminar al subcontratista $nombre?',
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance
          .collection('subcontratistas')
          .doc(docId)
          .delete();

      _mostrarMensaje(
        'Subcontratista eliminado',
        Colors.orange,
      );
    }
  }

  // ============================================================
  // CONFIRMACIÓN
  // ============================================================

  Future<bool?> _mostrarConfirmacion(String texto) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirmar eliminación',
        ),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDITAR TRANSPORTISTA
  // ============================================================

  void _editarTransportista(
    String docId,
    Map<String, dynamic> data,
  ) {
    final nameCtrl = TextEditingController(
      text: data['nombre'] ?? '',
    );

    final dniCtrl = TextEditingController(
      text: data['dni'] == 'No proporcionado'
          ? ''
          : data['dni'],
    );

    final placaCtrl = TextEditingController(
      text: data['placa'] ?? '',
    );

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Editar Transportista',
        ),

        content: SizedBox(
          width: 400,

          child: Form(
            key: formKey,

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: _inputDecoration(
                    'Nombre Completo',
                    Icons.person,
                  ),
                  validator: (v) =>
                      v!.isEmpty
                          ? 'Requerido'
                          : null,
                ),

                const SizedBox(height: 10),

                TextFormField(
                  controller: dniCtrl,
                  decoration: _inputDecoration(
                    'DNI',
                    Icons.badge,
                  ),
                ),

                const SizedBox(height: 10),

                TextFormField(
                  controller: placaCtrl,
                  decoration: _inputDecoration(
                    'Placa',
                    Icons.directions_car,
                  ),
                  validator: (v) =>
                      v!.isEmpty
                          ? 'Requerido'
                          : null,
                ),
              ],
            ),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text(
              'Cancelar',
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorVerde,
              foregroundColor: Colors.white,
            ),

            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await FirebaseFirestore.instance
                    .collection('transportistas')
                    .doc(docId)
                    .update({
                  'nombre':
                      nameCtrl.text.trim(),

                  'dni':
                      dniCtrl.text.trim().isNotEmpty
                          ? dniCtrl.text.trim()
                          : 'No proporcionado',

                  'placa':
                      placaCtrl.text.trim().toUpperCase(),
                });

                if (!mounted) return;

                Navigator.pop(context);

                _mostrarMensaje(
                  'Transportista actualizado',
                  colorVerde,
                );
              }
            },

            child: const Text(
              'Guardar',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDITAR SUBCONTRATISTA
  // ============================================================

  void _editarSubcontratista(
    String docId,
    String nombreActual,
  ) {
    final nameCtrl = TextEditingController(
      text: nombreActual,
    );

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Editar Subcontratista',
        ),

        content: SizedBox(
          width: 400,

          child: Form(
            key: formKey,

            child: TextFormField(
              controller: nameCtrl,

              decoration: _inputDecoration(
                'Nombre del Subcontratista',
                Icons.business,
              ),

              validator: (v) =>
                  v!.trim().isEmpty
                      ? 'Ingrese un nombre'
                      : null,
            ),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text(
              'Cancelar',
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorVerde,
              foregroundColor: Colors.white,
            ),

            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await FirebaseFirestore.instance
                    .collection('subcontratistas')
                    .doc(docId)
                    .update({
                  'nombre':
                      nameCtrl.text.trim(),
                });

                if (!mounted) return;

                Navigator.pop(context);

                _mostrarMensaje(
                  'Subcontratista actualizado',
                  colorVerde,
                );
              }
            },

            child: const Text(
              'Guardar',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  void _mostrarMensaje(
    String msg,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,

      // ========================================================
      // APPBAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Control de Transporte y Subcontratistas - Azunosa',
        ),
        backgroundColor: colorPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),

        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 1100,
            ),

            child: LayoutBuilder(
              builder: (context, constraints) {
                bool esCelular =
                    constraints.maxWidth < 700;

                // ==================================================
                // TRANSPORTISTAS
                // ==================================================

                final seccionTransportistas =
                    esCelular
                        ? Column(
                            children: [
                              _buildCardFormTransportista(),

                              const SizedBox(
                                height: 16,
                              ),

                              _buildCardListTransportista(),
                            ],
                          )
                        : Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Expanded(
                                flex: 4,
                                child:
                                    _buildCardFormTransportista(),
                              ),

                              const SizedBox(
                                width: 16,
                              ),

                              Expanded(
                                flex: 6,
                                child:
                                    _buildCardListTransportista(),
                              ),
                            ],
                          );

                // ==================================================
                // SUBCONTRATISTAS
                // ==================================================

                final seccionSubcontratistas =
                    esCelular
                        ? Column(
                            children: [
                              _buildCardFormSubcontratista(),

                              const SizedBox(
                                height: 16,
                              ),

                              _buildCardListSubcontratista(),
                            ],
                          )
                        : Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Expanded(
                                flex: 4,
                                child:
                                    _buildCardFormSubcontratista(),
                              ),

                              const SizedBox(
                                width: 16,
                              ),

                              Expanded(
                                flex: 6,
                                child:
                                    _buildCardListSubcontratista(),
                              ),
                            ],
                          );

                return Column(
                  children: [
                    // ============================================
                    // SECCIÓN TRANSPORTISTAS
                    // ============================================

                    seccionTransportistas,

                    const SizedBox(
                      height: 30,
                    ),

                    Divider(
                      thickness: 2,
                      color: colorBorde,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ============================================
                    // SECCIÓN SUBCONTRATISTAS
                    // ============================================

                    seccionSubcontratistas,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD FORM TRANSPORTISTA
  // ============================================================

  Widget _buildCardFormTransportista() {
    return Card(
      color: Colors.white,
      elevation: 3,

      shadowColor:
          Colors.black.withOpacity(0.08),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Form(
          key: _formTransportistaKey,

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Text(
                'Registro de Transportista',

                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorPrincipal,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Datos del Transportista',

                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorVerde,
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller:
                    _nombreTransportistaController,

                decoration: _inputDecoration(
                  'Nombre Completo',
                  Icons.person,
                ),

                validator: (v) =>
                    v == null ||
                            v.trim().isEmpty
                        ? 'Ingrese el nombre'
                        : null,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _dniController,

                decoration: _inputDecoration(
                  'Número de DNI (Opcional)',
                  Icons.badge,
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _placaController,

                decoration: _inputDecoration(
                  'Placa del Vehículo',
                  Icons.directions_car,
                ),

                validator: (v) =>
                    v == null ||
                            v.trim().isEmpty
                        ? 'Ingrese la placa'
                        : null,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorVerde,
                    foregroundColor: Colors.white,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                  ),

                  onPressed:
                      _guardandoTransportista
                          ? null
                          : _guardarTransportista,

                  child:
                      _guardandoTransportista
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Guardar Transportista',

                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LISTA TRANSPORTISTAS
  // ============================================================

  Widget _buildCardListTransportista() {
    return Card(
      color: Colors.white,
      elevation: 3,

      shadowColor:
          Colors.black.withOpacity(0.08),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            const Text(
              'Transportistas Registrados',

              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorPrincipal,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 320,

              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transportistas')
                    .orderBy(
                      'fechaRegistro',
                      descending: true,
                    )
                    .snapshots(),

                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(
                        color: colorVerde,
                      ),
                    );
                  }

                  final docs =
                      snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay transportistas registrados.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,

                    itemBuilder:
                        (context, index) {
                      final data =
                          docs[index].data()
                              as Map<String, dynamic>;

                      return Card(
                        color: Colors.white,

                        margin:
                            const EdgeInsets.symmetric(
                          vertical: 4,
                        ),

                        child: ListTile(
                          leading:
                              const CircleAvatar(
                            backgroundColor:
                                colorPrincipal,

                            child: Icon(
                              Icons.local_shipping,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),

                          title: Text(
                            'Placa: ${data['placa']}',

                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: colorVerde,
                            ),
                          ),

                          subtitle: Text(
                            'Propietario: ${data['nombre']}\nDNI: ${data['dni']}',
                          ),

                          isThreeLine: true,

                          trailing: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              IconButton(
                                icon:
                                    const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),

                                onPressed: () =>
                                    _editarTransportista(
                                  docs[index].id,
                                  data,
                                ),
                              ),

                              IconButton(
                                icon:
                                    const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),

                                onPressed: () =>
                                    _eliminarTransportista(
                                  docs[index].id,
                                  data['placa'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD FORM SUBCONTRATISTA
  // ============================================================

  Widget _buildCardFormSubcontratista() {
    return Card(
      color: Colors.white,
      elevation: 3,

      shadowColor:
          Colors.black.withOpacity(0.08),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Form(
          key: _formSubcontratistaKey,

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Text(
                'Registro de Subcontratista',

                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorPrincipal,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Datos de la Empresa / Subcontratista',

                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorVerde,
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller:
                    _nombreSubcontratistaController,

                decoration: _inputDecoration(
                  'Nombre del Subcontratista',
                  Icons.business,
                ),

                validator: (v) =>
                    v == null ||
                            v.trim().isEmpty
                        ? 'Ingrese el nombre'
                        : null,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorVerde,
                    foregroundColor: Colors.white,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                  ),

                  onPressed:
                      _guardandoSubcontratista
                          ? null
                          : _guardarSubcontratista,

                  child:
                      _guardandoSubcontratista
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Guardar Subcontratista',

                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LISTA SUBCONTRATISTAS
  // ============================================================

  Widget _buildCardListSubcontratista() {
    return Card(
      color: Colors.white,
      elevation: 3,

      shadowColor:
          Colors.black.withOpacity(0.08),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            const Text(
              'Subcontratistas Registrados',

              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorPrincipal,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 250,

              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subcontratistas')
                    .orderBy(
                      'fechaRegistro',
                      descending: true,
                    )
                    .snapshots(),

                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(
                        color: colorVerde,
                      ),
                    );
                  }

                  final docs =
                      snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay subcontratistas registrados.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,

                    itemBuilder:
                        (context, index) {
                      final data =
                          docs[index].data()
                              as Map<String, dynamic>;

                      final nombreSub =
                          data['nombre'] ??
                              'Sin nombre';

                      return Card(
                        color: Colors.white,

                        margin:
                            const EdgeInsets.symmetric(
                          vertical: 4,
                        ),

                        child: ListTile(
                          leading:
                              const CircleAvatar(
                            backgroundColor:
                                colorPrincipal,

                            child: Icon(
                              Icons.business,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),

                          title: Text(
                            nombreSub,

                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: colorVerde,
                            ),
                          ),

                          trailing: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              IconButton(
                                icon:
                                    const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),

                                onPressed: () =>
                                    _editarSubcontratista(
                                  docs[index].id,
                                  nombreSub,
                                ),
                              ),

                              IconButton(
                                icon:
                                    const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),

                                onPressed: () =>
                                    _eliminarSubcontratista(
                                  docs[index].id,
                                  nombreSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DECORACIÓN DE CAMPOS
  // ============================================================

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,

      filled: true,
      fillColor: Colors.white,

      prefixIcon: Icon(
        icon,
        color: colorVerde,
      ),

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),

        borderSide: const BorderSide(
          color: colorBorde,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),

        borderSide: const BorderSide(
          color: colorBorde,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),

        borderSide: const BorderSide(
          color: colorVerde,
          width: 1.5,
        ),
      ),
    );
  }
}