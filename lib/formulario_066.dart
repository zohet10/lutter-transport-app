import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'CalcularKm.dart';

class Formato066RutaTransporteScreen extends StatefulWidget {
  final ValueChanged<String>? onKilometrajeCalculado;
  final String? usuarioActual;
  final String? docId;
  final Map<String, dynamic>? datosIniciales;

  const Formato066RutaTransporteScreen({
    super.key,
    this.onKilometrajeCalculado,
    this.usuarioActual,
    this.docId,
    this.datosIniciales,
  });

  @override
  State<Formato066RutaTransporteScreen> createState() =>
      _Formato066RutaTransporteScreenState();
}

class _Formato066RutaTransporteScreenState
    extends State<Formato066RutaTransporteScreen> {
  final _formKey = GlobalKey<FormState>();

  // ============================================================
  // COLORES
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  // ============================================================
  // CONTROLADORES
  // ============================================================

  final TextEditingController _contratistaController =
      TextEditingController(text: 'ARAME');

  // Zafra queda vacía en registros nuevos.
  // El usuario debe ingresarla.
  final TextEditingController _zafraController =
      TextEditingController();

  final TextEditingController _fechaController =
      TextEditingController();

  final TextEditingController _transportistaController =
      TextEditingController();

  final TextEditingController _lineaRutaController =
      TextEditingController();

  final TextEditingController _kmController =
      TextEditingController();

  final TextEditingController _descripcionController =
      TextEditingController();

  final TextEditingController _cantidadPersonasController =
      TextEditingController();

  // ============================================================
  // VARIABLES
  // ============================================================

  String? _actividadSeleccionada;
  String? _fincaLoteSeleccionada;
  String? _procedenciaSeleccionada;
  String? _placaSeleccionada;
  String? _subcontratistaSeleccionado;

  List<String> _listaActividades = [];
  List<String> _listaFincas = [];
  List<Map<String, dynamic>> _listaTransportistas = [];
  List<String> _listaNombresTransportistas = [];

  bool _cargandoDatos = true;
  bool _guardando = false;

  // Se utiliza para reconstruir los Autocomplete
  // después de guardar.
  int _resetFormulario = 0;

  // ============================================================
  // SEMANA ACTUAL
  // DOMINGO → SÁBADO
  // ============================================================

  late DateTime _inicioSemana;
  late DateTime _finSemana;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _calcularRangoSemanaActual();

    // Solo colocar fecha automáticamente
    // cuando es un registro nuevo.
    if (widget.datosIniciales == null ||
        widget.datosIniciales!.isEmpty) {
      final hoy = DateTime.now();

      _fechaController.text =
          "${hoy.day.toString().padLeft(2, '0')}/"
          "${hoy.month.toString().padLeft(2, '0')}/"
          "${hoy.year}";
    }

    _cargarDatosFirebase();
    _cargarDatosIniciales();
  }

  // ============================================================
  // CARGAR DATOS INICIALES
  // ============================================================

  void _cargarDatosIniciales() {
    final datos = widget.datosIniciales;

    if (datos == null || datos.isEmpty) {
      return;
    }

    String texto(dynamic value) {
      return value == null ? '' : value.toString();
    }

    final contratista =
        texto(datos['contratista']);

    if (contratista.isNotEmpty) {
      _contratistaController.text =
          contratista;
    }

    // Zafra solamente se carga cuando estamos editando.
    final zafra =
        texto(datos['zafra']);

    if (zafra.isNotEmpty) {
      _zafraController.text =
          zafra;
    }

    final fecha =
        texto(datos['fecha']);

    if (fecha.isNotEmpty) {
      _fechaController.text =
          fecha;
    }

    _transportistaController.text =
        texto(datos['transportista']);

    _lineaRutaController.text =
        texto(datos['lineaRuta']);

    _kmController.text =
        texto(datos['kilometraje']);

    _descripcionController.text =
        texto(datos['descripcion']);

    _cantidadPersonasController.text =
        texto(datos['cantidadPersonas']);

    final actividad =
        texto(datos['actividad']);

    _actividadSeleccionada =
        actividad.isEmpty
            ? null
            : actividad;

    final finca =
        texto(datos['fincaLote']);

    _fincaLoteSeleccionada =
        finca.isEmpty
            ? null
            : finca;

    final procedencia =
        texto(datos['procedencia']);

    _procedenciaSeleccionada =
        procedencia.isEmpty
            ? null
            : procedencia;

    final placa =
        texto(datos['placa']);

    _placaSeleccionada =
        placa.isEmpty
            ? null
            : placa.toUpperCase();

    final subcontratista =
        texto(datos['subcontratista']);

    _subcontratistaSeleccionado =
        subcontratista.isEmpty
            ? null
            : subcontratista;
  }

  // ============================================================
  // USUARIO
  // ============================================================

  String _usuarioParaGuardar() {
    final externo =
        widget.usuarioActual?.trim();

    if (externo != null &&
        externo.isNotEmpty) {
      return externo;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user != null) {
      final nombre =
          user.displayName?.trim();

      if (nombre != null &&
          nombre.isNotEmpty) {
        return nombre;
      }

      final email =
          user.email?.trim();

      if (email != null &&
          email.isNotEmpty) {
        return email;
      }

      return user.uid;
    }

    return 'Desconocido';
  }

  String? _usuarioUid() {
    return FirebaseAuth
        .instance
        .currentUser
        ?.uid;
  }

  // ============================================================
  // CALCULAR SEMANA
  // DOMINGO → SÁBADO
  // ============================================================

  void _calcularRangoSemanaActual() {
    final ahora = DateTime.now();

    final diasDesdeDomingo =
        (ahora.weekday - DateTime.sunday + 7) % 7;

    _inicioSemana = ahora.subtract(
      Duration(
        days: diasDesdeDomingo,
      ),
    );

    _inicioSemana = DateTime(
      _inicioSemana.year,
      _inicioSemana.month,
      _inicioSemana.day,
    );

    _finSemana = _inicioSemana.add(
      const Duration(
        days: 6,
        hours: 23,
        minutes: 59,
        seconds: 59,
      ),
    );
  }

  // ============================================================
  // CARGAR DATOS FIREBASE
  // ============================================================

  Future<void> _cargarDatosFirebase() async {
    try {
      // ==========================================================
      // ACTIVIDADES
      // ==========================================================

      final actSnap = await FirebaseFirestore
          .instance
          .collection('actividad_labor')
          .get();

      final List<String> actList =
          actSnap.docs.map((doc) {
        final data =
            doc.data();

        final nombreActividad =
            data['actividad'] ??
            data['nombre'] ??
            data['descripcion'] ??
            data['nombreActividad'];

        return nombreActividad
                ?.toString()
                .trim() ??
            '';
      }).where((element) {
        return element.isNotEmpty &&
            !element.startsWith(
              '3jkHQTIS',
            ) &&
            element.length > 3;
      }).toList();

      // ==========================================================
      // FINCAS
      // ==========================================================

      final fincaSnap = await FirebaseFirestore
          .instance
          .collection('fincas')
          .get();

      final List<String> fincaList =
          fincaSnap.docs.map((doc) {
        final data =
            doc.data();

        return (
          data['nombre'] ??
          data['finca'] ??
          data['descripcion'] ??
          ''
        )
            .toString()
            .trim();
      }).where((element) {
        return element.isNotEmpty;
      }).toList();

      // ==========================================================
      // TRANSPORTISTAS
      // ==========================================================

      final transpSnap = await FirebaseFirestore
          .instance
          .collection('transportistas')
          .get();

      final List<Map<String, dynamic>>
          transpList =
          transpSnap.docs.map((doc) {
        final data =
            doc.data();

        return {
          'placa':
              (
                data['placa'] ??
                data['Placa'] ??
                ''
              )
                  .toString()
                  .toUpperCase()
                  .trim(),

          'nombre':
              (
                data['nombreTransportista'] ??
                data['transportista'] ??
                data['nombre'] ??
                data['chofer'] ??
                ''
              )
                  .toString()
                  .trim(),
        };
      }).where((item) {
        return item['placa'] != '';
      }).toList();

      // ==========================================================
      // NOMBRES DE TRANSPORTISTAS
      // ==========================================================

      final List<String> nombresList =
          transpList
              .map(
                (t) =>
                    t['nombre']
                        as String,
              )
              .where(
                (nombre) =>
                    nombre.isNotEmpty,
              )
              .toSet()
              .toList();

      if (!mounted) return;

      setState(() {
        _listaActividades =
            actList;

        _listaFincas =
            fincaList;

        _listaTransportistas =
            transpList;

        _listaNombresTransportistas =
            nombresList;

        _cargandoDatos =
            false;
      });
    } catch (e) {
      debugPrint(
        'Error cargando datos de Firebase: $e',
      );

      if (!mounted) return;

      setState(() {
        _cargandoDatos = false;
      });
    }
  }

  // ============================================================
  // LIMPIAR TODO EL FORMULARIO
  // ============================================================

  void _limpiarFormulario() {
    _contratistaController.clear();
    _zafraController.clear();
    _fechaController.clear();
    _transportistaController.clear();
    _lineaRutaController.clear();
    _kmController.clear();
    _descripcionController.clear();
    _cantidadPersonasController.clear();

    setState(() {
      _actividadSeleccionada = null;
      _fincaLoteSeleccionada = null;
      _procedenciaSeleccionada = null;
      _placaSeleccionada = null;
      _subcontratistaSeleccionado = null;

      // Reconstruir Autocomplete.
      _resetFormulario++;
    });

    _formKey.currentState?.reset();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _contratistaController.dispose();
    _zafraController.dispose();
    _fechaController.dispose();
    _transportistaController.dispose();
    _lineaRutaController.dispose();
    _kmController.dispose();
    _descripcionController.dispose();
    _cantidadPersonasController.dispose();

    super.dispose();
  }

  // ============================================================
  // SELECCIONAR FECHA
  // ============================================================

  Future<void> _seleccionarFecha(
    BuildContext context,
  ) async {
    _calcularRangoSemanaActual();

    DateTime initialDateToUse =
        DateTime.now();

    if (initialDateToUse
        .isBefore(_inicioSemana)) {
      initialDateToUse =
          _inicioSemana;
    } else if (initialDateToUse
        .isAfter(_finSemana)) {
      initialDateToUse =
          _finSemana;
    }

    final fechaSeleccionada =
        await showDatePicker(
      context: context,
      initialDate:
          initialDateToUse,
      firstDate:
          _inicioSemana,
      lastDate:
          _finSemana,
      helpText:
          'Seleccione fecha de la semana actual',
    );

    if (fechaSeleccionada !=
        null) {
      setState(() {
        _fechaController.text =
            "${fechaSeleccionada.day.toString().padLeft(2, '0')}/"
            "${fechaSeleccionada.month.toString().padLeft(2, '0')}/"
            "${fechaSeleccionada.year}";
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_cargandoDatos) {
      return Scaffold(
        backgroundColor:
            colorFondo,
        appBar: AppBar(
          title: const Text(
            'Formato 066 - Ruta Transporte',
          ),
          backgroundColor:
              colorPrincipal,
          foregroundColor:
              Colors.white,
        ),
        body: const Center(
          child:
              CircularProgressIndicator(
            color: colorVerde,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          colorFondo,

      // ========================================================
      // APPBAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Formato 066 - Ruta Transporte',
        ),
        backgroundColor:
            colorPrincipal,
        foregroundColor:
            Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // CUERPO RESPONSIVO
      // ========================================================

      body: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 800,
                ),
                child: Card(
                  color:
                      Colors.white,
                  elevation: 3,
                  shadowColor:
                      Colors.black.withOpacity(
                    0.08,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [

                          // ==================================================
                          // TÍTULO
                          // ==================================================

                          const Text(
                            'Registro de Ruta de Transporte (F-066)',
                            style: TextStyle(
                              color:
                                  colorVerde,
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          const Text(
                            'Nota: Solo se permiten registros correspondientes a la semana en curso.',
                            style: TextStyle(
                              color:
                                  Colors.grey,
                              fontSize: 12,
                            ),
                          ),

                          const Divider(
                            height: 24,
                          ),

                          // ==================================================
                          // CONTRATISTA
                          // ==================================================

                          _tituloCampo(
                            'Contratista',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          TextFormField(
                            controller:
                                _contratistaController,
                            decoration:
                                _inputDecoration(
                              'Ingrese contratista',
                              Icons.business,
                            ),
                            validator:
                                (value) =>
                                    value == null ||
                                            value
                                                .trim()
                                                .isEmpty
                                        ? 'Campo requerido'
                                        : null,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // SUBCONTRATISTA
                          // ==================================================

                          _tituloCampo(
                            'Nombre del Subcontratista',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          KeyedSubtree(
                            key: ValueKey(
                              'subcontratista_$_resetFormulario',
                            ),
                            child:
                                _autocompleteSubcontratista(),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // ACTIVIDAD
                          // ==================================================

                          _tituloCampo(
                            'Actividad',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          KeyedSubtree(
                            key: ValueKey(
                              'actividad_$_resetFormulario',
                            ),
                            child:
                                _autocompleteActividad(),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // ZAFRA
                          // ==========================================================

                          _tituloCampo(
                            'Zafra',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          TextFormField(
                            controller:
                                _zafraController,
                            keyboardType:
                                TextInputType.number,
                            decoration:
                                _inputDecoration(
                              'Ingrese la zafra',
                              Icons.calendar_view_month,
                            ),
                            validator:
                                (value) =>
                                    value == null ||
                                            value
                                                .trim()
                                                .isEmpty
                                        ? 'Ingrese la zafra'
                                        : null,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // FECHA
                          // ==================================================

                          _tituloCampo(
                            'Fecha (Semana Actual)',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          TextFormField(
                            controller:
                                _fechaController,
                            readOnly:
                                true,
                            onTap: () =>
                                _seleccionarFecha(
                              context,
                            ),
                            decoration:
                                _inputDecoration(
                              'Seleccione la fecha',
                              Icons.calendar_today,
                              suffix:
                                  const Icon(
                                Icons.arrow_drop_down,
                                color:
                                    Colors.grey,
                              ),
                            ),
                            validator:
                                (value) {
                              if (value ==
                                      null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Campo requerido';
                              }

                              try {
                                final partes =
                                    value.split(
                                  '/',
                                );

                                final fechaVal =
                                    DateTime(
                                  int.parse(
                                    partes[2],
                                  ),
                                  int.parse(
                                    partes[1],
                                  ),
                                  int.parse(
                                    partes[0],
                                  ),
                                );

                                _calcularRangoSemanaActual();

                                final inicio =
                                    DateTime(
                                  _inicioSemana
                                      .year,
                                  _inicioSemana
                                      .month,
                                  _inicioSemana
                                      .day,
                                );

                                if (fechaVal
                                        .isBefore(
                                      inicio,
                                    ) ||
                                    fechaVal
                                        .isAfter(
                                      _finSemana,
                                    )) {
                                  return 'La fecha debe pertenecer a la semana actual';
                                }
                              } catch (_) {
                                return 'Formato de fecha inválido';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // FINCA / PROCEDENCIA
                          // RESPONSIVO
                          // ==================================================

                          LayoutBuilder(
                            builder:
                                (
                                  context,
                                  constraints,
                                ) {
                              final esMovil =
                                  constraints.maxWidth <
                                      600;

                              final fincaWidget =
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  _tituloCampo(
                                    'Finca / Lote',
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  KeyedSubtree(
                                    key: ValueKey(
                                      'finca_$_resetFormulario',
                                    ),
                                    child:
                                        _autocompleteFinca(
                                      esFinca:
                                          true,
                                    ),
                                  ),
                                ],
                              );

                              final procedenciaWidget =
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  _tituloCampo(
                                    'Procedencia',
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  KeyedSubtree(
                                    key: ValueKey(
                                      'procedencia_$_resetFormulario',
                                    ),
                                    child:
                                        _autocompleteFinca(
                                      esFinca:
                                          false,
                                    ),
                                  ),
                                ],
                              );

                              if (esMovil) {
                                return Column(
                                  children: [
                                    fincaWidget,
                                    const SizedBox(
                                      height: 12,
                                    ),
                                    procedenciaWidget,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Expanded(
                                    child:
                                        fincaWidget,
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Expanded(
                                    child:
                                        procedenciaWidget,
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // PLACA
                          // ==================================================

                          _tituloCampo(
                            'Placa',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          KeyedSubtree(
                            key: ValueKey(
                              'placa_$_resetFormulario',
                            ),
                            child:
                                _autocompletePlaca(),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // TRANSPORTISTA
                          // ==================================================

                          _tituloCampo(
                            'Transportista',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          TextFormField(
                            controller:
                                _transportistaController,
                            readOnly:
                                true,
                            decoration:
                                _inputDecoration(
                              'Transportista vinculado',
                              Icons.local_shipping,
                            ),
                            validator:
                                (value) =>
                                    value == null ||
                                            value
                                                .trim()
                                                .isEmpty
                                        ? 'Campo requerido'
                                        : null,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // CANTIDAD PERSONAS
                          // ==================================================

                          _tituloCampo(
                            'Cantidad de Personas',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          TextFormField(
                            controller:
                                _cantidadPersonasController,
                            keyboardType:
                                TextInputType.number,
                            decoration:
                                _inputDecoration(
                              'Ej. 5',
                              Icons.group,
                            ),
                            validator:
                                (value) =>
                                    value == null ||
                                            value
                                                .trim()
                                                .isEmpty
                                        ? 'Campo requerido'
                                        : null,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // LÍNEA DE RUTA
                          // ==================================================

                          _tituloCampo(
                            'Línea de Ruta',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          TextFormField(
                            controller:
                                _lineaRutaController,
                            decoration:
                                _inputDecoration(
                              'Detalle de ruta',
                              Icons.alt_route,
                            ),
                            validator:
                                (value) =>
                                    value == null ||
                                            value
                                                .trim()
                                                .isEmpty
                                        ? 'Campo requerido'
                                        : null,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // KILOMETRAJE
                          // ==================================================

                          _tituloCampo(
                            'Kilometraje (KM)',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          LayoutBuilder(
                            builder:
                                (
                                  context,
                                  constraints,
                                ) {
                              final esMovil =
                                  constraints.maxWidth <
                                      600;

                              final campoKm =
                                  TextFormField(
                                controller:
                                    _kmController,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal:
                                      true,
                                ),
                                decoration:
                                    _inputDecoration(
                                  '0.0',
                                  Icons.speed,
                                ),
                                validator:
                                    (value) =>
                                        value == null ||
                                                value
                                                    .trim()
                                                    .isEmpty
                                            ? 'Campo requerido'
                                            : null,
                              );

                              final boton =
                                  SizedBox(
                                height: 46,
                                child:
                                    ElevatedButton
                                        .icon(
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        colorPrincipal,
                                    foregroundColor:
                                        Colors.white,
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        8,
                                      ),
                                    ),
                                  ),
                                  onPressed:
                                      () async {
                                    final resultadoKm =
                                        await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (
                                          context,
                                        ) =>
                                            const CalcularKmScreen(),
                                      ),
                                    );

                                    if (resultadoKm !=
                                        null) {
                                      setState(() {
                                        _kmController
                                                .text =
                                            resultadoKm
                                                .toString();
                                      });

                                      if (widget
                                              .onKilometrajeCalculado !=
                                          null) {
                                        widget
                                            .onKilometrajeCalculado!(
                                          resultadoKm
                                              .toString(),
                                        );
                                      }
                                    }
                                  },
                                  icon:
                                      const Icon(
                                    Icons.calculate,
                                    color:
                                        Colors.white,
                                    size: 18,
                                  ),
                                  label:
                                      const Text(
                                    'Calcular Kilometraje',
                                  ),
                                ),
                              );

                              if (esMovil) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .stretch,
                                  children: [
                                    campoKm,
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    boton,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child:
                                        campoKm,
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  Flexible(
                                    child:
                                        boton,
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // DESCRIPCIÓN
                          // ==================================================

                          _tituloCampo(
                            'Descripción',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          TextFormField(
                            controller:
                                _descripcionController,
                            maxLines: 3,
                            decoration:
                                _inputDecoration(
                              'Observaciones...',
                              Icons.description,
                            ),
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          // ==================================================
                          // GUARDAR
                          // ==================================================

                          SizedBox(
                            width:
                                double.infinity,
                            height: 48,
                            child:
                                ElevatedButton(
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    colorVerde,
                                foregroundColor:
                                    Colors.white,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    8,
                                  ),
                                ),
                              ),
                              onPressed:
                                  _guardando
                                      ? null
                                      : () async {
                                          if (!_formKey
                                              .currentState!
                                              .validate()) {
                                            return;
                                          }

                                          setState(() {
                                            _guardando =
                                                true;
                                          });

                                          try {
                                            // ==================================================
                                            // DATOS
                                            // ==================================================

                                            final datos =
                                                <String, dynamic>{
                                              'contratista':
                                                  _contratistaController
                                                      .text
                                                      .trim(),

                                              'subcontratista':
                                                  (
                                                _subcontratistaSeleccionado ??
                                                ''
                                              ).trim(),

                                              'actividad':
                                                  (
                                                _actividadSeleccionada ??
                                                ''
                                              ).trim(),

                                              'zafra':
                                                  _zafraController
                                                      .text
                                                      .trim(),

                                              'fecha':
                                                  _fechaController
                                                      .text
                                                      .trim(),

                                              'fincaLote':
                                                  (
                                                _fincaLoteSeleccionada ??
                                                ''
                                              ).trim(),

                                              'procedencia':
                                                  (
                                                _procedenciaSeleccionada ??
                                                ''
                                              ).trim(),

                                              'placa':
                                                  (
                                                _placaSeleccionada ??
                                                ''
                                              )
                                                      .toUpperCase()
                                                      .trim(),

                                              'transportista':
                                                  _transportistaController
                                                      .text
                                                      .trim(),

                                              'cantidadPersonas':
                                                  _cantidadPersonasController
                                                      .text
                                                      .trim(),

                                              'lineaRuta':
                                                  _lineaRutaController
                                                      .text
                                                      .trim(),

                                              'kilometraje':
                                                  _kmController
                                                      .text
                                                      .trim(),

                                              'descripcion':
                                                  _descripcionController
                                                      .text
                                                      .trim(),
                                            };

                                            final usuario =
                                                _usuarioParaGuardar();

                                            // ==================================================
                                            // NUEVO REGISTRO
                                            // ==================================================

                                            if (widget.docId ==
                                                    null ||
                                                widget.docId!
                                                    .trim()
                                                    .isEmpty) {
                                              datos[
                                                      'creadoPor'] =
                                                  usuario;

                                              datos[
                                                      'creadoPorUid'] =
                                                  _usuarioUid();

                                              datos[
                                                      'fechaCreacion'] =
                                                  FieldValue
                                                      .serverTimestamp();

                                              datos[
                                                      'timestamp'] =
                                                  FieldValue
                                                      .serverTimestamp();

                                              await FirebaseFirestore
                                                  .instance
                                                  .collection(
                                                    'registros_f066',
                                                  )
                                                  .add(
                                                datos,
                                              );
                                            }

                                            // ==================================================
                                            // EDITAR REGISTRO
                                            // ==================================================

                                            else {
                                              datos[
                                                      'editadoPor'] =
                                                  usuario;

                                              datos[
                                                      'editadoPorUid'] =
                                                  _usuarioUid();

                                              datos[
                                                      'fechaEdicion'] =
                                                  FieldValue
                                                      .serverTimestamp();

                                              datos[
                                                      'timestamp'] =
                                                  FieldValue
                                                      .serverTimestamp();

                                              await FirebaseFirestore
                                                  .instance
                                                  .collection(
                                                    'registros_f066',
                                                  )
                                                  .doc(
                                                    widget.docId,
                                                  )
                                                  .update(
                                                datos,
                                              );
                                            }

                                            if (!context
                                                .mounted) {
                                              return;
                                            }

                                            // ==================================================
                                            // LIMPIAR TODO
                                            // ==================================================

                                            _limpiarFormulario();

                                            ScaffoldMessenger
                                                .of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content:
                                                    Text(
                                                  widget.docId ==
                                                          null
                                                      ? '¡Registro F-066 guardado con éxito!'
                                                      : '¡Registro F-066 actualizado con éxito! El formulario está listo para un nuevo registro.',
                                                ),
                                                backgroundColor:
                                                    colorVerde,
                                              ),
                                            );
                                          } catch (e) {
                                            if (!context
                                                .mounted) {
                                              return;
                                            }

                                            ScaffoldMessenger
                                                .of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content:
                                                    Text(
                                                  'Error al guardar: $e',
                                                ),
                                                backgroundColor:
                                                    Colors.red,
                                              ),
                                            );
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _guardando =
                                                    false;
                                              });
                                            }
                                          }
                                        },
                              child: _guardando
                                  ? const SizedBox(
                                      width:
                                          20,
                                      height:
                                          20,
                                      child:
                                          CircularProgressIndicator(
                                        color:
                                            Colors.white,
                                        strokeWidth:
                                            2,
                                      ),
                                    )
                                  : const Text(
                                      'Guardar Registro',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            15,
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // TÍTULO DE CAMPO
  // ============================================================

  Widget _tituloCampo(
    String titulo,
  ) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
        fontWeight:
            FontWeight.bold,
      ),
    );
  }

  // ============================================================
  // AUTOCOMPLETE SUBCONTRATISTA
  // ============================================================

  Widget _autocompleteSubcontratista() {
    return Autocomplete<String>(
      optionsBuilder:
          (
            TextEditingValue
                textEditingValue,
          ) {
        if (textEditingValue
            .text
            .isEmpty) {
          return _listaNombresTransportistas;
        }

        return _listaNombresTransportistas
            .where(
          (item) =>
              item
                  .toLowerCase()
                  .contains(
                    textEditingValue
                        .text
                        .toLowerCase(),
                  ),
        );
      },
      onSelected:
          (String selection) {
        setState(() {
          _subcontratistaSeleccionado =
              selection;
        });
      },
      fieldViewBuilder:
          (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
        if (_subcontratistaSeleccionado !=
                null &&
            controller
                .text
                .isEmpty) {
          controller.text =
              _subcontratistaSeleccionado!;
        }

        return TextFormField(
          controller:
              controller,
          focusNode:
              focusNode,
          decoration:
              _inputDecoration(
            'Seleccione o busque subcontratista...',
            Icons.person_outline,
          ),
          onChanged:
              (val) {
            _subcontratistaSeleccionado =
                val;
          },
          validator:
              (value) =>
                  (
                        _subcontratistaSeleccionado ==
                                null ||
                            _subcontratistaSeleccionado!
                                .trim()
                                .isEmpty
                      ) &&
                      (
                        value ==
                                null ||
                            value
                                .trim()
                                .isEmpty
                      )
                  ? 'Campo requerido'
                  : null,
        );
      },
    );
  }

  // ============================================================
  // AUTOCOMPLETE ACTIVIDAD
  // ============================================================

  Widget _autocompleteActividad() {
    return Autocomplete<String>(
      optionsBuilder:
          (
            TextEditingValue
                textEditingValue,
          ) {
        if (textEditingValue
            .text
            .isEmpty) {
          return _listaActividades;
        }

        return _listaActividades
            .where(
          (item) =>
              item
                  .toLowerCase()
                  .contains(
                    textEditingValue
                        .text
                        .toLowerCase(),
                  ),
        );
      },
      onSelected:
          (String selection) {
        setState(() {
          _actividadSeleccionada =
              selection;
        });
      },
      fieldViewBuilder:
          (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
        if (_actividadSeleccionada !=
                null &&
            controller
                .text
                .isEmpty) {
          controller.text =
              _actividadSeleccionada!;
        }

        return TextFormField(
          controller:
              controller,
          focusNode:
              focusNode,
          decoration:
              _inputDecoration(
            'Seleccione o busque actividad...',
            Icons.work_outline,
          ),
          onChanged:
              (val) {
            _actividadSeleccionada =
                val;
          },
          validator:
              (value) =>
                  (
                        _actividadSeleccionada ==
                                null ||
                            _actividadSeleccionada!
                                .trim()
                                .isEmpty
                      ) &&
                      (
                        value ==
                                null ||
                            value
                                .trim()
                                .isEmpty
                      )
                  ? 'Campo requerido'
                  : null,
        );
      },
    );
  }

  // ============================================================
  // AUTOCOMPLETE FINCA / PROCEDENCIA
  // ============================================================

  Widget _autocompleteFinca({
    required bool esFinca,
  }) {
    return Autocomplete<String>(
      optionsBuilder:
          (
            TextEditingValue
                textEditingValue,
          ) {
        if (textEditingValue
            .text
            .isEmpty) {
          return _listaFincas;
        }

        return _listaFincas
            .where(
          (item) =>
              item
                  .toLowerCase()
                  .contains(
                    textEditingValue
                        .text
                        .toLowerCase(),
                  ),
        );
      },
      onSelected:
          (String selection) {
        setState(() {
          if (esFinca) {
            _fincaLoteSeleccionada =
                selection;
          } else {
            _procedenciaSeleccionada =
                selection;
          }
        });
      },
      fieldViewBuilder:
          (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
        final valorActual =
            esFinca
                ? _fincaLoteSeleccionada
                : _procedenciaSeleccionada;

        if (valorActual !=
                null &&
            controller
                .text
                .isEmpty) {
          controller.text =
              valorActual;
        }

        return TextFormField(
          controller:
              controller,
          focusNode:
              focusNode,
          decoration:
              _inputDecoration(
            esFinca
                ? 'Buscar finca...'
                : 'Buscar procedencia...',
            esFinca
                ? Icons.terrain
                : Icons.flag,
          ),
          onChanged:
              (val) {
            setState(() {
              if (esFinca) {
                _fincaLoteSeleccionada =
                    val;
              } else {
                _procedenciaSeleccionada =
                    val;
              }
            });
          },
          validator:
              (value) {
            final seleccionado =
                esFinca
                    ? _fincaLoteSeleccionada
                    : _procedenciaSeleccionada;

            if ((seleccionado ==
                        null ||
                    seleccionado
                        .trim()
                        .isEmpty) &&
                (value == null ||
                    value
                        .trim()
                        .isEmpty)) {
              return 'Campo requerido';
            }

            return null;
          },
        );
      },
    );
  }

  // ============================================================
  // AUTOCOMPLETE PLACA
  // ============================================================

  Widget _autocompletePlaca() {
    return Autocomplete<
        Map<String, dynamic>>(
      optionsBuilder:
          (
            TextEditingValue
                textEditingValue,
          ) {
        if (textEditingValue
            .text
            .isEmpty) {
          return _listaTransportistas;
        }

        return _listaTransportistas
            .where(
          (item) =>
              item['placa']!
                  .toLowerCase()
                  .contains(
                    textEditingValue
                        .text
                        .toLowerCase(),
                  ) ||
              item['nombre']!
                  .toLowerCase()
                  .contains(
                    textEditingValue
                        .text
                        .toLowerCase(),
                  ),
        );
      },
      displayStringForOption:
          (option) =>
              option['placa'] ??
              '',
      onSelected:
          (
            Map<String, dynamic>
                selection,
          ) {
        final placaEscogida =
            selection['placa'] ??
                '';

        final nombreTransportista =
            selection['nombre'] ??
                '';

        setState(() {
          _placaSeleccionada =
              placaEscogida;

          _transportistaController
                  .text =
              nombreTransportista;
        });
      },
      fieldViewBuilder:
          (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
        if (_placaSeleccionada !=
                null &&
            controller
                .text
                .isEmpty) {
          controller.text =
              _placaSeleccionada!;
        }

        return TextFormField(
          controller:
              controller,
          focusNode:
              focusNode,
          decoration:
              _inputDecoration(
            'Buscar placa...',
            Icons.directions_car,
          ),
          validator:
              (value) =>
                  (
                        _placaSeleccionada ==
                                null ||
                            _placaSeleccionada!
                                .trim()
                                .isEmpty
                      ) &&
                      (
                        value ==
                                null ||
                            value
                                .trim()
                                .isEmpty
                      )
                  ? 'Campo requerido'
                  : null,
          onChanged:
              (val) {
            _placaSeleccionada =
                val;

            final valUpper =
                val
                    .trim()
                    .toUpperCase();

            final match =
                _listaTransportistas
                    .firstWhere(
              (t) =>
                  t['placa'] ==
                          valUpper ||
                      t['placa']
                          .contains(
                        valUpper,
                      ),
              orElse: () =>
                  {},
            );

            setState(() {
              if (match
                  .isNotEmpty) {
                _transportistaController
                        .text =
                    match['nombre'] ??
                        '';
              } else {
                _transportistaController
                    .clear();
              }
            });
          },
        );
      },
    );
  }

  // ============================================================
  // DECORACIÓN DE CAMPOS
  // ============================================================

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,

      // Campo blanco
      filled: true,
      fillColor: Colors.white,

      prefixIcon: Icon(
        icon,
        color: colorVerde,
        size: 20,
      ),

      suffixIcon: suffix,

      // Borde normal
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        borderSide:
            const BorderSide(
          color:
              colorBorde,
        ),
      ),

      // Borde seleccionado
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        borderSide:
            const BorderSide(
          color:
              colorVerde,
          width: 1.5,
        ),
      ),

      // Borde de error
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        borderSide:
            const BorderSide(
          color:
              Colors.red,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        borderSide:
            const BorderSide(
          color:
              Colors.red,
          width: 1.5,
        ),
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 10,
      ),

      isDense: true,
    );
  }
}