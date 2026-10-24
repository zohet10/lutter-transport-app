import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'package:cloud_firestore/cloud_firestore.dart';

class MapaFincaScreen extends StatefulWidget {
  const MapaFincaScreen({super.key});

  @override
  State<MapaFincaScreen> createState() => _MapaFincaScreenState();
}

class _MapaFincaScreenState extends State<MapaFincaScreen> {
  // ============================================================
  // COLORES GENERALES DE LOS OTROS FORMATOS
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  // ============================================================
  // VARIABLES
  // ============================================================

  List<FincaPunto> _fincasCargadas = [];
  List<FincaPunto> _fincasFiltradas = [];

  String _nombreArchivo = 'Ningún archivo seleccionado';

  bool _guardando = false;
  bool _cargando = true;
  bool _cargandoArchivo = false;

  final TextEditingController _searchController =
      TextEditingController();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filtrarFincas);

    _cargarFincasExistentesDeFirestore();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // FILTRAR FINCAS
  // ============================================================

  void _filtrarFincas() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _fincasFiltradas = _fincasCargadas.where((finca) {
        return finca.nombre.toLowerCase().contains(query);
      }).toList();
    });
  }

  // ============================================================
  // CARGAR FINCAS EXISTENTES DE FIREBASE
  // ============================================================

  Future<void> _cargarFincasExistentesDeFirestore() async {
    setState(() {
      _cargando = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fincas')
          .get();

      List<FincaPunto> fincasExistentes = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        fincasExistentes.add(
          FincaPunto(
            nombre: data['nombre'] ?? 'Sin nombre',
            latitud: (data['latitud'] ?? 0.0).toDouble(),
            longitud: (data['longitud'] ?? 0.0).toDouble(),
            yaGuardada: true,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _fincasCargadas = fincasExistentes;
          _fincasFiltradas = fincasExistentes;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar fincas existentes: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // CARGAR ARCHIVO KML / KMZ
  // ============================================================

  Future<void> _cargarArchivoKml() async {
    setState(() {
      _cargandoArchivo = true;
    });

    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Archivos de Fincas',
        extensions: ['kml', 'kmz', 'txt'],
      );

      final XFile? archivoSeleccionado =
          await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (archivoSeleccionado != null) {
        String nombre = archivoSeleccionado.name;

        Uint8List fileBytes =
            await archivoSeleccionado.readAsBytes();

        String contenido = "";

        // ======================================================
        // KMZ
        // ======================================================

        if (nombre.toLowerCase().endsWith('.kmz')) {
          try {
            final archive =
                ZipDecoder().decodeBytes(fileBytes);

            for (var file in archive) {
              if (file.name
                  .toLowerCase()
                  .endsWith('.kml')) {
                contenido = utf8.decode(
                  file.content as List<int>,
                );

                break;
              }
            }

            if (contenido.isEmpty &&
                archive.isNotEmpty) {
              contenido = utf8.decode(
                archive.first.content as List<int>,
              );
            }
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Error al descomprimir el archivo KMZ.',
                ),
                backgroundColor: Colors.red,
              ),
            );

            return;
          }
        } else {
          // ====================================================
          // KML / TXT
          // ====================================================

          contenido = utf8.decode(fileBytes);
        }

        List<FincaPunto> fincasNuevasExtraidas = [];

        try {
          final document =
              xml.XmlDocument.parse(contenido);

          final placemarks =
              document.findAllElements('Placemark');

          final Set<String> nombresExistentes =
              _fincasCargadas
                  .map(
                    (f) => f.nombre
                        .trim()
                        .toLowerCase(),
                  )
                  .toSet();

          // ==================================================
          // RECORRER PLACEMARKS
          // ==================================================

          for (var pm in placemarks) {
            String nombreFinca = "Finca sin nombre";

            final nameElement =
                pm.findElements('name').firstOrNull;

            if (nameElement != null) {
              nombreFinca =
                  nameElement.text.trim();
            }

            String nombreLower =
                nombreFinca.toLowerCase();

            // =================================================
            // EVITAR DUPLICADOS
            // =================================================

            if (nombresExistentes.contains(
              nombreLower,
            )) {
              continue;
            }

            final coordElements =
                pm.findAllElements('coordinates');

            List<PuntoGeo> puntosPoligono = [];

            // =================================================
            // EXTRAER COORDENADAS
            // =================================================

            for (var coordEl in coordElements) {
              String coordText =
                  coordEl.text.trim();

              List<String> lineasPuntos =
                  coordText.split(
                RegExp(r'\s+'),
              );

              for (var puntoStr in lineasPuntos) {
                List<String> partes =
                    puntoStr.split(',');

                if (partes.length >= 2) {
                  double? lng =
                      double.tryParse(partes[0]);

                  double? lat =
                      double.tryParse(partes[1]);

                  if (lat != null &&
                      lng != null) {
                    puntosPoligono.add(
                      PuntoGeo(
                        lat: lat,
                        lng: lng,
                      ),
                    );
                  }
                }
              }
            }

            // =================================================
            // CALCULAR CENTRO
            // =================================================

            if (puntosPoligono.isNotEmpty) {
              double sumLat = 0;
              double sumLng = 0;

              for (var p in puntosPoligono) {
                sumLat += p.lat;
                sumLng += p.lng;
              }

              double latCentro =
                  sumLat /
                      puntosPoligono.length;

              double lngCentro =
                  sumLng /
                      puntosPoligono.length;

              fincasNuevasExtraidas.add(
                FincaPunto(
                  nombre: nombreFinca,
                  latitud: latCentro,
                  longitud: lngCentro,
                  yaGuardada: false,
                ),
              );

              nombresExistentes.add(
                nombreLower,
              );
            }
          }
        } catch (e) {
          // Error de parseo XML
        }

        if (!mounted) return;

        // ======================================================
        // MOSTRAR RESULTADOS
        // ======================================================

        if (fincasNuevasExtraidas.isNotEmpty) {
          setState(() {
            _fincasCargadas.addAll(
              fincasNuevasExtraidas,
            );

            _filtrarFincas();

            _nombreArchivo = nombre;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡Se agregaron ${fincasNuevasExtraidas.length} fincas nuevas!',
              ),
              backgroundColor: colorVerde,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontraron fincas nuevas; todas ya están registradas.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargandoArchivo = false;
        });
      }
    }
  }

  // ============================================================
  // GUARDAR EN FIREBASE
  // ============================================================

  Future<void> _guardarEnFirestore() async {
    setState(() {
      _guardando = true;
    });

    try {
      final firestore =
          FirebaseFirestore.instance;

      final fincasPorGuardar =
          _fincasCargadas
              .where(
                (f) => !f.yaGuardada,
              )
              .toList();

      if (fincasPorGuardar.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay fincas nuevas pendientes por guardar.',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return;
      }

      // ========================================================
      // GUARDAR CADA FINCA
      // ========================================================

      for (var finca in fincasPorGuardar) {
        await firestore.collection('fincas').add({
          'nombre': finca.nombre,
          'latitud': finca.latitud,
          'longitud': finca.longitud,
          'archivo_origen': _nombreArchivo,
          'fecha_creacion':
              FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Fincas nuevas guardadas en Firestore exitosamente!',
          ),
          backgroundColor: colorVerde,
        ),
      );

      await _cargarFincasExistentesDeFirestore();

      if (!mounted) return;

      Navigator.pop(
        context,
        {
          'fincas': _fincasCargadas,
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar en Firestore: $e',
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
  // DECORACIÓN DE CAMPOS
  // ============================================================

  InputDecoration _searchDecoration() {
    return InputDecoration(
      hintText: 'Buscar finca por nombre...',
      hintStyle: const TextStyle(
        color: Color(0xFF777777),
        fontSize: 14,
      ),

      prefixIcon: const Icon(
        Icons.search,
        color: colorVerde,
      ),

      suffixIcon:
          _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,

      filled: true,
      fillColor: Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 12,
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
          width: 1.3,
        ),
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),
        borderSide: const BorderSide(
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
    return Scaffold(
      backgroundColor: colorFondo,

      body: Column(
        children: [
          // ======================================================
          // BARRA SUPERIOR
          // ======================================================

          Container(
            height: 16,
            width: double.infinity,
            color: colorPrincipal,
          ),

          // ======================================================
          // CONTENIDO
          // ======================================================

          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder:
                    (context, constraints) {
                  final bool pantallaPequena =
                      constraints.maxWidth < 700;

                  return ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: Container(
                      width: double.infinity,

                      margin:
                          EdgeInsets.symmetric(
                        horizontal:
                            pantallaPequena
                                ? 8
                                : 24,
                        vertical:
                            pantallaPequena
                                ? 12
                                : 18,
                      ),

                      decoration:
                          BoxDecoration(
                        color: Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),

                        border: Border.all(
                          color: colorBorde,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(
                              0.04,
                            ),
                            blurRadius: 10,
                            offset:
                                const Offset(
                              0,
                              3,
                            ),
                          ),
                        ],
                      ),

                      child: Padding(
                        padding:
                            EdgeInsets.all(
                          pantallaPequena
                              ? 16
                              : 20,
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .stretch,
                          children: [
                            // ==============================================
                            // ENCABEZADO
                            // ==============================================

                            const Text(
                              'Listado de Fincas y Coordenadas',
                              style: TextStyle(
                                color:
                                    colorVerde,
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            const Text(
                              'Cargue un archivo KML o KMZ para obtener las coordenadas de las fincas.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            const Divider(
                              color:
                                  colorBorde,
                              height: 1,
                            ),

                            const SizedBox(
                              height: 20,
                            ),

                            // ==============================================
                            // BOTÓN CARGAR ARCHIVO
                            // ==============================================

                            SizedBox(
                              height: 48,
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
                                  elevation: 0,
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
                                    (_guardando ||
                                            _cargandoArchivo)
                                        ? null
                                        : _cargarArchivoKml,
                                icon:
                                    _cargandoArchivo
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
                                        : const Icon(
                                            Icons
                                                .upload_file,
                                          ),
                                label: Text(
                                  _cargandoArchivo
                                      ? 'Leyendo archivo...'
                                      : 'Cargar KML/KMZ',
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        15,
                                    fontWeight:
                                        FontWeight
                                            .w500,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            // ==============================================
                            // NOMBRE DEL ARCHIVO
                            // ==============================================

                            Text(
                              _nombreArchivo,
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w500,
                                color:
                                    Colors.grey,
                              ),
                              textAlign:
                                  TextAlign.center,
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            // ==============================================
                            // BUSCADOR
                            // ==============================================

                            TextField(
                              controller:
                                  _searchController,
                              decoration:
                                  _searchDecoration(),
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            // ==============================================
                            // LISTADO
                            // ==============================================

                            Expanded(
                              child:
                                  _fincasFiltradas
                                          .isEmpty
                                      ? const Center(
                                          child:
                                              Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .location_off_outlined,
                                                size:
                                                    45,
                                                color:
                                                    Colors.grey,
                                              ),
                                              SizedBox(
                                                height:
                                                    10,
                                              ),
                                              Text(
                                                'No se encontraron fincas.',
                                                style:
                                                    TextStyle(
                                                  color:
                                                      Colors.grey,
                                                  fontSize:
                                                      15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView
                                          .builder(
                                          itemCount:
                                              _fincasFiltradas
                                                  .length,
                                          itemBuilder:
                                              (
                                            context,
                                            index,
                                          ) {
                                            final finca =
                                                _fincasFiltradas[
                                                    index];

                                            return Container(
                                              margin:
                                                  const EdgeInsets
                                                      .only(
                                                bottom:
                                                    8,
                                              ),

                                              decoration:
                                                  BoxDecoration(
                                                color:
                                                    Colors.white,
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  8,
                                                ),
                                                border:
                                                    Border.all(
                                                  color:
                                                      colorBorde,
                                                ),
                                              ),

                                              child:
                                                  ListTile(
                                                contentPadding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal:
                                                      12,
                                                  vertical:
                                                      4,
                                                ),

                                                leading:
                                                    CircleAvatar(
                                                  backgroundColor:
                                                      finca.yaGuardada
                                                          ? Colors.grey
                                                          : colorPrincipal,
                                                  child:
                                                      Icon(
                                                    finca.yaGuardada
                                                        ? Icons.cloud_done
                                                        : Icons.agriculture,
                                                    color:
                                                        Colors.white,
                                                  ),
                                                ),

                                                title:
                                                    Row(
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          Text(
                                                        finca.nombre,
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize:
                                                              14,
                                                          color:
                                                              colorPrincipal,
                                                        ),
                                                      ),
                                                    ),

                                                    if (finca.yaGuardada)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                          horizontal:
                                                              8,
                                                          vertical:
                                                              3,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              const Color(
                                                            0xFFE8F5E9,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                            4,
                                                          ),
                                                        ),
                                                        child:
                                                            const Text(
                                                          'Guardada',
                                                          style:
                                                              TextStyle(
                                                            fontSize:
                                                                10,
                                                            color:
                                                                colorVerde,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                subtitle:
                                                    Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top:
                                                        5,
                                                  ),
                                                  child:
                                                      Text(
                                                    'Latitud: ${finca.latitud.toStringAsFixed(6)}\n'
                                                    'Longitud: ${finca.longitud.toStringAsFixed(6)}',
                                                    style:
                                                        const TextStyle(
                                                      fontSize:
                                                          12,
                                                      color:
                                                          Colors.black87,
                                                    ),
                                                  ),
                                                ),

                                                isThreeLine:
                                                    true,
                                              ),
                                            );
                                          },
                                        ),
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            // ==============================================
                            // BOTÓN GUARDAR
                            // ==============================================

                            SizedBox(
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
                                      8,
                                    ),
                                  ),
                                ),
                                onPressed:
                                    _guardando
                                        ? null
                                        : _guardarEnFirestore,
                                child: _guardando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Colors.white,
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .center,
                                        children: [
                                          Icon(
                                            Icons
                                                .save_outlined,
                                            color:
                                                Colors.white,
                                          ),
                                          SizedBox(
                                            width:
                                                8,
                                          ),
                                          Text(
                                            'Guardar Nuevas y Continuar',
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  15,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PUNTO GEOGRÁFICO
// ================================================================

class PuntoGeo {
  final double lat;
  final double lng;

  PuntoGeo({
    required this.lat,
    required this.lng,
  });
}

// ================================================================
// FINCA
// ================================================================

class FincaPunto {
  final String nombre;
  final double latitud;
  final double longitud;
  final bool yaGuardada;

  FincaPunto({
    required this.nombre,
    required this.latitud,
    required this.longitud,
    this.yaGuardada = false,
  });
}