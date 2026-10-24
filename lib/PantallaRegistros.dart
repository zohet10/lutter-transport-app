import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'formulario_066.dart';
import 'formulario_225.dart';
import 'Formato066TransporteAgua.dart';
import 'validador_semana.dart';

import 'autorizaciones/autorizacion_edicion_service.dart';
import 'autorizaciones/solicitud_edicion_model.dart';

class ListaRegistrosAdminScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ListaRegistrosAdminScreen({
    super.key,
    this.userData,
  });

  @override
  State<ListaRegistrosAdminScreen> createState() =>
      _ListaRegistrosAdminScreenState();
}

class _ListaRegistrosAdminScreenState
    extends State<ListaRegistrosAdminScreen> {
  // ============================================================
  // COLORES IGUALES A LOS DEMÁS FORMATOS
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  // ============================================================
  // COLECCIONES
  // ============================================================

  final List<String> _coleccionesFormatos = [
    'registros_f225',
    'registros_f066',
  ];

  // ============================================================
  // FILTROS
  // ============================================================

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  String _busqueda = '';
  String? _actividadSeleccionada;

  final TextEditingController _busquedaController =
      TextEditingController();

  late Future<List<Map<String, dynamic>>> _futuroRegistros;
  late Future<List<String>> _futuroActividades;

  // ============================================================
  // USUARIO
  // ============================================================

  String _rolUsuario() {
    return widget.userData?['rol']?.toString().trim().toLowerCase() ?? '';
  }

  String _rolNormalizado() {
    return _rolUsuario()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  bool get _esAdministrador =>
      _rolNormalizado() == 'administrador';

  bool get _esAdministradorAgricola =>
      _rolNormalizado() == 'administrador agricola' ||
      _rolNormalizado() == 'administrador agricola/o';

  bool get _esJefe =>
      _rolNormalizado() == 'jefe de zona';

  bool get _esSupervisor =>
      _rolNormalizado() == 'supervisor';

  String _nombreUsuarioActual() {
    final nombre = widget.userData?['nombre_completo']
            ?.toString()
            .trim() ??
        '';

    return nombre.isEmpty ? 'Desconocido' : nombre;
  }

  String _uidUsuarioActual() {
    return widget.userData?['uid']?.toString().trim() ??
        widget.userData?['usuarioUid']?.toString().trim() ??
        widget.userData?['uidUsuario']?.toString().trim() ??
        '';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _actualizarLista();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _actualizarLista() {
    _futuroRegistros = _obtenerRegistros();
    _futuroActividades = _obtenerActividades();
  }

  // ============================================================
  // FECHAS
  // ============================================================

  DateTime? _convertirFecha(dynamic valor) {
    if (valor == null) return null;

    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    if (valor is String) {
      final texto = valor.trim();
      final partes = texto.split('/');

      if (partes.length == 3) {
        final dia = int.tryParse(partes[0]);
        final mes = int.tryParse(partes[1]);
        final anio = int.tryParse(partes[2]);

        if (dia != null && mes != null && anio != null) {
          return DateTime(anio, mes, dia);
        }
      }

      return DateTime.tryParse(texto);
    }

    return null;
  }

  String _formatearFecha(dynamic valor) {
    final fecha = _convertirFecha(valor);

    if (fecha == null) {
      return 'Sin fecha';
    }

    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  // ============================================================
  // OBTENER REGISTROS
  // ============================================================

  Future<List<Map<String, dynamic>>> _obtenerRegistros() async {
    final List<Map<String, dynamic>> registros = [];

    for (final coleccion in _coleccionesFormatos) {
      final snapshot = await FirebaseFirestore.instance
          .collection(coleccion)
          .get();

      for (final doc in snapshot.docs) {
        final datos = Map<String, dynamic>.from(doc.data());

        registros.add({
          'docId': doc.id,
          'coleccion': coleccion,
          'datos': datos,
        });
      }
    }

    registros.sort((a, b) {
      final fechaA = _convertirFecha(a['datos']['fecha']);
      final fechaB = _convertirFecha(b['datos']['fecha']);

      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;

      return fechaB.compareTo(fechaA);
    });

    return registros;
  }

  // ============================================================
  // ACTIVIDADES
  // ============================================================

  Future<List<String>> _obtenerActividades() async {
    final Set<String> actividades = {};

    for (final coleccion in _coleccionesFormatos) {
      final snapshot = await FirebaseFirestore.instance
          .collection(coleccion)
          .get();

      for (final doc in snapshot.docs) {
        final actividad = doc.data()['actividad'];

        if (actividad != null &&
            actividad.toString().trim().isNotEmpty) {
          actividades.add(actividad.toString().trim());
        }
      }
    }

    final lista = actividades.toList();

    lista.sort(
      (a, b) => a.toLowerCase().compareTo(
        b.toLowerCase(),
      ),
    );

    return lista;
  }

  // ============================================================
  // NOMBRE FORMATO
  // ============================================================

  String _nombreFormato(
    String coleccion,
    Map<String, dynamic> datos,
  ) {
    if (coleccion == 'registros_f225') {
      return 'F-OA-225';
    }

    if (coleccion == 'registros_f066') {
      if (datos.containsKey('cantidadPersonas')) {
        return 'F-066 Transporte';
      }

      return 'F-066 Transporte de Agua';
    }

    return coleccion;
  }

  // ============================================================
  // FILTROS
  // ============================================================

  bool _cumpleFiltros(
    Map<String, dynamic> registro,
  ) {
    final datos = Map<String, dynamic>.from(
      registro['datos'] ?? {},
    );

    if (_busqueda.trim().isNotEmpty) {
      final busqueda = _busqueda.toLowerCase().trim();

      final texto = [
        _nombreFormato(
          registro['coleccion'],
          datos,
        ),
        datos['actividad'],
        datos['contratista'],
        datos['subcontratista'],
        datos['fincaLote'],
        datos['procedencia'],
        datos['placa'],
        datos['transportista'],
        datos['lineaRuta'],
        datos['descripcion'],
        datos['zafra'],
        datos['creadoPor'],
        datos['editadoPor'],
      ]
          .where((e) => e != null)
          .map((e) => e.toString().toLowerCase())
          .join(' ');

      if (!texto.contains(busqueda)) {
        return false;
      }
    }

    if (_actividadSeleccionada != null &&
        _actividadSeleccionada!.isNotEmpty) {
      if (datos['actividad']?.toString() !=
          _actividadSeleccionada) {
        return false;
      }
    }

    final fechaRegistro = _convertirFecha(datos['fecha']);

    if (_fechaInicio != null) {
      final inicio = DateTime(
        _fechaInicio!.year,
        _fechaInicio!.month,
        _fechaInicio!.day,
      );

      if (fechaRegistro == null ||
          fechaRegistro.isBefore(inicio)) {
        return false;
      }
    }

    if (_fechaFin != null) {
      final fin = DateTime(
        _fechaFin!.year,
        _fechaFin!.month,
        _fechaFin!.day,
        23,
        59,
        59,
        999,
      );

      if (fechaRegistro == null ||
          fechaRegistro.isAfter(fin)) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // RANGO DE FECHAS
  // ============================================================

  Future<void> _seleccionarRangoFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      currentDate: DateTime.now(),
      initialDateRange:
          (_fechaInicio != null && _fechaFin != null)
              ? DateTimeRange(
                  start: _fechaInicio!,
                  end: _fechaFin!,
                )
              : null,
      helpText: 'Selecciona el rango de fechas',
      cancelText: 'CANCELAR',
      confirmText: 'APLICAR',
      fieldStartHintText: 'Fecha inicial',
      fieldEndHintText: 'Fecha final',
      fieldStartLabelText: 'Desde',
      fieldEndLabelText: 'Hasta',
    );

    if (rango == null) return;

    setState(() {
      _fechaInicio = DateTime(
        rango.start.year,
        rango.start.month,
        rango.start.day,
      );

      _fechaFin = DateTime(
        rango.end.year,
        rango.end.month,
        rango.end.day,
      );
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _busquedaController.clear();
      _busqueda = '';
      _actividadSeleccionada = null;
      _fechaInicio = null;
      _fechaFin = null;
    });
  }

  // ============================================================
  // EDITAR REGISTRO
  // ============================================================

  Future<void> _editarRegistro(
    BuildContext context,
    String coleccion,
    String docId,
    Map<String, dynamic> datos,
  ) async {
    if (coleccion == 'registros_f225') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FormularioTransporteScreen(
            docId: docId,
            datosIniciales: datos,
            usuarioActual: _nombreUsuarioActual(),
          ),
        ),
      );
    } else if (coleccion == 'registros_f066') {
      if (datos.containsKey('cantidadPersonas')) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Formato066RutaTransporteScreen(
              docId: docId,
              datosIniciales: datos,
              usuarioActual: _nombreUsuarioActual(),
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Formato066TransporteAguaScreen(
              docId: docId,
              datosIniciales: datos,
              usuarioActual: _nombreUsuarioActual(),
            ),
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _actualizarLista();
    });
  }

  // ============================================================
  // SOLICITAR EDICIÓN
  // ============================================================

  Future<void> _solicitarEdicion(
    BuildContext context,
    String coleccion,
    String docId,
    Map<String, dynamic> datos,
  ) async {
    final controller = TextEditingController();

    final motivo = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
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
                'Indique el motivo de la solicitud:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Escriba el motivo...',
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(
                      color: colorBorde,
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(
                      color: colorVerde,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text(
                'CANCELAR',
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorVerde,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final texto =
                    controller.text.trim();

                if (texto.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
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
                  dialogContext,
                  texto,
                );
              },
              child: const Text(
                'ENVIAR',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (motivo == null || motivo.trim().isEmpty) {
      return;
    }

    try {
      await AutorizacionEdicionService
          .crearSolicitud(
        registroId: docId,
        coleccion: coleccion,
        formato: _nombreFormato(
          coleccion,
          datos,
        ),
        actividad:
            datos['actividad']?.toString() ?? '',
        motivo: motivo,
        solicitadoPor:
            _nombreUsuarioActual(),
        solicitadoPorUid:
            _uidUsuarioActual(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada al Administrador.',
          ),
          backgroundColor: colorVerde,
        ),
      );

      setState(() {
        _actualizarLista();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
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
    }
  }

  // ============================================================
  // ELIMINAR
  // ============================================================

  Future<void> _eliminarRegistro(
    BuildContext context,
    String coleccion,
    String docId,
  ) async {
    if (!_esAdministrador) return;

    final confirmar =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar registro',
          ),
          content: const Text(
            '¿Está seguro de que desea eliminar este registro?\n\n'
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text(
                'CANCELAR',
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text(
                'ELIMINAR',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance
          .collection(coleccion)
          .doc(docId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registro eliminado correctamente.',
          ),
          backgroundColor: colorVerde,
        ),
      );

      setState(() {
        _actualizarLista();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al eliminar el registro: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SOLICITUD EXISTENTE
  // ============================================================

  Future<SolicitudEdicion?> _obtenerSolicitud(
    String docId,
    String coleccion,
  ) {
    return AutorizacionEdicionService
        .obtenerSolicitudRegistro(
      registroId: docId,
      coleccion: coleccion,
    );
  }

  // ============================================================
  // TEXTO
  // ============================================================

  String _texto(dynamic valor) {
    if (valor == null) return '-';

    final texto = valor.toString().trim();

    return texto.isEmpty ? '-' : texto;
  }

  String _nombreCreador(dynamic valor) {
    final creador =
        valor?.toString().trim() ?? '';

    return creador.isEmpty || creador == '-'
        ? 'Sin usuario'
        : creador;
  }

  // ============================================================
  // DATO DE REGISTRO
  // ============================================================

  Widget _datoCard(
    IconData icono,
    String titulo,
    dynamic valor,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 180,
        maxWidth: 260,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icono,
            size: 19,
            color: colorVerde,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _texto(valor),
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colorPrincipal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTROLES
  // ============================================================

  Widget _construirControles({
    required BuildContext context,
    required String coleccion,
    required String docId,
    required Map<String, dynamic> datos,
    required bool semanaActual,
    required SolicitudEdicion? solicitud,
  }) {
    final estado =
        solicitud?.estado ?? '';

    final pendiente =
        estado == 'pendiente';

    final autorizada =
        estado == 'autorizada' &&
        solicitud?.solicitadoPorUid ==
            _uidUsuarioActual();

    // ADMIN AGRÍCOLA
    if (_esAdministradorAgricola) {
      return _soloConsulta();
    }

    // ADMINISTRADOR
    if (_esAdministrador) {
      return _filaBotones(
        children: [
          OutlinedButton.icon(
            onPressed: () => _editarRegistro(
              context,
              coleccion,
              docId,
              datos,
            ),
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
          ),
          ElevatedButton.icon(
            onPressed: () => _eliminarRegistro(
              context,
              coleccion,
              docId,
            ),
            icon: const Icon(Icons.delete),
            label: const Text('Eliminar'),
            style:
                ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    // SUPERVISOR
    if (_esSupervisor) {
      if (semanaActual) {
        return _filaBotones(
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  _editarRegistro(
                context,
                coleccion,
                docId,
                datos,
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Editar'),
            ),
          ],
        );
      }

      return _mensajeBloqueado(
        'Semana cerrada para edición',
      );
    }

    // JEFE DE ZONA
    if (_esJefe) {
      if (semanaActual) {
        return _filaBotones(
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  _editarRegistro(
                context,
                coleccion,
                docId,
                datos,
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Editar'),
            ),
          ],
        );
      }

      if (autorizada) {
        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            _estadoChip(
              'Edición autorizada',
              colorVerde,
              Icons.lock_open,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _editarRegistro(
                context,
                coleccion,
                docId,
                datos,
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Editar'),
            ),
          ],
        );
      }

      if (pendiente) {
        return _estadoChip(
          'Solicitud pendiente',
          Colors.orange,
          Icons.hourglass_empty,
        );
      }

      return _filaBotones(
        children: [
          OutlinedButton.icon(
            onPressed: () =>
                _solicitarEdicion(
              context,
              coleccion,
              docId,
              datos,
            ),
            icon: const Icon(
              Icons.lock_clock,
            ),
            label: const Text(
              'Pedir permiso',
            ),
            style:
                OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
          ),
        ],
      );
    }

    return _soloConsulta();
  }

  Widget _filaBotones({
    required List<Widget> children,
  }) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 8,
      children: children,
    );
  }

  Widget _soloConsulta() {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.visibility_outlined,
            size: 18,
            color: Colors.grey,
          ),
          SizedBox(width: 6),
          Text(
            'Solo consulta',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeBloqueado(String texto) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 18,
            color: Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoChip(
    String texto,
    Color color,
    IconData icono,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icono,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DEL REGISTRO
  // ============================================================

  Widget _construirCard(
    BuildContext context,
    Map<String, dynamic> registro,
  ) {
    final String coleccion =
        registro['coleccion'];

    final String docId =
        registro['docId'];

    final datos =
        Map<String, dynamic>.from(
      registro['datos'] ?? {},
    );

    final actividad =
        _texto(datos['actividad']);

    final fecha =
        _formatearFecha(datos['fecha']);

    final semanaActual =
        ControlZafra.esSemanaActualEditable(
      fecha,
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: colorBorde,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:
                const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // ENCABEZADO RESPONSIVE
            // ==================================================

            LayoutBuilder(
              builder: (context, constraints) {
                final pequeno =
                    constraints.maxWidth < 600;

                final titulo = Text(
                  actividad,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorVerde,
                  ),
                );

                final info = Column(
                  crossAxisAlignment:
                      pequeno
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                  children: [
                    Text(
                      fecha,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(
                            maxWidth: 220,
                          ),
                          child: Text(
                            _nombreCreador(
                              datos['creadoPor'],
                            ),
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                if (pequeno) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      titulo,
                      const SizedBox(height: 8),
                      info,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: titulo,
                    ),
                    const SizedBox(width: 12),
                    info,
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            const Divider(
              height: 1,
              color: colorBorde,
            ),

            const SizedBox(height: 14),

            // ==================================================
            // DATOS
            // ==================================================

            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                if (datos['contratista'] != null)
                  _datoCard(
                    Icons.business,
                    'Contratista',
                    datos['contratista'],
                  ),

                if (datos['subcontratista'] != null)
                  _datoCard(
                    Icons.business_center,
                    'Subcontratista',
                    datos['subcontratista'],
                  ),

                if (datos['fincaLote'] != null)
                  _datoCard(
                    Icons.landscape,
                    'Finca / Lote',
                    datos['fincaLote'],
                  ),

                if (datos['procedencia'] != null)
                  _datoCard(
                    Icons.location_on,
                    'Procedencia',
                    datos['procedencia'],
                  ),

                if (datos['placa'] != null)
                  _datoCard(
                    Icons.directions_car,
                    'Placa',
                    datos['placa'],
                  ),

                if (datos['transportista'] != null)
                  _datoCard(
                    Icons.person,
                    'Transportista',
                    datos['transportista'],
                  ),

                if (datos['lineaRuta'] != null)
                  _datoCard(
                    Icons.route,
                    'Línea / Ruta',
                    datos['lineaRuta'],
                  ),

                if (datos['kilometraje'] != null)
                  _datoCard(
                    Icons.speed,
                    'Kilometraje',
                    datos['kilometraje'],
                  ),

                if (datos['cantidadPersonas'] != null)
                  _datoCard(
                    Icons.people,
                    'Cantidad de personas',
                    datos['cantidadPersonas'],
                  ),

                if (datos['zafra'] != null)
                  _datoCard(
                    Icons.calendar_month,
                    'Zafra',
                    datos['zafra'],
                  ),
              ],
            ),

            // ==================================================
            // DESCRIPCIÓN
            // ==================================================

            if (datos['descripcion'] != null &&
                datos['descripcion']
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(
                color: colorBorde,
              ),
              const SizedBox(height: 8),
              const Text(
                'Descripción',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorPrincipal,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _texto(datos['descripcion']),
                style: const TextStyle(
                  color: Colors.black87,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ==================================================
            // CONTROLES
            // ==================================================

            FutureBuilder<SolicitudEdicion?>(
              future: _obtenerSolicitud(
                docId,
                coleccion,
              ),
              builder:
                  (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Align(
                    alignment:
                        Alignment.centerRight,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorVerde,
                      ),
                    ),
                  );
                }

                return _construirControles(
                  context: context,
                  coleccion: coleccion,
                  docId: docId,
                  datos: datos,
                  semanaActual:
                      semanaActual,
                  solicitud:
                      snapshot.data,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DECORACIÓN
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color: colorVerde,
      ),

      suffixIcon: suffixIcon,

      filled: true,
      fillColor: Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color: colorBorde,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color: colorVerde,
          width: 1.3,
        ),
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color: colorBorde,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool hayFiltros =
        _busqueda.isNotEmpty ||
        _actividadSeleccionada != null ||
        _fechaInicio != null ||
        _fechaFin != null;

    return Scaffold(
      backgroundColor: colorFondo,

      appBar: AppBar(
        backgroundColor: colorPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Registros',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              setState(() {
                _actualizarLista();
              });
            },
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ======================================================
          // FILTROS
          // ======================================================

          Container(
            color: colorFondo,
            padding:
                const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder:
                  (context, constraints) {
                final pequeno =
                    constraints.maxWidth < 700;

                return Column(
                  children: [
                    // BUSCADOR
                    TextField(
                      controller:
                          _busquedaController,
                      onChanged: (valor) {
                        setState(() {
                          _busqueda = valor;
                        });
                      },
                      decoration:
                          _inputDecoration(
                        label:
                            'Buscar registros',
                        hint:
                            'Actividad, finca, placa, transportista...',
                        icon:
                            Icons.search,
                        suffixIcon:
                            _busqueda.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _busquedaController
                                          .clear();

                                      setState(() {
                                        _busqueda =
                                            '';
                                      });
                                    },
                                    icon:
                                        const Icon(
                                      Icons.clear,
                                      color:
                                          Colors.grey,
                                    ),
                                  )
                                : null,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // FECHA + ACTIVIDAD
                    if (pequeno)
                      Column(
                        children: [
                          _campoFecha(),
                          const SizedBox(
                            height: 12,
                          ),
                          _campoActividad(),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child:
                                _campoFecha(),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child:
                                _campoActividad(),
                          ),
                        ],
                      ),

                    if (hayFiltros)
                      Align(
                        alignment:
                            Alignment.centerRight,
                        child:
                            TextButton.icon(
                          onPressed:
                              _limpiarFiltros,
                          icon:
                              const Icon(
                            Icons
                                .filter_alt_off,
                            color:
                                colorVerde,
                          ),
                          label:
                              const Text(
                            'Limpiar filtros',
                            style:
                                TextStyle(
                              color:
                                  colorVerde,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          const Divider(
            height: 1,
            color: colorBorde,
          ),

          // ======================================================
          // LISTA
          // ======================================================

          Expanded(
            child: FutureBuilder<
                List<Map<String, dynamic>>>(
              future: _futuroRegistros,
              builder:
                  (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color: colorVerde,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _pantallaError(
                    snapshot.error,
                  );
                }

                final registros =
                    snapshot.data ?? [];

                final filtrados =
                    registros
                        .where(
                          _cumpleFiltros,
                        )
                        .toList();

                if (filtrados.isEmpty) {
                  return _sinResultados(
                    hayFiltros,
                  );
                }

                return RefreshIndicator(
                  color: colorVerde,
                  onRefresh: () async {
                    setState(() {
                      _actualizarLista();
                    });

                    await _futuroRegistros;
                  },
                  child:
                      ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      30,
                    ),
                    itemCount:
                        filtrados.length,
                    itemBuilder:
                        (context, index) {
                      return _construirCard(
                        context,
                        filtrados[index],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CAMPO FECHA
  // ============================================================

  Widget _campoFecha() {
    final tieneFechas =
        _fechaInicio != null &&
        _fechaFin != null;

    return InkWell(
      onTap: _seleccionarRangoFechas,
      borderRadius:
          BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Rango de fechas',
          icon: Icons.date_range,
          suffixIcon: tieneFechas
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _fechaInicio = null;
                      _fechaFin = null;
                    });
                  },
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
        child: Text(
          tieneFechas
              ? '${DateFormat('dd/MM/yyyy').format(_fechaInicio!)} - '
                  '${DateFormat('dd/MM/yyyy').format(_fechaFin!)}'
              : 'Seleccionar rango',
          style: TextStyle(
            color: tieneFechas
                ? Colors.black87
                : Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CAMPO ACTIVIDAD
  // ============================================================

  Widget _campoActividad() {
    return FutureBuilder<List<String>>(
      future: _futuroActividades,
      builder: (context, snapshot) {
        final actividades =
            snapshot.data ?? [];

        String? valor =
            _actividadSeleccionada;

        if (valor != null &&
            !actividades.contains(valor)) {
          valor = null;
        }

        return DropdownButtonFormField<String>(
          value: valor,
          isExpanded: true,

          decoration:
              _inputDecoration(
            label: 'Actividad',
            icon:
                Icons.work_outline,
          ),

          hint: const Text(
            'Todas las actividades',
          ),

          items:
              actividades.map(
            (actividad) {
              return DropdownMenuItem<
                  String>(
                value: actividad,
                child: Text(
                  actividad,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            },
          ).toList(),

          onChanged: (valor) {
            setState(() {
              _actividadSeleccionada =
                  valor;
            });
          },
        );
      },
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _pantallaError(dynamic error) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ocurrió un error al cargar los registros.',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    colorVerde,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _actualizarLista();
                });
              },
              icon:
                  const Icon(Icons.refresh),
              label:
                  const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIN RESULTADOS
  // ============================================================

  Widget _sinResultados(
    bool hayFiltros,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              hayFiltros
                  ? Icons.search_off
                  : Icons
                      .description_outlined,
              size: 65,
              color:
                  Colors.grey[400],
            ),
            const SizedBox(height: 15),
            Text(
              hayFiltros
                  ? 'No se encontraron registros con estos filtros.'
                  : 'No hay registros disponibles.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color:
                    Colors.grey[600],
                fontWeight:
                    FontWeight.w500,
              ),
            ),
            if (hayFiltros) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed:
                    _limpiarFiltros,
                child:
                    const Text(
                  'Limpiar filtros',
                  style: TextStyle(
                    color:
                        colorVerde,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}