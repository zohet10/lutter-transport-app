import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'validador_semana.dart';
import 'autorizaciones/autorizacion_edicion_service.dart';
import 'autorizaciones/solicitud_edicion_model.dart';

import 'formulario_225.dart';
import 'formulario_066.dart';
import 'Formato066TransporteAgua.dart';

class HistorialGeneralScreen extends StatelessWidget {
  final String nombreColeccion;
  final String rolUsuario;

  // Estos dos son opcionales para no romper el código
  // que actualmente abre esta pantalla.
  final String? usuarioActual;
  final String? usuarioUid;

  const HistorialGeneralScreen({
    super.key,
    required this.nombreColeccion,
    required this.rolUsuario,
    this.usuarioActual,
    this.usuarioUid,
  });

  // ============================================================
  // DATOS DEL USUARIO
  // ============================================================

  String get _rol {
    return rolUsuario.trim().toLowerCase();
  }

  String get _nombreUsuario {
    if (usuarioActual != null &&
        usuarioActual!.trim().isNotEmpty) {
      return usuarioActual!.trim();
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user?.displayName != null &&
        user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    if (user?.email != null &&
        user!.email!.trim().isNotEmpty) {
      return user.email!.trim();
    }

    return 'Usuario';
  }

  String get _uidUsuario {
    if (usuarioUid != null &&
        usuarioUid!.trim().isNotEmpty) {
      return usuarioUid!.trim();
    }

    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  bool get _esAdministrador {
    return _rol == 'administrador';
  }

  bool get _esJefe {
    return _rol == 'jefe';
  }

  bool get _esSupervisor {
    return _rol == 'supervisor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Historial - $nombreColeccion',
        ),
        backgroundColor: const Color(0xFF0F1E36),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(nombreColeccion)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E7D32),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error al cargar los registros:\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay registros guardados todavía.',
              ),
            );
          }

          final documentos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final documento = documentos[index];

              final docId = documento.id;

              final data =
                  documento.data()
                      as Map<String, dynamic>;

              // ==================================================
              // DATOS DEL REGISTRO
              // ==================================================

              final placa =
                  data['placa'] ??
                  data['vehiculo'] ??
                  'Sin Placa';

              final tipoTransporte =
                  data['tipoTransporte'] ??
                  data['actividad'] ??
                  'Transporte General';

              final fecha =
                  data['fecha']?.toString() ?? '';

              final finca =
                  data['fincaLote'] ??
                  data['finca'] ??
                  'N/A';

              final actividad =
                  data['actividad']?.toString() ??
                  tipoTransporte.toString();

              // ==================================================
              // SEMANA OPERATIVA
              // ==================================================

              final bool enSemanaActual =
                  ControlZafra
                      .esSemanaActualEditable(
                fecha,
              );

              // ==================================================
              // TARJETA
              // ==================================================

              return _RegistroCard(
                key: ValueKey(docId),
                nombreColeccion:
                    nombreColeccion,
                docId: docId,
                data: data,
                placa: placa.toString(),
                tipoTransporte:
                    tipoTransporte.toString(),
                actividad: actividad,
                fecha: fecha,
                finca: finca.toString(),
                enSemanaActual:
                    enSemanaActual,
                esAdministrador:
                    _esAdministrador,
                esJefe: _esJefe,
                esSupervisor:
                    _esSupervisor,
                nombreUsuario:
                    _nombreUsuario,
                uidUsuario:
                    _uidUsuario,
              );
            },
          );
        },
      ),
    );
  }
}

// ================================================================
// TARJETA INDIVIDUAL
// ================================================================

class _RegistroCard extends StatefulWidget {
  final String nombreColeccion;
  final String docId;
  final Map<String, dynamic> data;

  final String placa;
  final String tipoTransporte;
  final String actividad;
  final String fecha;
  final String finca;

  final bool enSemanaActual;

  final bool esAdministrador;
  final bool esJefe;
  final bool esSupervisor;

  final String nombreUsuario;
  final String uidUsuario;

  const _RegistroCard({
    super.key,
    required this.nombreColeccion,
    required this.docId,
    required this.data,
    required this.placa,
    required this.tipoTransporte,
    required this.actividad,
    required this.fecha,
    required this.finca,
    required this.enSemanaActual,
    required this.esAdministrador,
    required this.esJefe,
    required this.esSupervisor,
    required this.nombreUsuario,
    required this.uidUsuario,
  });

  @override
  State<_RegistroCard> createState() =>
      _RegistroCardState();
}

class _RegistroCardState
    extends State<_RegistroCard> {
  bool _procesando = false;

  Future<SolicitudEdicion?> _obtenerSolicitud() {
    return AutorizacionEdicionService
        .obtenerSolicitudRegistro(
      registroId: widget.docId,
      coleccion: widget.nombreColeccion,
    );
  }

  // ============================================================
  // EDITAR REGISTRO
  // ============================================================

  Future<void> _editarRegistro() async {
    if (_procesando) return;

    setState(() {
      _procesando = true;
    });

    try {
      Widget pantalla;

      // --------------------------------------------------------
      // F-OA-225
      // --------------------------------------------------------

      if (widget.nombreColeccion ==
          'registros_f225') {
        pantalla =
            FormularioTransporteScreen(
          usuarioActual:
              widget.nombreUsuario,
          docId: widget.docId,
          datosIniciales:
              widget.data,
        );
      }

      // --------------------------------------------------------
      // F-066
      // --------------------------------------------------------

      else if (widget.nombreColeccion ==
          'registros_f066') {
        // Si tiene cantidadPersonas es F-066 normal.
        //
        // Si NO tiene cantidadPersonas es
        // F-066 Transporte de Agua.

        final bool esF066Normal =
            widget.data.containsKey(
              'cantidadPersonas',
            );

        if (esF066Normal) {
          pantalla =
              Formato066RutaTransporteScreen(
            usuarioActual:
                widget.nombreUsuario,
            docId: widget.docId,
            datosIniciales:
                widget.data,
          );
        } else {
          pantalla =
              Formato066TransporteAguaScreen(
            usuarioActual:
                widget.nombreUsuario,
            docId: widget.docId,
            datosIniciales:
                widget.data,
          );
        }
      }

      // --------------------------------------------------------
      // COLECCIÓN DESCONOCIDA
      // --------------------------------------------------------

      else {
        throw Exception(
          'No existe un formulario configurado para la colección ${widget.nombreColeccion}.',
        );
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => pantalla,
        ),
      );

      // --------------------------------------------------------
      // SI HABÍA UNA AUTORIZACIÓN, LA CERRAMOS DESPUÉS
      // DE REGRESAR DEL FORMULARIO.
      // --------------------------------------------------------

      if (widget.esJefe &&
          !widget.enSemanaActual) {
        final solicitud =
            await _obtenerSolicitud();

        if (solicitud != null &&
            solicitud.estado ==
                'autorizada') {
          await AutorizacionEdicionService
              .completarSolicitud(
            solicitudId: solicitud.id,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir el registro: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  // ============================================================
  // SOLICITAR EDICIÓN
  // ============================================================

  Future<void> _solicitarEdicion() async {
    if (_procesando) return;

    final motivoController =
        TextEditingController();

    final motivo =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Solicitar edición',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Este registro pertenece a una semana cerrada.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Indique el motivo por el cual necesita modificarlo:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: motivoController,
                maxLines: 4,
                decoration:
                    const InputDecoration(
                  hintText:
                      'Ejemplo: Corrección de horas trabajadas...',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  null,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final motivo =
                    motivoController.text
                        .trim();

                if (motivo.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Debe indicar el motivo.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  context,
                  motivo,
                );
              },
              child: const Text(
                'Enviar solicitud',
              ),
            ),
          ],
        );
      },
    );

    motivoController.dispose();

    if (motivo == null ||
        motivo.trim().isEmpty) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await AutorizacionEdicionService
          .crearSolicitud(
        registroId: widget.docId,
        coleccion:
            widget.nombreColeccion,
        formato:
            _nombreFormato(),
        actividad:
            widget.actividad,
        motivo: motivo,
        solicitadoPor:
            widget.nombreUsuario,
        solicitadoPorUid:
            widget.uidUsuario,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada al Administrador.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  String _nombreFormato() {
    if (widget.nombreColeccion ==
        'registros_f225') {
      return 'F-OA-225';
    }

    if (widget.data.containsKey(
      'cantidadPersonas',
    )) {
      return 'F-066 Transporte';
    }

    return 'F-066 Transporte de Agua';
  }

  // ============================================================
  // ELIMINAR
  // ============================================================

  Future<void> _eliminarRegistro() async {
    if (_procesando) return;

    final confirmar =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Eliminar registro',
          ),
          content: const Text(
            '¿Está seguro de que desea eliminar este registro? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection(
            widget.nombreColeccion,
          )
          .doc(widget.docId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Registro eliminado.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al eliminar: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.local_shipping,
          color: Color(0xFF0F1E36),
        ),
        title: Text(
          'Placa: ${widget.placa} | ${widget.tipoTransporte}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'Fecha: ${widget.fecha} • Finca: ${widget.finca}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: FutureBuilder<
                SolicitudEdicion?>(
              future: _obtenerSolicitud(),
              builder:
                  (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Align(
                    alignment:
                        Alignment.centerLeft,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final solicitud =
                    snapshot.data;

                return _contenido(
                  context,
                  solicitud,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    SolicitudEdicion? solicitud,
  ) {
    final bool solicitudPendiente =
        solicitud?.estado ==
            'pendiente';

    final bool solicitudAutorizada =
        solicitud?.estado ==
            'autorizada' &&
        solicitud?.solicitadoPorUid ==
            widget.uidUsuario;

    // ==========================================================
    // MENSAJES DE ESTADO
    // ==========================================================

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------
        // SEMANA CERRADA
        // ------------------------------------------------------

        if (!widget.enSemanaActual)
          Padding(
            padding:
                const EdgeInsets.only(
              bottom: 10,
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.esAdministrador
                          ? 'Registro de semana cerrada. Administrador puede editarlo.'
                          : 'Registro de semana cerrada.',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ------------------------------------------------------
        // SOLICITUD PENDIENTE
        // ------------------------------------------------------

        if (solicitudPendiente)
          Container(
            width: double.infinity,
            margin:
                const EdgeInsets.only(
              bottom: 10,
            ),
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange
                  .withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 18,
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hay una solicitud de edición pendiente de autorización.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ------------------------------------------------------
        // SOLICITUD AUTORIZADA
        // ------------------------------------------------------

        if (solicitudAutorizada)
          Container(
            width: double.infinity,
            margin:
                const EdgeInsets.only(
              bottom: 10,
            ),
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green
                  .withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.lock_open,
                  size: 18,
                  color: Colors.green,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edición autorizada por el Administrador.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ========================================================
        // BOTONES
        // ========================================================

        Row(
          mainAxisAlignment:
              MainAxisAlignment.end,
          children: [
            // ====================================================
            // ADMINISTRADOR
            // Puede editar cualquier semana.
            // ====================================================

            if (widget.esAdministrador) ...[
              TextButton.icon(
                onPressed: _procesando
                    ? null
                    : _editarRegistro,
                icon: const Icon(
                  Icons.edit,
                  color: Colors.blue,
                  size: 18,
                ),
                label:
                    const Text('Editar'),
              ),
              TextButton.icon(
                onPressed: _procesando
                    ? null
                    : _eliminarRegistro,
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                  size: 18,
                ),
                label:
                    const Text('Eliminar'),
              ),
            ]

            // ====================================================
            // SEMANA ACTUAL
            // Supervisor y Jefe pueden editar.
            // ====================================================

            else if (widget.enSemanaActual &&
                (widget.esSupervisor ||
                    widget.esJefe)) ...[
              TextButton.icon(
                onPressed: _procesando
                    ? null
                    : _editarRegistro,
                icon: const Icon(
                  Icons.edit,
                  color: Colors.blue,
                  size: 18,
                ),
                label:
                    const Text('Editar'),
              ),
            ]

            // ====================================================
            // JEFE - SEMANA CERRADA
            // ====================================================

            else if (widget.esJefe &&
                !widget.enSemanaActual) ...[
              if (solicitudAutorizada)
                TextButton.icon(
                  onPressed: _procesando
                      ? null
                      : _editarRegistro,
                  icon: const Icon(
                    Icons.lock_open,
                    color: Colors.green,
                    size: 18,
                  ),
                  label:
                      const Text('Editar'),
                )
              else if (solicitudPendiente)
                TextButton.icon(
                  onPressed: null,
                  icon: const Icon(
                    Icons.hourglass_empty,
                    size: 18,
                  ),
                  label:
                      const Text('Solicitado'),
                )
              else
                TextButton.icon(
                  onPressed: _procesando
                      ? null
                      : _solicitarEdicion,
                  style:
                      TextButton.styleFrom(
                    foregroundColor:
                        Colors.orange,
                  ),
                  icon: const Icon(
                    Icons.lock_clock,
                    size: 18,
                  ),
                  label: const Text(
                    'Pedir permiso',
                  ),
                ),
            ]

            // ====================================================
            // SUPERVISOR - SEMANA CERRADA
            // ====================================================

            else if (widget.esSupervisor &&
                !widget.enSemanaActual) ...[
              const Tooltip(
                message:
                    'Semana cerrada para edición',
                child: Padding(
                  padding:
                      EdgeInsets.all(8),
                  child: Icon(
                    Icons.lock,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}