import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActividadLaborScreen extends StatefulWidget {
  const ActividadLaborScreen({super.key});

  @override
  State<ActividadLaborScreen> createState() =>
      _ActividadLaborScreenState();
}

class _ActividadLaborScreenState
    extends State<ActividadLaborScreen> {
  // ============================================================
  // COLORES ESTÁNDAR DE LA APLICACIÓN
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _actividadController =
      TextEditingController();

  final TextEditingController _laborController =
      TextEditingController();

  bool _guardando = false;

  String? _idDocumentoEditando;

  @override
  void dispose() {
    _actividadController.dispose();
    _laborController.dispose();
    super.dispose();
  }

  // ============================================================
  // GUARDAR / ACTUALIZAR
  // ============================================================

  Future<void> _guardarOActualizarRegistro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      if (_idDocumentoEditando == null) {
        await FirebaseFirestore.instance
            .collection('actividad_labor')
            .add({
          'actividad':
              _actividadController.text.trim(),
          'labor':
              _laborController.text.trim(),
          'fechaRegistro':
              FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('¡Guardado exitosamente!'),
            backgroundColor: colorVerde,
          ),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('actividad_labor')
            .doc(_idDocumentoEditando)
            .update({
          'actividad':
              _actividadController.text.trim(),
          'labor':
              _laborController.text.trim(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('¡Actualizado exitosamente!'),
            backgroundColor: colorVerde,
          ),
        );
      }

      _limpiarFormulario();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  // ============================================================
  // PREPARAR EDICIÓN
  // ============================================================

  void _prepararEdicion(
    String id,
    String actividad,
    String labor,
  ) {
    setState(() {
      _idDocumentoEditando = id;
      _actividadController.text = actividad;
      _laborController.text = labor;
    });
  }

  // ============================================================
  // LIMPIAR FORMULARIO
  // ============================================================

  void _limpiarFormulario() {
    setState(() {
      _idDocumentoEditando = null;
      _actividadController.clear();
      _laborController.clear();
    });
  }

  // ============================================================
  // ELIMINAR
  // ============================================================

  Future<void> _eliminarRegistro(
      String docId) async {
    try {
      if (_idDocumentoEditando == docId) {
        _limpiarFormulario();
      }

      await FirebaseFirestore.instance
          .collection('actividad_labor')
          .doc(docId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro eliminado'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // DECORACIÓN DE CAMPOS
  // ============================================================

  InputDecoration _decoracionCampo({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,

      prefixIcon: Icon(
        icon,
        color: colorVerde,
      ),

      filled: true,
      fillColor: Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color: colorBorde,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color: colorBorde,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color: colorVerde,
          width: 1.5,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color: Colors.red,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isEditing =
        _idDocumentoEditando != null;

    // ==========================================================
    // TARJETA DEL FORMULARIO
    // ==========================================================

    final Widget tarjetaFormulario = Card(
      elevation: 0,
      color: Colors.white,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(14),
        side: const BorderSide(
          color: colorBorde,
        ),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            mainAxisSize:
                MainAxisSize.min,

            children: [

              // ------------------------------------------------
              // TÍTULO
              // ------------------------------------------------

              Row(
                children: [

                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Editar Entrada'
                          : 'Nueva Entrada',

                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            colorPrincipal,
                      ),
                    ),
                  ),

                  if (isEditing)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                      ),

                      tooltip:
                          'Cancelar edición',

                      onPressed:
                          _limpiarFormulario,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // ------------------------------------------------
              // ACTIVIDAD
              // ------------------------------------------------

              TextFormField(
                controller:
                    _actividadController,

                decoration:
                    _decoracionCampo(
                  label: 'Actividad',
                  icon:
                      Icons.work_outline,
                ),

                validator: (v) {
                  if (v == null ||
                      v.trim().isEmpty) {
                    return 'Ingrese la actividad';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------
              // LABOR
              // ------------------------------------------------

              TextFormField(
                controller:
                    _laborController,

                decoration:
                    _decoracionCampo(
                  label: 'Labor',
                  icon:
                      Icons.engineering_outlined,
                ),

                validator: (v) {
                  if (v == null ||
                      v.trim().isEmpty) {
                    return 'Ingrese la labor';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // BOTÓN GUARDAR
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 48,

                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        colorVerde,

                    foregroundColor:
                        Colors.white,

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),

                  onPressed: _guardando
                      ? null
                      : _guardarOActualizarRegistro,

                  child: _guardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            color:
                                Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing
                              ? 'Actualizar Registro'
                              : 'Guardar',

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // ------------------------------------------------
              // CANCELAR EDICIÓN
              // ------------------------------------------------

              if (isEditing) ...[
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,

                  child: TextButton(
                    onPressed:
                        _limpiarFormulario,

                    child:
                        const Text(
                      'Cancelar edición',

                      style:
                          TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // ==========================================================
    // TARJETA HISTORIAL
    // ==========================================================

    final Widget tarjetaHistorial = Card(
      elevation: 0,
      color: Colors.white,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(14),
        side: const BorderSide(
          color: colorBorde,
        ),
      ),

      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // --------------------------------------------------
            // TÍTULO HISTORIAL
            // --------------------------------------------------

            const Text(
              'Historial Registrado',

              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
                color: colorPrincipal,
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // FIRESTORE
            // --------------------------------------------------

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore
                  .instance
                  .collection(
                      'actividad_labor')
                  .orderBy(
                    'fechaRegistro',
                    descending: true,
                  )
                  .snapshots(),

              builder:
                  (context, snapshot) {

                if (snapshot
                    .connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(20),
                      child:
                          CircularProgressIndicator(
                        color:
                            colorVerde,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        20,
                      ),
                      child: Text(
                        'Error al cargar registros:\n${snapshot.error}',
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(20),
                      child:
                          CircularProgressIndicator(
                        color:
                            colorVerde,
                      ),
                    ),
                  );
                }

                final docs =
                    snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(20),
                      child: Text(
                        'No hay registros todavía.',
                      ),
                    ),
                  );
                }

                // ----------------------------------------------
                // LISTA
                // ----------------------------------------------

                return ListView.builder(
                  shrinkWrap: true,

                  physics:
                      const NeverScrollableScrollPhysics(),

                  itemCount: docs.length,

                  itemBuilder:
                      (context, index) {

                    final docId =
                        docs[index].id;

                    final data =
                        docs[index].data()
                            as Map<String,
                                dynamic>;

                    final actividad =
                        data['actividad'] ??
                            '';

                    final labor =
                        data['labor'] ??
                            '';

                    final bool
                        estaSiendoEditado =
                        _idDocumentoEditando ==
                            docId;

                    // ------------------------------------------
                    // TARJETA DE REGISTRO
                    // ------------------------------------------

                    return Card(
                      elevation: 0,

                      color:
                          estaSiendoEditado
                              ? const Color(
                                  0xFFEAF4EC,
                                )
                              : Colors.white,

                      margin:
                          const EdgeInsets
                              .symmetric(
                        vertical: 4,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),

                        side:
                            const BorderSide(
                          color: colorBorde,
                        ),
                      ),

                      child: ListTile(

                        // --------------------------------------
                        // ICONO
                        // --------------------------------------

                        leading:
                            CircleAvatar(
                          backgroundColor:
                              estaSiendoEditado
                                  ? colorVerde
                                  : colorPrincipal,

                          child:
                              const Icon(
                            Icons.check,
                            color:
                                Colors.white,
                            size: 20,
                          ),
                        ),

                        // --------------------------------------
                        // INFORMACIÓN
                        // --------------------------------------

                        title: Text(
                          'Actividad: $actividad',

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            color:
                                colorVerde,
                          ),

                          overflow:
                              TextOverflow.ellipsis,
                        ),

                        subtitle: Text(
                          'Labor: $labor',

                          overflow:
                              TextOverflow.ellipsis,
                        ),

                        // --------------------------------------
                        // BOTONES
                        // --------------------------------------

                        trailing:
                            Wrap(
                          spacing: 2,

                          children: [

                            IconButton(
                              icon:
                                  const Icon(
                                Icons.edit,
                                color:
                                    colorVerde,
                              ),

                              tooltip:
                                  'Editar',

                              onPressed: () =>
                                  _prepararEdicion(
                                docId,
                                actividad,
                                labor,
                              ),
                            ),

                            IconButton(
                              icon:
                                  const Icon(
                                Icons.delete,
                                color:
                                    Colors.red,
                              ),

                              tooltip:
                                  'Eliminar',

                              onPressed: () =>
                                  _eliminarRegistro(
                                docId,
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
          ],
        ),
      ),
    );

    // ==========================================================
    // PANTALLA PRINCIPAL RESPONSIVE
    // ==========================================================

    return Scaffold(
      backgroundColor: colorFondo,

      appBar: AppBar(
        title: const Text(
          'Registro de Actividad y Labor',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        backgroundColor:
            colorPrincipal,

        foregroundColor:
            Colors.white,

        elevation: 0,
      ),

      body: LayoutBuilder(
        builder:
            (context, constraints) {

          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(16),

            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1100,
                ),

                child:
                    constraints.maxWidth < 700

                        // ==================================================
                        // CELULAR
                        // ==================================================

                        ? Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .stretch,

                            children: [

                              tarjetaFormulario,

                              const SizedBox(
                                height: 16,
                              ),

                              tarjetaHistorial,
                            ],
                          )

                        // ==================================================
                        // TABLET / PC
                        // ==================================================

                        : Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              Expanded(
                                flex: 4,

                                child:
                                    tarjetaFormulario,
                              ),

                              const SizedBox(
                                width: 16,
                              ),

                              Expanded(
                                flex: 6,

                                child:
                                    tarjetaHistorial,
                              ),
                            ],
                          ),
              ),
            ),
          );
        },
      ),
    );
  }
}