import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'CalcularKm.dart';

class Formato066TransporteAguaScreen extends StatefulWidget {
  final ValueChanged<String>? onKilometrajeCalculado;
  final String? usuarioActual;
  final String? docId;
  final Map<String, dynamic>? datosIniciales;

  const Formato066TransporteAguaScreen({
    super.key,
    this.onKilometrajeCalculado,
    this.usuarioActual,
    this.docId,
    this.datosIniciales,
  });

  @override
  State<Formato066TransporteAguaScreen> createState() =>
      _Formato066TransporteAguaScreenState();
}

class _Formato066TransporteAguaScreenState
    extends State<Formato066TransporteAguaScreen> {
  // ============================================================
  // COLORES
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  // ============================================================
  // FORMULARIO
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _contratistaController =
      TextEditingController(text: 'ARAME');

  // ZAFRA INICIA EN BLANCO
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

  // ============================================================
  // SELECCIONES
  // ============================================================

  String? _actividadSeleccionada;
  String? _fincaLoteSeleccionada;
  String? _procedenciaSeleccionada;
  String? _placaSeleccionada;
  String? _subcontratistaSeleccionado;

  // ============================================================
  // LISTAS
  // ============================================================

  List<String> _listaActividades = [];
  List<String> _listaFincas = [];

  List<Map<String, dynamic>> _listaTransportistas = [];

  List<String> _listaNombresTransportistas = [];

  bool _cargandoDatos = true;
  bool _guardando = false;

  // ============================================================
  // SEMANA ACTUAL
  // DOMINGO -> SÁBADO
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

    final DateTime hoy = DateTime.now();

    _fechaController.text =
        '${hoy.day.toString().padLeft(2, '0')}/'
        '${hoy.month.toString().padLeft(2, '0')}/'
        '${hoy.year}';

    _cargarDatosFirebase();
  }

  // ============================================================
  // RANGO DE SEMANA
  // DOMINGO -> SÁBADO
  // ============================================================

  void _calcularRangoSemanaActual() {
    final DateTime ahora = DateTime.now();

    final int diasDesdeDomingo = ahora.weekday % 7;

    _inicioSemana = ahora.subtract(
      Duration(days: diasDesdeDomingo),
    );

    _inicioSemana = DateTime(
      _inicioSemana.year,
      _inicioSemana.month,
      _inicioSemana.day,
    );

    _finSemana = DateTime(
      _inicioSemana.year,
      _inicioSemana.month,
      _inicioSemana.day,
      23,
      59,
      59,
    ).add(
      const Duration(days: 6),
    );
  }

  // ============================================================
  // CARGAR DATOS FIREBASE
  // ============================================================

  Future<void> _cargarDatosFirebase() async {
    try {
      // ----------------------------------------------------------
      // ACTIVIDADES
      // ----------------------------------------------------------

      final QuerySnapshot actSnap = await FirebaseFirestore.instance
          .collection('actividad_labor')
          .get();

      final List<String> actList = actSnap.docs
          .map((doc) {
            final Map<String, dynamic> data =
                doc.data() as Map<String, dynamic>? ?? {};

            final dynamic nombreActividad =
                data['actividad'] ??
                data['nombre'] ??
                data['descripcion'] ??
                data['nombreActividad'];

            return nombreActividad?.toString().trim() ?? '';
          })
          .where(
            (element) =>
                element.isNotEmpty &&
                !element.startsWith('3jkHQTIS') &&
                element.length > 3,
          )
          .toList();

      // ----------------------------------------------------------
      // FINCAS
      // ----------------------------------------------------------

      final QuerySnapshot fincaSnap = await FirebaseFirestore.instance
          .collection('fincas')
          .get();

      final List<String> fincaList = fincaSnap.docs
          .map((doc) {
            final Map<String, dynamic> data =
                doc.data() as Map<String, dynamic>? ?? {};

            return (
              data['nombre'] ??
              data['finca'] ??
              data['descripcion'] ??
              ''
            ).toString().trim();
          })
          .where(
            (element) => element.isNotEmpty,
          )
          .toList();

      // ----------------------------------------------------------
      // TRANSPORTISTAS
      // ----------------------------------------------------------

      final QuerySnapshot transpSnap = await FirebaseFirestore.instance
          .collection('transportistas')
          .get();

      final List<Map<String, dynamic>> transpList = transpSnap.docs
          .map((doc) {
            final Map<String, dynamic> data =
                doc.data() as Map<String, dynamic>? ?? {};

            return {
              'placa': (
                data['placa'] ??
                data['Placa'] ??
                ''
              ).toString().toUpperCase().trim(),

              'nombre': (
                data['nombreTransportista'] ??
                data['transportista'] ??
                data['nombre'] ??
                data['chofer'] ??
                ''
              ).toString().trim(),
            };
          })
          .where(
            (item) => item['placa'] != '',
          )
          .toList();

      final List<String> nombresList = transpList
          .map(
            (t) => t['nombre'] as String,
          )
          .where(
            (nombre) => nombre.isNotEmpty,
          )
          .toSet()
          .toList();

      if (!mounted) return;

      setState(() {
        _listaActividades = actList;
        _listaFincas = fincaList;
        _listaTransportistas = transpList;
        _listaNombresTransportistas = nombresList;
        _cargandoDatos = false;
      });

      _cargarDatosIniciales();
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
  // CARGAR DATOS PARA EDICIÓN
  // ============================================================

  void _cargarDatosIniciales() {
    final Map<String, dynamic> datos =
        widget.datosIniciales ?? <String, dynamic>{};

    if (datos.isEmpty) return;

    String texto(dynamic valor) {
      return valor?.toString() ?? '';
    }

    String? textoNulo(dynamic valor) {
      final String v = texto(valor).trim();

      return v.isEmpty ? null : v;
    }

    _contratistaController.text =
        texto(datos['contratista']);

    _zafraController.text =
        texto(datos['zafra']);

    _fechaController.text =
        texto(datos['fecha']);

    _transportistaController.text =
        texto(datos['transportista']);

    _lineaRutaController.text =
        texto(datos['lineaRuta']);

    _kmController.text =
        texto(datos['kilometraje']);

    _descripcionController.text =
        texto(datos['descripcion']);

    _actividadSeleccionada =
        textoNulo(datos['actividad']);

    _fincaLoteSeleccionada =
        textoNulo(datos['fincaLote']);

    _procedenciaSeleccionada =
        textoNulo(datos['procedencia']);

    _placaSeleccionada =
        textoNulo(datos['placa'])?.toUpperCase();

    _subcontratistaSeleccionado =
        textoNulo(datos['subcontratista']);

    if (_placaSeleccionada != null &&
        _transportistaController.text.trim().isEmpty) {
      final Map<String, dynamic> match =
          _listaTransportistas.firstWhere(
        (Map<String, dynamic> item) =>
            (item['placa'] ?? '')
                .toString()
                .toUpperCase() ==
            _placaSeleccionada,
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty) {
        _transportistaController.text =
            (match['nombre'] ?? '').toString();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // USUARIO ACTUAL
  // ============================================================

  String _obtenerUsuarioActual() {
    final String? externo =
        widget.usuarioActual?.trim();

    if (externo != null && externo.isNotEmpty) {
      return externo;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return 'Desconocido';
    }

    final String? nombre =
        user.displayName?.trim();

    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }

    final String? email =
        user.email?.trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return user.uid;
  }

  String? _usuarioUid() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // ============================================================
  // LIMPIAR FORMULARIO
  // ============================================================

  void _limpiarFormulario() {
    _contratistaController.clear();
    _zafraController.clear();
    _transportistaController.clear();
    _lineaRutaController.clear();
    _kmController.clear();
    _descripcionController.clear();

    _actividadSeleccionada = null;
    _fincaLoteSeleccionada = null;
    _procedenciaSeleccionada = null;
    _placaSeleccionada = null;
    _subcontratistaSeleccionado = null;

    // Mantener fecha actual
    final DateTime hoy = DateTime.now();

    _fechaController.text =
        '${hoy.day.toString().padLeft(2, '0')}/'
        '${hoy.month.toString().padLeft(2, '0')}/'
        '${hoy.year}';

    _formKey.currentState?.reset();

    if (mounted) {
      setState(() {});
    }
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

    super.dispose();
  }

  // ============================================================
  // SELECCIONAR FECHA
  // ============================================================

  Future<void> _seleccionarFecha(
    BuildContext context,
  ) async {
    _calcularRangoSemanaActual();

    DateTime hoy = DateTime.now();

    DateTime initialDateToUse = hoy;

    if (initialDateToUse.isBefore(_inicioSemana)) {
      initialDateToUse = _inicioSemana;
    } else if (initialDateToUse.isAfter(_finSemana)) {
      initialDateToUse = _finSemana;
    }

    final DateTime? fechaSeleccionada =
        await showDatePicker(
      context: context,
      initialDate: initialDateToUse,
      firstDate: _inicioSemana,
      lastDate: _finSemana,
      helpText:
          'Seleccione fecha de la semana actual',
    );

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaController.text =
            '${fechaSeleccionada.day.toString().padLeft(2, '0')}/'
            '${fechaSeleccionada.month.toString().padLeft(2, '0')}/'
            '${fechaSeleccionada.year}';
      });
    }
  }

  // ============================================================
  // DECORACIÓN CAMPOS
  // ============================================================

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,

      prefixIcon: Icon(
        icon,
        color: colorPrincipal,
      ),

      suffixIcon: suffix,

      filled: true,
      fillColor: Colors.white,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: colorBorde,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: colorBorde,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: colorVerde,
          width: 2,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
    );
  }

  // ============================================================
  // TITULO DE SECCIÓN
  // ============================================================

  Widget _tituloCampo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ============================================================
  // AUTOCOMPLETE SUBCONTRATISTA
  // ============================================================

  Widget _campoSubcontratista() {
    return Autocomplete<String>(
      optionsBuilder:
          (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _listaNombresTransportistas;
        }

        return _listaNombresTransportistas.where(
          (item) => item
              .toLowerCase()
              .contains(
                textEditingValue.text.toLowerCase(),
              ),
        );
      },

      onSelected: (String selection) {
        setState(() {
          _subcontratistaSeleccionado =
              selection;
        });
      },

      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        if (_subcontratistaSeleccionado != null &&
            controller.text.isEmpty) {
          controller.text =
              _subcontratistaSeleccionado!;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,

          decoration: _inputDecoration(
            'Seleccione o busque subcontratista...',
            Icons.person_outline,
          ),

          onChanged: (val) {
            _subcontratistaSeleccionado = val;
          },

          validator: (value) {
            if ((_subcontratistaSeleccionado ==
                        null ||
                    _subcontratistaSeleccionado!
                        .trim()
                        .isEmpty) &&
                (value == null ||
                    value.trim().isEmpty)) {
              return 'Campo requerido';
            }

            return null;
          },
        );
      },
    );
  }

  // ============================================================
  // AUTOCOMPLETE ACTIVIDAD
  // ============================================================

  Widget _campoActividad() {
    return Autocomplete<String>(
      optionsBuilder:
          (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _listaActividades;
        }

        return _listaActividades.where(
          (item) => item
              .toLowerCase()
              .contains(
                textEditingValue.text.toLowerCase(),
              ),
        );
      },

      onSelected: (String selection) {
        setState(() {
          _actividadSeleccionada =
              selection;
        });
      },

      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        if (_actividadSeleccionada != null &&
            controller.text.isEmpty) {
          controller.text =
              _actividadSeleccionada!;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,

          decoration: _inputDecoration(
            'Seleccione o busque actividad...',
            Icons.work_outline,
          ),

          onChanged: (val) {
            _actividadSeleccionada = val;
          },

          validator: (value) {
            if ((_actividadSeleccionada ==
                        null ||
                    _actividadSeleccionada!
                        .trim()
                        .isEmpty) &&
                (value == null ||
                    value.trim().isEmpty)) {
              return 'Campo requerido';
            }

            return null;
          },
        );
      },
    );
  }

  // ============================================================
  // AUTOCOMPLETE FINCA
  // ============================================================

  Widget _campoFinca() {
    return Autocomplete<String>(
      optionsBuilder:
          (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _listaFincas;
        }

        return _listaFincas.where(
          (item) => item
              .toLowerCase()
              .contains(
                textEditingValue.text.toLowerCase(),
              ),
        );
      },

      onSelected: (String selection) {
        setState(() {
          _fincaLoteSeleccionada =
              selection;
        });
      },

      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        if (_fincaLoteSeleccionada != null &&
            controller.text.isEmpty) {
          controller.text =
              _fincaLoteSeleccionada!;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,

          decoration: _inputDecoration(
            'Buscar finca...',
            Icons.terrain,
          ),

          onChanged: (val) {
            _fincaLoteSeleccionada = val;
          },

          validator: (value) {
            if ((_fincaLoteSeleccionada ==
                        null ||
                    _fincaLoteSeleccionada!
                        .trim()
                        .isEmpty) &&
                (value == null ||
                    value.trim().isEmpty)) {
              return 'Campo requerido';
            }

            return null;
          },
        );
      },
    );
  }

  // ============================================================
  // AUTOCOMPLETE PROCEDENCIA
  // ============================================================

  Widget _campoProcedencia() {
    return Autocomplete<String>(
      optionsBuilder:
          (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _listaFincas;
        }

        return _listaFincas.where(
          (item) => item
              .toLowerCase()
              .contains(
                textEditingValue.text.toLowerCase(),
              ),
        );
      },

      onSelected: (String selection) {
        setState(() {
          _procedenciaSeleccionada =
              selection;
        });
      },

      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        if (_procedenciaSeleccionada != null &&
            controller.text.isEmpty) {
          controller.text =
              _procedenciaSeleccionada!;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,

          decoration: _inputDecoration(
            'Buscar procedencia...',
            Icons.flag,
          ),

          onChanged: (val) {
            _procedenciaSeleccionada = val;
          },

          validator: (value) {
            if ((_procedenciaSeleccionada ==
                        null ||
                    _procedenciaSeleccionada!
                        .trim()
                        .isEmpty) &&
                (value == null ||
                    value.trim().isEmpty)) {
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

  Widget _campoPlaca() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder:
          (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _listaTransportistas;
        }

        return _listaTransportistas.where(
          (item) {
            final String placa =
                (item['placa'] ?? '')
                    .toString()
                    .toLowerCase();

            final String nombre =
                (item['nombre'] ?? '')
                    .toString()
                    .toLowerCase();

            final String busqueda =
                textEditingValue.text.toLowerCase();

            return placa.contains(busqueda) ||
                nombre.contains(busqueda);
          },
        );
      },

      displayStringForOption:
          (option) =>
              option['placa'] ?? '',

      onSelected:
          (Map<String, dynamic> selection) {
        final String placaEscogida =
            selection['placa'] ?? '';

        final String nombreTransportista =
            selection['nombre'] ?? '';

        setState(() {
          _placaSeleccionada =
              placaEscogida;

          _transportistaController.text =
              nombreTransportista;
        });
      },

      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        if (_placaSeleccionada != null &&
            controller.text.isEmpty) {
          controller.text =
              _placaSeleccionada!;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,

          decoration: _inputDecoration(
            'Buscar placa...',
            Icons.directions_car,
          ),

          validator: (value) {
            if ((_placaSeleccionada ==
                        null ||
                    _placaSeleccionada!
                        .trim()
                        .isEmpty) &&
                (value == null ||
                    value.trim().isEmpty)) {
              return 'Campo requerido';
            }

            return null;
          },

          onChanged: (val) {
            _placaSeleccionada = val;

            final String valUpper =
                val.trim().toUpperCase();

            final Map<String, dynamic> match =
                _listaTransportistas.firstWhere(
              (t) {
                final String placa =
                    (t['placa'] ?? '')
                        .toString();

                return placa == valUpper ||
                    placa.contains(valUpper);
              },
              orElse: () =>
                  <String, dynamic>{},
            );

            if (match.isNotEmpty) {
              _transportistaController.text =
                  match['nombre'] ?? '';
            } else {
              _transportistaController.clear();
            }

            setState(() {});
          },
        );
      },
    );
  }

  // ============================================================
  // GUARDAR
  // ============================================================

  Future<void> _guardarRegistro() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final Map<String, dynamic> datosGuardar = {
        'contratista':
            _contratistaController.text.trim(),

        'subcontratista':
            (_subcontratistaSeleccionado ?? '')
                .trim(),

        'actividad':
            (_actividadSeleccionada ?? '')
                .trim(),

        'zafra':
            _zafraController.text.trim(),

        'fecha':
            _fechaController.text.trim(),

        'fincaLote':
            (_fincaLoteSeleccionada ?? '')
                .trim(),

        'procedencia':
            (_procedenciaSeleccionada ?? '')
                .trim(),

        'placa':
            (_placaSeleccionada ?? '')
                .toUpperCase()
                .trim(),

        'transportista':
            _transportistaController.text.trim(),

        'lineaRuta':
            _lineaRutaController.text.trim(),

        'kilometraje':
            _kmController.text.trim(),

        'descripcion':
            _descripcionController.text.trim(),

        'timestamp':
            FieldValue.serverTimestamp(),
      };

      final String usuarioFinal =
          _obtenerUsuarioActual();

      final bool esNuevo =
          widget.docId == null ||
          widget.docId!.trim().isEmpty;

      // ========================================================
      // NUEVO REGISTRO
      // ========================================================

      if (esNuevo) {
        datosGuardar['creadoPor'] =
            usuarioFinal;

        datosGuardar['creadoPorUid'] =
            _usuarioUid();

        datosGuardar['fechaCreacion'] =
            FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('registros_f066')
            .add(datosGuardar);
      }

      // ========================================================
      // EDITAR REGISTRO
      // ========================================================

      else {
        datosGuardar['editadoPor'] =
            usuarioFinal;

        datosGuardar['editadoPorUid'] =
            _usuarioUid();

        datosGuardar['fechaEdicion'] =
            FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('registros_f066')
            .doc(widget.docId)
            .update(datosGuardar);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            esNuevo
                ? '¡Registro de ruta de agua guardado con éxito!'
                : '¡Registro de ruta de agua actualizado con éxito!',
          ),
          backgroundColor: colorVerde,
        ),
      );

      // ========================================================
      // LIMPIAR FORMULARIO SOLO AL CREAR
      // ========================================================

      if (esNuevo) {
        _limpiarFormulario();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return Scaffold(
        backgroundColor: colorFondo,

        appBar: AppBar(
          title: const Text(
            'Transporte de Agua - Ruta',
          ),
          backgroundColor: colorPrincipal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        body: const Center(
          child: CircularProgressIndicator(
            color: colorVerde,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorFondo,

      appBar: AppBar(
        title: const Text(
          'Transporte de Agua - Ruta',
        ),
        backgroundColor: colorPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final bool pantallaPequena =
              constraints.maxWidth < 650;

          return SingleChildScrollView(
            padding: EdgeInsets.all(
              pantallaPequena ? 10 : 20,
            ),

            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                ),

                child: Card(
                  elevation: 0,
                  color: Colors.white,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),

                    side: const BorderSide(
                      color: colorBorde,
                    ),
                  ),

                  child: Padding(
                    padding: EdgeInsets.all(
                      pantallaPequena ? 16 : 24,
                    ),

                    child: Form(
                      key: _formKey,

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          // ==================================================
                          // TITULO
                          // ==================================================

                          const Text(
                            'Registro de Ruta de Transporte de Agua',
                            style: TextStyle(
                              color: colorVerde,
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),

                          const SizedBox(height: 5),

                          const Text(
                            'Nota: Solo se permiten registros correspondientes a la semana en curso.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),

                          const Divider(
                            height: 28,
                          ),

                          // ==================================================
                          // CONTRATISTA
                          // ==================================================

                          _tituloCampo(
                            'Contratista',
                          ),

                          const SizedBox(height: 5),

                          TextFormField(
                            controller:
                                _contratistaController,

                            decoration:
                                _inputDecoration(
                              'Ingrese contratista',
                              Icons.business,
                            ),

                            validator:
                                (value) {
                              if (value == null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Campo requerido';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // SUBCONTRATISTA
                          // ==================================================

                          _tituloCampo(
                            'Nombre del Subcontratista',
                          ),

                          const SizedBox(height: 5),

                          _campoSubcontratista(),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // ACTIVIDAD
                          // ==================================================

                          _tituloCampo(
                            'Actividad',
                          ),

                          const SizedBox(height: 5),

                          _campoActividad(),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // ZAFRA
                          // ==================================================

                          _tituloCampo(
                            'Zafra',
                          ),

                          const SizedBox(height: 5),

                          TextFormField(
                            controller:
                                _zafraController,

                            decoration:
                                _inputDecoration(
                              'Ingrese zafra',
                              Icons
                                  .calendar_view_month,
                            ),

                            validator:
                                (value) {
                              if (value == null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Campo requerido';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // FECHA
                          // ==================================================

                          _tituloCampo(
                            'Fecha (Semana Actual)',
                          ),

                          const SizedBox(height: 5),

                          TextFormField(
                            controller:
                                _fechaController,

                            readOnly: true,

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
                                Icons
                                    .arrow_drop_down,
                                color:
                                    Colors.grey,
                              ),
                            ),

                            validator:
                                (value) {
                              if (value == null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Campo requerido';
                              }

                              try {
                                final List<String>
                                    partes =
                                    value.split('/');

                                final DateTime
                                    fechaVal =
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

                                final DateTime inicio =
                                    DateTime(
                                  _inicioSemana
                                      .year,
                                  _inicioSemana
                                      .month,
                                  _inicioSemana
                                      .day,
                                );

                                final DateTime fin =
                                    DateTime(
                                  _finSemana.year,
                                  _finSemana.month,
                                  _finSemana.day,
                                );

                                if (fechaVal
                                        .isBefore(
                                      inicio,
                                    ) ||
                                    fechaVal
                                        .isAfter(
                                      fin,
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
                            height: 14,
                          ),

                          // ==================================================
                          // FINCA / PROCEDENCIA
                          // RESPONSIVE
                          // ==================================================

                          if (pantallaPequena)
                            Column(
                              children: [
                                _tituloCampo(
                                  'Finca / Lote',
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                _campoFinca(),

                                const SizedBox(
                                  height: 14,
                                ),

                                _tituloCampo(
                                  'Procedencia',
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                _campoProcedencia(),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [
                                      _tituloCampo(
                                        'Finca / Lote',
                                      ),

                                      const SizedBox(
                                        height: 5,
                                      ),

                                      _campoFinca(),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [
                                      _tituloCampo(
                                        'Procedencia',
                                      ),

                                      const SizedBox(
                                        height: 5,
                                      ),

                                      _campoProcedencia(),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // PLACA
                          // ==================================================

                          _tituloCampo(
                            'Placa',
                          ),

                          const SizedBox(height: 5),

                          _campoPlaca(),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // TRANSPORTISTA
                          // ==================================================

                          _tituloCampo(
                            'Transportista',
                          ),

                          const SizedBox(height: 5),

                          TextFormField(
                            controller:
                                _transportistaController,

                            readOnly: true,

                            decoration:
                                _inputDecoration(
                              'Transportista vinculado',
                              Icons.local_shipping,
                            ),

                            validator:
                                (value) {
                              if (value == null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Campo requerido';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // LINEA DE RUTA
                          // ==================================================

                          _tituloCampo(
                            'Línea de Ruta',
                          ),

                          const SizedBox(height: 5),

                          TextFormField(
                            controller:
                                _lineaRutaController,

                            decoration:
                                _inputDecoration(
                              'Detalle de ruta',
                              Icons.alt_route,
                            ),

                            validator:
                                (value) {
                              if (value == null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Campo requerido';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // KILOMETRAJE
                          // ==================================================

                          _tituloCampo(
                            'Kilometraje (KM)',
                          ),

                          const SizedBox(height: 5),

                          if (pantallaPequena)
                            Column(
                              children: [
                                TextFormField(
                                  controller:
                                      _kmController,

                                  keyboardType:
                                      const TextInputType
                                          .numberWithOptions(
                                    decimal: true,
                                  ),

                                  decoration:
                                      _inputDecoration(
                                    '0.0',
                                    Icons.speed,
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

                                    return null;
                                  },
                                ),

                                const SizedBox(
                                  height: 10,
                                ),

                                SizedBox(
                                  width:
                                      double.infinity,
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
                                          10,
                                        ),
                                      ),
                                    ),

                                    onPressed:
                                        () async {
                                      final resultadoKm =
                                          await Navigator
                                              .push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
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

                                        widget
                                            .onKilometrajeCalculado
                                            ?.call(
                                          resultadoKm
                                              .toString(),
                                        );
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
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                Expanded(
                                  child:
                                      TextFormField(
                                    controller:
                                        _kmController,

                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                      decimal: true,
                                    ),

                                    decoration:
                                        _inputDecoration(
                                      '0.0',
                                      Icons.speed,
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

                                      return null;
                                    },
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                SizedBox(
                                  height: 56,

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

                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 18,
                                      ),

                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          10,
                                        ),
                                      ),
                                    ),

                                    onPressed:
                                        () async {
                                      final resultadoKm =
                                          await Navigator
                                              .push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
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

                                        widget
                                            .onKilometrajeCalculado
                                            ?.call(
                                          resultadoKm
                                              .toString(),
                                        );
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
                                ),
                              ],
                            ),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // DESCRIPCIÓN
                          // ==================================================

                          _tituloCampo(
                            'Descripción',
                          ),

                          const SizedBox(height: 5),

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
                            height: 26,
                          ),

                          // ==================================================
                          // GUARDAR
                          // ==================================================

                          SizedBox(
                            width: double.infinity,
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

                                elevation: 0,

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),
                              ),

                              onPressed:
                                  _guardando
                                      ? null
                                      : _guardarRegistro,

                              child: _guardando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child:
                                          CircularProgressIndicator(
                                        color:
                                            Colors.white,
                                        strokeWidth:
                                            2,
                                      ),
                                    )
                                  : Text(
                                      widget.docId ==
                                              null
                                          ? 'Guardar Registro'
                                          : 'Actualizar Registro',

                                      style:
                                          const TextStyle(
                                        fontSize: 16,
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
}