import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class CalcularKmScreen extends StatefulWidget {
  final bool seleccionarRuta;

  const CalcularKmScreen({
    super.key,
    this.seleccionarRuta = false,
  });

  @override
  State<CalcularKmScreen> createState() =>
      _CalcularKmScreenState();
}

class _CalcularKmScreenState
    extends State<CalcularKmScreen> {

  // ============================================================
  // COLORES ZAFI
  // ============================================================

  static const Color colorPrincipal =
      Color(0xFF0F1E36);

  static const Color colorVerde =
      Color(0xFF2E7D32);

  static const Color colorFondo =
      Color(0xFFEEF2F6);

  static const Color colorBorde =
      Color(0xFFD5DCE5);

  static const Color colorVerdeSuave =
      Color(0xFFEAF4EC);

  // ============================================================
  // CONTROLADORES
  // ============================================================

  final MapController _mapController =
      MapController();

  final TextEditingController _kmTotalesController =
      TextEditingController(text: '0.00 km');

  // ============================================================
  // DATOS
  // ============================================================

  final List<PuntoRutaItem> _puntosRuta = [];

  List<LatLng> _puntosRutaCarretera = [];

  List<Map<String, dynamic>> _fincasFirebase = [];

  bool _cargandoFincas = true;

  bool _calculandoKm = false;

  bool _mostrarNombresFincasEnMapa = true;

  double _zoomActual = 11.0;

  // ============================================================
  // MODO DE RUTA
  // ============================================================

  // true = automática por carretera
  // false = manual dibujada por el usuario
  bool _modoAutomatico = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _cargarFincasDesdeFirebase();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    for (final punto in _puntosRuta) {
      punto.controller.dispose();
    }

    _kmTotalesController.dispose();

    super.dispose();
  }

  // ============================================================
  // CARGAR FINCAS
  // ============================================================

  Future<void> _cargarFincasDesdeFirebase() async {

    if (mounted) {
      setState(() {
        _cargandoFincas = true;
      });
    }

    try {

      final snapshot =
          await FirebaseFirestore.instance
              .collection('fincas')
              .get();

      final List<Map<String, dynamic>>
          tempFincas = [];

      for (final doc in snapshot.docs) {

        final data = doc.data();

        // --------------------------------------------------------
        // NOMBRE
        // --------------------------------------------------------

        final String nombreFinca =
            data['nombre'] ??
            data['name'] ??
            data['title'] ??
            data['finca'] ??
            'Finca sin nombre';

        // --------------------------------------------------------
        // LATITUD
        // --------------------------------------------------------

        double? lat;

        final rawLat =
            data['lat'] ??
            data['latitude'] ??
            data['latitud'];

        if (rawLat is num) {

          lat = rawLat.toDouble();

        } else if (rawLat is String) {

          lat = double.tryParse(rawLat);
        }

        // --------------------------------------------------------
        // LONGITUD
        // --------------------------------------------------------

        double? lng;

        final rawLng =
            data['lng'] ??
            data['longitude'] ??
            data['longitud'] ??
            data['lon'];

        if (rawLng is num) {

          lng = rawLng.toDouble();

        } else if (rawLng is String) {

          lng = double.tryParse(rawLng);
        }

        // --------------------------------------------------------
        // GUARDAR
        // --------------------------------------------------------

        if (lat != null && lng != null) {

          tempFincas.add({
            'id': doc.id,
            'nombre': nombreFinca,
            'latLng': LatLng(lat, lng),
            'tipo': data['tipo'] ??
                'Finca / Lote',
          });
        }
      }

      if (!mounted) return;

      setState(() {

        _fincasFirebase =
            tempFincas;

        _cargandoFincas =
            false;
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        _cargandoFincas = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar las fincas: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CAMBIAR MODO
  // ============================================================

  void _cambiarModo(bool automatico) {

    if (_modoAutomatico == automatico) {
      return;
    }

    setState(() {

      _modoAutomatico =
          automatico;

      // Al cambiar de modo empezamos
      // con el mismo recorrido actual,
      // pero recalculamos correctamente.

      _puntosRutaCarretera = [];
    });

    if (_puntosRuta.length >= 2) {

      if (_modoAutomatico) {

        _calcularRutaYDistanciaOSRM();

      } else {

        _calcularDistanciaRutaManual();
      }
    }
  }

  // ============================================================
  // AGREGAR PUNTO DESDE MAPA
  // ============================================================

  Future<void> _agregarPuntoEnMapa(
    LatLng punto,
  ) async {

    // ==========================================================
    // MODO MANUAL
    // ==========================================================

    if (!_modoAutomatico) {

      final nombre =
          'Punto ${_puntosRuta.length + 1}';

      setState(() {

        _puntosRuta.add(
          PuntoRutaItem(
            controller:
                TextEditingController(
              text: nombre,
            ),
            nombre: nombre,
            latLng: punto,
          ),
        );

        // MUY IMPORTANTE:
        // En modo manual la línea es exactamente
        // la que dibuja el usuario.

        _puntosRutaCarretera =
            _puntosRuta
                .where(
                  (p) => p.latLng != null,
                )
                .map(
                  (p) => p.latLng!,
                )
                .toList();
      });

      _calcularDistanciaRutaManual();

      return;
    }

    // ==========================================================
    // MODO AUTOMÁTICO
    // ==========================================================

    String nombreLugar =
        'Punto (${punto.latitude.toStringAsFixed(4)}, '
        '${punto.longitude.toStringAsFixed(4)})';

    try {

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/'
        'reverse'
        '?lat=${punto.latitude}'
        '&lon=${punto.longitude}'
        '&format=json',
      );

      final response =
          await http.get(
        url,
        headers: {
          'User-Agent':
              'ZAFI-Field-Management-System',
        },
      );

      if (response.statusCode == 200) {

        final data =
            json.decode(response.body);

        String displayName =
            data['display_name'] ?? '';

        if (displayName.contains(',')) {

          displayName =
              displayName
                  .split(',')
                  .take(2)
                  .join(',');
        }

        if (displayName.isNotEmpty) {
          nombreLugar =
              displayName;
        }
      }

    } catch (_) {
      // Si no hay conexión,
      // usamos las coordenadas.
    }

    if (!mounted) return;

    setState(() {

      _puntosRuta.add(
        PuntoRutaItem(
          controller:
              TextEditingController(
            text: nombreLugar,
          ),
          nombre: nombreLugar,
          latLng: punto,
        ),
      );
    });

    _calcularRutaYDistanciaOSRM();
  }

  // ============================================================
  // CALCULAR RUTA AUTOMÁTICA
  // ============================================================

  Future<void>
      _calcularRutaYDistanciaOSRM() async {

    final puntosValidos =
        _puntosRuta
            .where(
              (p) => p.latLng != null,
            )
            .toList();

    // ----------------------------------------------------------
    // MENOS DE 2 PUNTOS
    // ----------------------------------------------------------

    if (puntosValidos.length < 2) {

      if (!mounted) return;

      setState(() {

        _kmTotalesController.text =
            '0.00 km';

        _puntosRutaCarretera = [];

        _calculandoKm = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {

      _calculandoKm = true;

      _kmTotalesController.text =
          'Calculando...';

      _puntosRutaCarretera = [];
    });

    try {

      // --------------------------------------------------------
      // COORDENADAS
      // --------------------------------------------------------

      final coordenadas =
          puntosValidos.map(
        (p) =>
            '${p.latLng!.longitude},'
            '${p.latLng!.latitude}',
      ).toList();

      final coordinatesQuery =
          coordenadas.join(';');

      // --------------------------------------------------------
      // OSRM
      // --------------------------------------------------------

      final url = Uri.parse(
        'https://router.project-osrm.org/'
        'route/v1/driving/'
        '$coordinatesQuery'
        '?overview=full'
        '&geometries=geojson'
        '&steps=true',
      );

      final response =
          await http.get(url);

      if (response.statusCode == 200) {

        final data =
            json.decode(response.body);

        final routes =
            data['routes'] as List?;

        if (routes != null &&
            routes.isNotEmpty) {

          final route =
              routes.first;

          final double distanciaMetros =
              (route['distance'] as num)
                  .toDouble();

          final double distanciaKm =
              distanciaMetros / 1000.0;

          final geometry =
              route['geometry'];

          final coordsList =
              geometry['coordinates']
                  as List;

          final List<LatLng>
              loadedPoints =
              coordsList.map(
            (coord) {

              return LatLng(
                (coord[1] as num)
                    .toDouble(),
                (coord[0] as num)
                    .toDouble(),
              );
            },
          ).toList();

          if (!mounted) return;

          setState(() {

            _puntosRutaCarretera =
                loadedPoints;

            _kmTotalesController.text =
                '${distanciaKm.toStringAsFixed(2)} km';

            _calculandoKm = false;
          });

          return;
        }
      }

      // --------------------------------------------------------
      // FALLBACK
      // --------------------------------------------------------

      _calcularDistanciaPorPuntos();

    } catch (e) {

      _calcularDistanciaPorPuntos();
    }
  }

  // ============================================================
  // DISTANCIA MANUAL
  // ============================================================

  void _calcularDistanciaRutaManual() {

    final puntos =
        _puntosRuta
            .where(
              (p) => p.latLng != null,
            )
            .map(
              (p) => p.latLng!,
            )
            .toList();

    if (puntos.length < 2) {

      if (!mounted) return;

      setState(() {

        _kmTotalesController.text =
            '0.00 km';

        _puntosRutaCarretera =
            puntos;
      });

      return;
    }

    double distanciaTotal =
        0.0;

    for (
      int i = 0;
      i < puntos.length - 1;
      i++
    ) {

      final p1 =
          puntos[i];

      final p2 =
          puntos[i + 1];

      distanciaTotal +=
          _calcularDistanciaHaversine(
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );
    }

    if (!mounted) return;

    setState(() {

      // ========================================================
      // ESTA ES LA CLAVE:
      //
      // En manual NO llamamos OSRM.
      // La línea es exactamente la que
      // marcó el usuario.
      // ========================================================

      _puntosRutaCarretera =
          puntos;

      _kmTotalesController.text =
          '${distanciaTotal.toStringAsFixed(2)} km';

      _calculandoKm = false;
    });
  }

  // ============================================================
  // FALLBACK DISTANCIA ENTRE PUNTOS
  // ============================================================

  void _calcularDistanciaPorPuntos() {

    final puntos =
        _puntosRuta
            .where(
              (p) => p.latLng != null,
            )
            .map(
              (p) => p.latLng!,
            )
            .toList();

    double distanciaTotal =
        0.0;

    for (
      int i = 0;
      i < puntos.length - 1;
      i++
    ) {

      distanciaTotal +=
          _calcularDistanciaHaversine(
        puntos[i].latitude,
        puntos[i].longitude,
        puntos[i + 1].latitude,
        puntos[i + 1].longitude,
      );
    }

    if (!mounted) return;

    setState(() {

      _kmTotalesController.text =
          '${distanciaTotal.toStringAsFixed(2)} km';

      _puntosRutaCarretera = [];

      _calculandoKm = false;
    });
  }

  // ============================================================
  // HAVERSINE
  // ============================================================

  double _calcularDistanciaHaversine(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {

    const double radioTierraKm =
        6371.0;

    final double dLat =
        _degToRad(
      lat2 - lat1,
    );

    final double dLon =
        _degToRad(
      lon2 - lon1,
    );

    final double a =
        sin(dLat / 2) *
            sin(dLat / 2) +
        cos(
              _degToRad(lat1),
            ) *
            cos(
              _degToRad(lat2),
            ) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c =
        2 *
            atan2(
              sqrt(a),
              sqrt(1 - a),
            );

    return radioTierraKm * c;
  }

  double _degToRad(
    double deg,
  ) {
    return deg *
        (pi / 180.0);
  }

  // ============================================================
  // ELIMINAR PUNTO
  // ============================================================

  void _eliminarPunto(
    int index,
  ) {

    setState(() {

      _puntosRuta[index]
          .controller
          .dispose();

      _puntosRuta.removeAt(index);
    });

    if (_modoAutomatico) {

      _calcularRutaYDistanciaOSRM();

    } else {

      _calcularDistanciaRutaManual();
    }
  }

  // ============================================================
  // DESHACER ÚLTIMO PUNTO
  // ============================================================

  void _deshacerUltimoPunto() {

    if (_puntosRuta.isEmpty) {
      return;
    }

    final ultimo =
        _puntosRuta.removeLast();

    ultimo.controller.dispose();

    setState(() {});

    if (_modoAutomatico) {

      _calcularRutaYDistanciaOSRM();

    } else {

      _calcularDistanciaRutaManual();
    }
  }

  // ============================================================
  // LIMPIAR RUTA
  // ============================================================

  void _limpiarRuta() {

    for (final punto
        in _puntosRuta) {

      punto.controller.dispose();
    }

    setState(() {

      _puntosRuta.clear();

      _puntosRutaCarretera.clear();

      _kmTotalesController.text =
          '0.00 km';

      _calculandoKm = false;
    });
  }

  // ============================================================
  // ACTUALIZAR PUNTO
  // ============================================================

  void _actualizarPunto(
    int index,
    String nombre,
    LatLng latLng,
  ) {

    setState(() {

      _puntosRuta[index].nombre =
          nombre;

      _puntosRuta[index].latLng =
          latLng;

      _puntosRuta[index]
          .controller
          .text = nombre;
    });

    if (_modoAutomatico) {

      _calcularRutaYDistanciaOSRM();

    } else {

      _calcularDistanciaRutaManual();
    }

    _mapController.move(
      latLng,
      14.0,
    );
  }

  // ============================================================
  // AGREGAR PUNTO VACÍO
  // ============================================================

  void _agregarPuntoVacio() {

    setState(() {

      _puntosRuta.add(
        PuntoRutaItem(
          controller:
              TextEditingController(),
          nombre: '',
          latLng: null,
        ),
      );
    });
  }

  // ============================================================
  // GUARDAR / USAR RUTA
  // ============================================================

  void _guardarRuta() {

    if (_puntosRuta.length < 2) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Debes agregar al menos 2 puntos.',
          ),
          backgroundColor:
              Colors.orange,
        ),
      );

      return;
    }

    Navigator.pop(
      context,
      _kmTotalesController.text,
    );
  }

  // ============================================================
  // BUSCADOR DE FINCAS
  // ============================================================

  void _abrirBuscadorFincas(
    int index,
  ) {

    showDialog(
      context: context,

      builder: (context) {

        String filtro = '';

        return StatefulBuilder(
          builder: (
            context,
            setStateDialog,
          ) {

            final fincasFiltradas =
                _fincasFirebase.where(
              (f) {

                final nombre =
                    f['nombre']
                        .toString()
                        .toLowerCase();

                return nombre.contains(
                  filtro
                      .toLowerCase()
                      .trim(),
                );
              },
            ).toList();

            return AlertDialog(
              backgroundColor:
                  Colors.white,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16),
              ),

              title: Text(
                'Seleccionar Finca '
                '(${_fincasFirebase.length} cargadas)',

                style:
                    const TextStyle(
                  color:
                      colorPrincipal,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              content: SizedBox(
                width: 450,
                height: 450,

                child: Column(
                  children: [

                    // ==========================================
                    // BUSCAR
                    // ==========================================

                    TextField(
                      autofocus: true,

                      decoration:
                          InputDecoration(
                        labelText:
                            'Buscar por nombre...',

                        prefixIcon:
                            const Icon(
                          Icons.search,
                          color:
                              colorVerde,
                        ),

                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),

                          borderSide:
                              const BorderSide(
                            color:
                                colorBorde,
                          ),
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),

                          borderSide:
                              const BorderSide(
                            color:
                                colorBorde,
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),

                          borderSide:
                              const BorderSide(
                            color:
                                colorVerde,

                            width: 1.5,
                          ),
                        ),
                      ),

                      onChanged:
                          (value) {

                        setStateDialog(() {

                          filtro =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==========================================
                    // LISTA
                    // ==========================================

                    Expanded(
                      child:
                          _cargandoFincas

                              ? const Center(
                                  child:
                                      CircularProgressIndicator(
                                    color:
                                        colorVerde,
                                  ),
                                )

                              : fincasFiltradas
                                      .isEmpty

                                  ? Center(
                                      child:
                                          Text(
                                        _fincasFirebase
                                                .isEmpty
                                            ? 'No hay fincas registradas '
                                              'en Firebase.'
                                            : 'No se encontró ninguna '
                                              'finca con "$filtro".',

                                        textAlign:
                                            TextAlign.center,

                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.grey,
                                        ),
                                      ),
                                    )

                                  : ListView
                                      .builder(
                                      itemCount:
                                          fincasFiltradas
                                              .length,

                                      itemBuilder:
                                          (
                                        context,
                                        i,
                                      ) {

                                        final finca =
                                            fincasFiltradas[
                                                i];

                                        final LatLng
                                            latLng =
                                            finca[
                                                'latLng'];

                                        return Card(
                                          margin:
                                              const EdgeInsets
                                                  .only(
                                            bottom:
                                                8,
                                          ),

                                          elevation:
                                              0,

                                          color:
                                              Colors.white,

                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              10,
                                            ),

                                            side:
                                                const BorderSide(
                                              color:
                                                  colorBorde,
                                            ),
                                          ),

                                          child:
                                              ListTile(
                                            leading:
                                                const Icon(
                                              Icons
                                                  .agriculture,
                                              color:
                                                  colorVerde,
                                            ),

                                            title:
                                                Text(
                                              finca[
                                                  'nombre'],

                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,

                                                fontSize:
                                                    13,

                                                color:
                                                    colorPrincipal,
                                              ),
                                            ),

                                            subtitle:
                                                Text(
                                              'Lat: ${latLng.latitude.toStringAsFixed(4)}, '
                                              'Lng: ${latLng.longitude.toStringAsFixed(4)}',

                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    11,
                                              ),
                                            ),

                                            onTap:
                                                () {

                                              Navigator.pop(
                                                context,
                                              );

                                              _actualizarPunto(
                                                index,
                                                finca[
                                                    'nombre'],
                                                latLng,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),

              actions: [

                TextButton(
                  onPressed:
                      () =>
                          Navigator.pop(
                    context,
                  ),

                  child:
                      const Text(
                    'Cancelar',

                    style:
                        TextStyle(
                      color:
                          colorPrincipal,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MARCADORES DE FINCAS
  // ============================================================

  List<Marker>
      _crearMarcadoresFincas() {

    final List<Marker>
        marcadores = [];

    if (!_mostrarNombresFincasEnMapa) {
      return marcadores;
    }

    final bool mostrarTexto =
        _zoomActual >= 14.5;

    for (
      final finca
      in _fincasFirebase
    ) {

      marcadores.add(
        Marker(
          point:
              finca['latLng'],

          width:
              mostrarTexto
                  ? 140
                  : 18,

          height:
              mostrarTexto
                  ? 40
                  : 18,

          child:
              GestureDetector(
            onTap: () {

              ScaffoldMessenger
                  .of(context)
                  .showSnackBar(
                SnackBar(
                  content: Text(
                    'Finca: '
                    '${finca['nombre']}',
                  ),

                  duration:
                      const Duration(
                    seconds: 1,
                  ),
                ),
              );
            },

            child:
                Center(
              child:
                  mostrarTexto

                      ? Text(
                          finca['nombre'],

                          style:
                              const TextStyle(
                            color:
                                Colors.white,

                            fontSize:
                                11,

                            fontWeight:
                                FontWeight.bold,

                            shadows: [
                              Shadow(
                                blurRadius:
                                    4,

                                color:
                                    Colors.black,

                                offset:
                                    Offset(
                                  1,
                                  1,
                                ),
                              ),

                              Shadow(
                                blurRadius:
                                    4,

                                color:
                                    Colors.black,

                                offset:
                                    Offset(
                                  -1,
                                  -1,
                                ),
                              ),
                            ],
                          ),

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          maxLines:
                              1,

                          textAlign:
                              TextAlign.center,
                        )

                      : Container(
                          width: 10,
                          height: 10,

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.greenAccent,

                            shape:
                                BoxShape.circle,

                            border:
                                Border.all(
                              color:
                                  Colors.white,

                              width:
                                  1.5,
                            ),

                            boxShadow: const [
                              BoxShadow(
                                color:
                                    Colors.black54,

                                blurRadius:
                                    2,
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ),
      );
    }

    return marcadores;
  }

  // ============================================================
  // MARCADORES DE LA RUTA
  // ============================================================

  List<Marker>
      _crearMarcadoresRuta() {

    final List<Marker>
        marcadores = [];

    for (
      int i = 0;
      i < _puntosRuta.length;
      i++
    ) {

      final punto =
          _puntosRuta[i];

      if (punto.latLng == null) {
        continue;
      }

      marcadores.add(
        Marker(
          point:
              punto.latLng!,

          width: 42,

          height: 45,

          child:
              Column(
            children: [

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      colorPrincipal,

                  borderRadius:
                      BorderRadius
                          .circular(5),
                ),

                child:
                    Text(
                  '${i + 1}',

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        10,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const Icon(
                Icons.location_on,

                color:
                    Colors.red,

                size:
                    26,
              ),
            ],
          ),
        ),
      );
    }

    return marcadores;
  }

  // ============================================================
  // PANEL DE MODO
  // ============================================================

  Widget _construirSelectorModo() {

    return Container(
      padding:
          const EdgeInsets.all(4),

      decoration:
          BoxDecoration(
        color:
            colorFondo,

        borderRadius:
            BorderRadius.circular(10),

        border:
            Border.all(
          color:
              colorBorde,
        ),
      ),

      child:
          Row(
        children: [

          // ======================================================
          // AUTOMÁTICA
          // ======================================================

          Expanded(
            child:
                InkWell(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),

              onTap:
                  () =>
                      _cambiarModo(
                true,
              ),

              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 9,
                  horizontal: 6,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      _modoAutomatico
                          ? colorVerde
                          : Colors
                              .transparent,

                  borderRadius:
                      BorderRadius
                          .circular(8),
                ),

                child:
                    Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  children: [

                    Icon(
                      Icons
                          .alt_route,

                      size:
                          18,

                      color:
                          _modoAutomatico
                              ? Colors
                                  .white
                              : colorPrincipal,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Flexible(
                      child:
                          Text(
                        'Ruta automática',

                        textAlign:
                            TextAlign.center,

                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            TextStyle(
                          fontSize:
                              11,

                          fontWeight:
                              FontWeight.bold,

                          color:
                              _modoAutomatico
                                  ? Colors
                                      .white
                                  : colorPrincipal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================================================
          // MANUAL
          // ======================================================

          Expanded(
            child:
                InkWell(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),

              onTap:
                  () =>
                      _cambiarModo(
                false,
              ),

              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 9,
                  horizontal: 6,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      !_modoAutomatico
                          ? colorVerde
                          : Colors
                              .transparent,

                  borderRadius:
                      BorderRadius
                          .circular(8),
                ),

                child:
                    Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  children: [

                    Icon(
                      Icons
                          .edit_location_alt,

                      size:
                          18,

                      color:
                          !_modoAutomatico
                              ? Colors
                                  .white
                              : colorPrincipal,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Flexible(
                      child:
                          Text(
                        'Dibujar ruta',

                        textAlign:
                            TextAlign.center,

                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            TextStyle(
                          fontSize:
                              11,

                          fontWeight:
                              FontWeight.bold,

                          color:
                              !_modoAutomatico
                                  ? Colors
                                      .white
                                  : colorPrincipal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PANEL DE CONTROLES
  // ============================================================

  Widget _construirPanelControles(
    double ancho,
  ) {
    final bool esMovil = ancho < 700;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorBorde,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // CABECERA
          // ======================================================
          if (ancho < 550)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Secuencia de la Ruta',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorPrincipal,
                        ),
                      ),
                    ),
                    if (widget.seleccionarRuta)
                      SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorVerde,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _puntosRuta.length < 2
                              ? null
                              : _guardarRuta,
                          icon: const Icon(
                            Icons.check,
                            size: 18,
                          ),
                          label: const Text(
                            'Usar esta ruta',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Secuencia de la Ruta',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorPrincipal,
                  ),
                ),
                if (widget.seleccionarRuta)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorVerde,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _puntosRuta.length < 2
                        ? null
                        : _guardarRuta,
                    icon: const Icon(
                      Icons.check,
                      size: 17,
                    ),
                    label: const Text(
                      'Usar esta ruta',
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 8),

          // ======================================================
          // INSTRUCCIÓN
          // ======================================================
          Text(
            _modoAutomatico
                ? '🚗 Selecciona fincas o toca el mapa. ZAFI buscará una ruta por carretera.'
                : '✏️ Toca el mapa siguiendo el camino real. ZAFI respetará exactamente los puntos que marques.',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 10),

          // ======================================================
          // SELECTOR
          // ======================================================
          _construirSelectorModo(),

          const SizedBox(height: 10),

          // ======================================================
          // DISTANCIA
          // ======================================================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorVerdeSuave,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF9BC6A0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.straighten,
                  color: colorVerde,
                  size: 27,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _modoAutomatico
                            ? 'Distancia por carretera'
                            : 'Distancia de ruta dibujada',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TextField(
                        controller: _kmTotalesController,
                        readOnly: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_calculandoKm)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorVerde,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ======================================================
          // BOTONES DE CONTROL
          // ======================================================
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _puntosRuta.isEmpty
                      ? null
                      : _deshacerUltimoPunto,
                  icon: const Icon(
                    Icons.undo,
                    size: 17,
                  ),
                  label: const Text('Deshacer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorPrincipal,
                    side: const BorderSide(
                      color: colorBorde,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _puntosRuta.isEmpty
                      ? null
                      : _limpiarRuta,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 17,
                  ),
                  label: const Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(
                      color: Color(0xFFE0BABA),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ======================================================
          // EN MÓVIL: EL BOTÓN AGREGAR SIEMPRE VISIBLE
          // Y LA LISTA ES LA ÚNICA ZONA CON SCROLL.
          // ======================================================
          if (esMovil) ...[
            const SizedBox(height: 4),
            _construirListaPuntos(ancho),
          ] else ...[
            const SizedBox(height: 10),
            Expanded(
              child: _construirListaPuntos(
                ancho,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: colorVerde,
                ),
                onPressed: _agregarPuntoVacio,
                icon: const Icon(
                  Icons.add_circle_outline,
                ),
                label: Text(
                  _modoAutomatico
                      ? 'Agregar punto'
                      : 'Agregar punto de referencia',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // LISTA DE PUNTOS
  // Esta es la única zona que debe desplazarse en móvil.
  // ============================================================
  Widget _construirListaPuntos(
    double ancho,
  ) {
    if (_puntosRuta.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 10,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _modoAutomatico
                  ? Icons.route
                  : Icons.edit_location,
              size: 42,
              color: colorVerde.withOpacity(0.65),
            ),
            const SizedBox(height: 10),
            Text(
              _modoAutomatico
                  ? 'Agrega una finca o toca el mapa'
                  : 'Toca el mapa para comenzar a dibujar',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _modoAutomatico
                  ? 'Puedes buscar fincas registradas.'
                  : 'Marca varios puntos siguiendo el camino real.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    Widget construirPunto(int index) {
      final punto = _puntosRuta[index];

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: _modoAutomatico
            ? const Color(0xFFF8F5FA)
            : colorVerdeSuave,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: colorBorde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorPrincipal,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      punto.nombre.isNotEmpty
                          ? punto.nombre
                          : 'Punto sin definir',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: colorPrincipal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _eliminarPunto(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 19,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              InkWell(
                onTap: () => _abrirBuscadorFincas(index),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _modoAutomatico
                        ? 'Buscar finca registrada...'
                        : 'Finca / punto de referencia',
                    prefixIcon: const Icon(
                      Icons.agriculture_outlined,
                      color: colorVerde,
                    ),
                    suffixIcon: const Icon(
                      Icons.search,
                      size: 19,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: colorBorde),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: colorBorde),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(
                        color: colorVerde,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    punto.controller.text.isNotEmpty
                        ? punto.controller.text
                        : 'Seleccionar finca...',
                    style: TextStyle(
                      fontSize: 12,
                      color: punto.controller.text.isNotEmpty
                          ? Colors.black87
                          : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (punto.latLng != null)
                Text(
                  'Lat: ${punto.latLng!.latitude.toStringAsFixed(5)}, '
                  'Lng: ${punto.latLng!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                )
              else
                const Text(
                  '⚠️ Selecciona una finca o toca el mapa',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final puntosWidgets = List<Widget>.generate(
      _puntosRuta.length,
      construirPunto,
    );

    final agregar = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: colorVerde,
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
        ),
        onPressed: _agregarPuntoVacio,
        icon: const Icon(Icons.add_circle_outline, size: 26),
        label: Text(
          _modoAutomatico
              ? 'Agregar punto'
              : 'Agregar punto de referencia',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

    // En móvil NO usamos ListView ni Expanded.
    // Toda la pantalla se desplaza desde el SingleChildScrollView del build.
    if (ancho < 700) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...puntosWidgets,
          agregar,
        ],
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 8),
        physics: const ClampingScrollPhysics(),
        children: [
          ...puntosWidgets,
        ],
      ),
    );
  }

  // ============================================================
  // MAPA
  // ============================================================

  Widget _construirMapa(
    double ancho,
  ) {

    final marcadoresFincas =
        _crearMarcadoresFincas();

    final marcadoresRuta =
        _crearMarcadoresRuta();

    return Container(
      margin:
          const EdgeInsets.all(12),

      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),

        border:
            Border.all(
          color:
              colorBorde,
        ),
      ),

      clipBehavior:
          Clip.antiAlias,

      child:
          Stack(
        children: [

          // ======================================================
          // MAPA
          // ======================================================

          FlutterMap(
            mapController:
                _mapController,

            options:
                MapOptions(
              initialCenter:
                  const LatLng(
                15.22,
                -87.90,
              ),

              initialZoom:
                  11.0,

              onPositionChanged:
                  (
                camera,
                hasGesture,
              ) {

                final nuevoZoom =
                    camera.zoom;

                if (mounted) {

                  setState(() {
                    _zoomActual =
                        nuevoZoom;
                  });
                }
              },

              onTap:
                  (
                tapPosition,
                latLng,
              ) {

                _agregarPuntoEnMapa(
                  latLng,
                );
              },
            ),

            children: [

              // ==================================================
              // SATÉLITE
              // ==================================================

              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/'
                    'ArcGIS/rest/services/'
                    'World_Imagery/'
                    'MapServer/tile/'
                    '{z}/{y}/{x}',

                userAgentPackageName:
                    'com.azunosa.transporte',
              ),

              // ==================================================
              // NOMBRES
              // ==================================================

              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/'
                    'ArcGIS/rest/services/'
                    'Reference/'
                    'World_Boundaries_and_Places/'
                    'MapServer/tile/'
                    '{z}/{y}/{x}',

                userAgentPackageName:
                    'com.azunosa.transporte',
              ),

              // ==================================================
              // RUTA
              // ==================================================

              if (_puntosRutaCarretera.length >= 2)

                PolylineLayer(
                  polylines: [

                    Polyline(
                      points:
                          _puntosRutaCarretera,

                      color:
                          _modoAutomatico
                              ? Colors.blueAccent
                              : colorVerde,

                      strokeWidth:
                          _modoAutomatico
                              ? 4.0
                              : 5.0,
                    ),
                  ],
                ),

              // ==================================================
              // FINCAS
              // ==================================================

              MarkerLayer(
                markers:
                    marcadoresFincas,
              ),

              // ==================================================
              // PUNTOS RUTA
              // ==================================================

              MarkerLayer(
                markers:
                    marcadoresRuta,
              ),
            ],
          ),

          // ======================================================
          // INDICADOR DEL MODO
          // ======================================================

          Positioned(
            top:
                10,

            right:
                10,

            child:
                Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal:
                    10,

                vertical:
                    7,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withOpacity(
                  0.94,
                ),

                borderRadius:
                    BorderRadius
                        .circular(8),

                boxShadow: const [
                  BoxShadow(
                    color:
                        Colors.black12,

                    blurRadius:
                        4,
                  ),
                ],
              ),

              child:
                  Row(
                mainAxisSize:
                    MainAxisSize.min,

                children: [

                  Icon(
                    _modoAutomatico
                        ? Icons
                            .alt_route
                        : Icons
                            .edit_location_alt,

                    size:
                        16,

                    color:
                        colorVerde,
                  ),

                  const SizedBox(
                    width:
                        5,
                  ),

                  Text(
                    _modoAutomatico
                        ? 'Ruta automática'
                        : 'Dibujando ruta',

                    style:
                        const TextStyle(
                      fontSize:
                          11,

                      fontWeight:
                          FontWeight.bold,

                      color:
                          colorPrincipal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // AYUDA EN MODO MANUAL
          // ======================================================

          if (!_modoAutomatico)

            Positioned(
              bottom:
                  10,

              left:
                  10,

              right:
                  10,

              child:
                  Center(
                child:
                    Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        12,

                    vertical:
                        8,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white
                            .withOpacity(
                      0.94,
                    ),

                    borderRadius:
                        BorderRadius
                            .circular(20),

                    boxShadow:
                        const [
                      BoxShadow(
                        color:
                            Colors.black12,

                        blurRadius:
                            4,
                      ),
                    ],
                  ),

                  child:
                      const Text(
                    '✏️ Toca el camino para marcar el recorrido',

                    textAlign:
                        TextAlign.center,

                    style:
                        TextStyle(
                      fontSize:
                          11,

                      fontWeight:
                          FontWeight.w600,

                      color:
                          colorPrincipal,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(
      backgroundColor:
          colorFondo,
      resizeToAvoidBottomInset: false,

      appBar:
          AppBar(
        title:
            const Text(
          'Ruta de Fincas',

          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,

            fontSize:
                16,
          ),
        ),

        backgroundColor:
            colorPrincipal,

        foregroundColor:
            Colors.white,

        elevation:
            0,

        actions: [

          // ======================================================
          // MOSTRAR / OCULTAR FINCAS
          // ======================================================

          IconButton(
            tooltip:
                'Mostrar/Ocultar fincas',

            icon:
                Icon(
              _mostrarNombresFincasEnMapa
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),

            onPressed:
                () {

              setState(() {

                _mostrarNombresFincasEnMapa =
                    !_mostrarNombresFincasEnMapa;
              });
            },
          ),

          // ======================================================
          // CENTRAR MAPA
          // ======================================================

          IconButton(
            tooltip:
                'Centrar mapa',

            icon:
                const Icon(
              Icons.my_location,
            ),

            onPressed:
                () {

              _mapController.move(
                const LatLng(
                  15.22,
                  -87.90,
                ),

                11.0,
              );
            },
          ),
        ],
      ),

      body:
          LayoutBuilder(
        builder:
            (
          context,
          constraints,
        ) {

          // ======================================================
          // MÓVIL
          // ======================================================

          if (constraints.maxWidth < 700) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 360,
                    child: _construirMapa(
                      constraints.maxWidth,
                    ),
                  ),
                  _construirPanelControles(
                    constraints.maxWidth,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          }

          // ======================================================
          // TABLET / PC
          // ======================================================

          return Row(
            children: [

              Expanded(
                flex:
                    5,

                child:
                    _construirPanelControles(
                  constraints.maxWidth,
                ),
              ),

              Expanded(
                flex:
                    5,

                child:
                    _construirMapa(
                  constraints.maxWidth,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================
// MODELO DE PUNTO
// ================================================================

class PuntoRutaItem {

  final TextEditingController controller;

  String nombre;

  LatLng? latLng;

  PuntoRutaItem({
    required this.controller,
    required this.nombre,
    this.latLng,
  });
}