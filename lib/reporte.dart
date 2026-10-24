import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel_plus/excel_plus.dart' as excel_pkg;
import 'package:universal_html/html.dart' as html;

class MenuReporteriaScreen extends StatefulWidget {
  const MenuReporteriaScreen({super.key});

  @override
  State<MenuReporteriaScreen> createState() =>
      _MenuReporteriaScreenState();
}

class _MenuReporteriaScreenState extends State<MenuReporteriaScreen> {
  // ============================================================
  // COLORES
  // ============================================================

  static const Color colorAzunosa = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorVerdeClaro = Color(0xFFE8F5E9);
  static const Color colorFondo = Color(0xFFF5F7FA);

  // ============================================================
  // COLECCIONES
  // ============================================================

  final List<String> _colecciones = [
    'registros_f225',
    'registros_f066',
  ];

  // ============================================================
  // FILTROS
  // ============================================================

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  String? _actividadSeleccionada;
  String? _supervisorSeleccionado;

  String _formatoSeleccionado = 'Todos';

  String _busqueda = '';

  final TextEditingController _busquedaController =
      TextEditingController();

  // ============================================================
  // DATOS
  // ============================================================

  List<Map<String, dynamic>> _registros = [];

  List<String> _actividades = [];

  List<String> _supervisores = [];

  bool _cargando = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGAR DATOS
  // ============================================================

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
    });

    try {
      final registros = await _obtenerRegistros();

      final actividades = _obtenerListaActividades(
        registros,
      );

      final supervisores = _obtenerListaSupervisores(
        registros,
      );

      if (!mounted) return;

      setState(() {
        _registros = registros;
        _actividades = actividades;
        _supervisores = supervisores;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al cargar los registros: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CONVERTIR FECHA
  // ============================================================

  DateTime? _convertirFecha(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    if (valor is String) {
      final texto = valor.trim();

      if (texto.isEmpty) {
        return null;
      }

      // dd/MM/yyyy
      final partes = texto.split('/');

      if (partes.length == 3) {
        final dia = int.tryParse(partes[0]);
        final mes = int.tryParse(partes[1]);
        final anio = int.tryParse(partes[2]);

        if (dia != null &&
            mes != null &&
            anio != null) {
          return DateTime(
            anio,
            mes,
            dia,
          );
        }
      }

      // ISO
      return DateTime.tryParse(texto);
    }

    return null;
  }

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================

  String _formatearFecha(dynamic valor) {
    final fecha = _convertirFecha(valor);

    if (fecha == null) {
      return '-';
    }

    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  // ============================================================
  // TEXTO
  // ============================================================

  String _texto(dynamic valor) {
    if (valor == null) {
      return '-';
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return '-';
    }

    return texto;
  }

  // ============================================================
  // OBTENER TODOS LOS REGISTROS
  // ============================================================

  Future<List<Map<String, dynamic>>> _obtenerRegistros() async {
    final List<Map<String, dynamic>> registros = [];

    for (final coleccion in _colecciones) {
      final snapshot = await FirebaseFirestore.instance
          .collection(coleccion)
          .get();

      for (final doc in snapshot.docs) {
        final datos = Map<String, dynamic>.from(
          doc.data(),
        );

        registros.add({
          'docId': doc.id,
          'coleccion': coleccion,
          'datos': datos,
        });
      }
    }

    // Ordenar del más reciente al más antiguo.
    registros.sort((a, b) {
      final fechaA = _convertirFecha(
        a['datos']['fecha'],
      );

      final fechaB = _convertirFecha(
        b['datos']['fecha'],
      );

      if (fechaA == null && fechaB == null) {
        return 0;
      }

      if (fechaA == null) {
        return 1;
      }

      if (fechaB == null) {
        return -1;
      }

      return fechaB.compareTo(fechaA);
    });

    return registros;
  }

  // ============================================================
  // LISTA DE ACTIVIDADES
  // ============================================================

  List<String> _obtenerListaActividades(
    List<Map<String, dynamic>> registros,
  ) {
    final Set<String> actividades = {};

    for (final registro in registros) {
      final datos = Map<String, dynamic>.from(
        registro['datos'] ?? {},
      );

      final actividad = datos['actividad'];

      if (actividad != null &&
          actividad.toString().trim().isNotEmpty) {
        actividades.add(
          actividad.toString().trim(),
        );
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
  // LISTA DE SUPERVISORES
  // ============================================================

  List<String> _obtenerListaSupervisores(
    List<Map<String, dynamic>> registros,
  ) {
    final Set<String> supervisores = {};

    for (final registro in registros) {
      final datos = Map<String, dynamic>.from(
        registro['datos'] ?? {},
      );

      final supervisor =
          datos['supervisor'] ??
          datos['nombreSupervisor'] ??
          datos['creadoPor'];

      if (supervisor != null &&
          supervisor.toString().trim().isNotEmpty) {
        supervisores.add(
          supervisor.toString().trim(),
        );
      }
    }

    final lista = supervisores.toList();

    lista.sort(
      (a, b) => a.toLowerCase().compareTo(
        b.toLowerCase(),
      ),
    );

    return lista;
  }

  // ============================================================
  // OBTENER SUPERVISOR
  // ============================================================

  String _obtenerSupervisor(
    Map<String, dynamic> datos,
  ) {
    final supervisor =
        datos['supervisor'] ??
        datos['nombreSupervisor'] ??
        datos['creadoPor'];

    return _texto(supervisor);
  }

  // ============================================================
  // NOMBRE DEL FORMATO
  // ============================================================

  String _nombreFormato(
    String coleccion,
    Map<String, dynamic> datos,
  ) {
    if (coleccion == 'registros_f225') {
      return 'F-OA-225';
    }

    if (coleccion == 'registros_f066') {
      // F-066 normal tiene cantidadPersonas.
      if (datos.containsKey('cantidadPersonas')) {
        return 'F-066 Transporte';
      }

      // F-066 Agua no tiene cantidadPersonas.
      return 'F-066 Transporte de Agua';
    }

    return coleccion;
  }

  // ============================================================
  // FILTRO POR FORMATO
  // ============================================================

  bool _cumpleFormato(
    String coleccion,
    Map<String, dynamic> datos,
  ) {
    if (_formatoSeleccionado == 'Todos') {
      return true;
    }

    return _nombreFormato(
          coleccion,
          datos,
        ) ==
        _formatoSeleccionado;
  }

  // ============================================================
  // CUMPLE TODOS LOS FILTROS
  // ============================================================

  bool _cumpleFiltros(
    Map<String, dynamic> registro,
  ) {
    final String coleccion =
        registro['coleccion']?.toString() ?? '';

    final Map<String, dynamic> datos =
        Map<String, dynamic>.from(
      registro['datos'] ?? {},
    );

    // ----------------------------------------------------------
    // FORMATO
    // ----------------------------------------------------------

    if (!_cumpleFormato(
      coleccion,
      datos,
    )) {
      return false;
    }

    // ----------------------------------------------------------
    // BÚSQUEDA GENERAL
    // ----------------------------------------------------------

    if (_busqueda.trim().isNotEmpty) {
      final busqueda =
          _busqueda.toLowerCase().trim();

      final textoCompleto = [
        _nombreFormato(
          coleccion,
          datos,
        ),
        datos['actividad'],
        datos['contratista'],
        datos['subcontratista'],
        datos['zafra'],
        datos['fincaLote'],
        datos['procedencia'],
        datos['placa'],
        datos['transportista'],
        datos['lineaRuta'],
        datos['kilometraje'],
        datos['cantidadPersonas'],
        datos['descripcion'],
        datos['supervisor'],
        datos['nombreSupervisor'],
        datos['creadoPor'],
        datos['editadoPor'],
      ]
          .where(
            (valor) => valor != null,
          )
          .map(
            (valor) => valor
                .toString()
                .toLowerCase(),
          )
          .join(' ');

      if (!textoCompleto.contains(
        busqueda,
      )) {
        return false;
      }
    }

    // ----------------------------------------------------------
    // ACTIVIDAD
    // ----------------------------------------------------------

    if (_actividadSeleccionada != null &&
        _actividadSeleccionada!.isNotEmpty) {
      final actividad =
          datos['actividad']?.toString() ?? '';

      if (actividad !=
          _actividadSeleccionada) {
        return false;
      }
    }

    // ----------------------------------------------------------
    // SUPERVISOR
    // ----------------------------------------------------------

    if (_supervisorSeleccionado != null &&
        _supervisorSeleccionado!.isNotEmpty) {
      final supervisor =
          _obtenerSupervisor(datos);

      if (supervisor !=
          _supervisorSeleccionado) {
        return false;
      }
    }

    // ----------------------------------------------------------
    // FECHA INICIO
    // ----------------------------------------------------------

    final fechaRegistro =
        _convertirFecha(
      datos['fecha'],
    );

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

    // ----------------------------------------------------------
    // FECHA FIN
    // ----------------------------------------------------------

    if (_fechaFin != null) {
      final fin = DateTime(
        _fechaFin!.year,
        _fechaFin!.month,
        _fechaFin!.day,
        23,
        59,
        59,
      );

      if (fechaRegistro == null ||
          fechaRegistro.isAfter(fin)) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // REGISTROS FILTRADOS
  // ============================================================

  List<Map<String, dynamic>> _registrosFiltrados() {
    return _registros
        .where(_cumpleFiltros)
        .toList();
  }

  // ============================================================
  // COLUMNAS F-OA-225
  // ============================================================

  List<String> _columnasF225() {
    return [
      'Fecha',
      'Supervisor',
      'Actividad',
      'Contratista',
      'Zafra',
      'Finca / Lote',
      'Procedencia',
      'Placa',
      'Transportista',
      'Línea / Ruta',
      'Kilometraje (KM)',
      'Descripción / Observaciones',
    ];
  }

  // ============================================================
  // COLUMNAS F-066 TRANSPORTE
  // ============================================================

  List<String> _columnasF066() {
    return [
      'Fecha',
      'Supervisor',
      'Actividad',
      'Contratista',
      'Subcontratista',
      'Zafra',
      'Finca / Lote',
      'Procedencia',
      'Placa',
      'Transportista',
      'Línea / Ruta',
      'Kilometraje (KM)',
      'Cantidad de Personas',
      'Descripción / Observaciones',
    ];
  }

  // ============================================================
  // COLUMNAS F-066 AGUA
  // ============================================================

  List<String> _columnasF066Agua() {
    return [
      'Fecha',
      'Supervisor',
      'Actividad',
      'Contratista',
      'Subcontratista',
      'Zafra',
      'Finca / Lote',
      'Procedencia',
      'Placa',
      'Transportista',
      'Línea / Ruta',
      'Kilometraje (KM)',
      'Descripción / Observaciones',
    ];
  }

  // ============================================================
  // COLUMNAS GENERALES
  // ============================================================

  List<String> _columnasGenerales() {
    return [
      'Fecha',
      'Supervisor',
      'Formato',
      'Actividad',
      'Contratista',
      'Subcontratista',
      'Zafra',
      'Finca / Lote',
      'Procedencia',
      'Placa',
      'Transportista',
      'Línea / Ruta',
      'Kilometraje (KM)',
      'Cantidad de Personas',
      'Descripción / Observaciones',
    ];
  }

  // ============================================================
  // COLUMNAS SEGÚN FORMATO
  // ============================================================

  List<String> _columnasReporte(
    String formato,
  ) {
    switch (formato) {
      case 'F-OA-225':
        return _columnasF225();

      case 'F-066 Transporte':
        return _columnasF066();

      case 'F-066 Transporte de Agua':
        return _columnasF066Agua();

      default:
        return _columnasGenerales();
    }
  }

  // ============================================================
  // VALOR DE COLUMNA
  // ============================================================

  String _valorColumna(
    String columna,
    Map<String, dynamic> registro,
  ) {
    final datos =
        Map<String, dynamic>.from(
      registro['datos'] ?? {},
    );

    switch (columna) {
      case 'Fecha':
        return _formatearFecha(
          datos['fecha'],
        );

      case 'Supervisor':
        return _obtenerSupervisor(
          datos,
        );

      case 'Formato':
        return _nombreFormato(
          registro['coleccion']?.toString() ?? '',
          datos,
        );

      case 'Actividad':
        return _texto(
          datos['actividad'],
        );

      case 'Contratista':
        return _texto(
          datos['contratista'],
        );

      case 'Subcontratista':
        return _texto(
          datos['subcontratista'],
        );

      case 'Zafra':
        return _texto(
          datos['zafra'],
        );

      case 'Finca / Lote':
        return _texto(
          datos['fincaLote'],
        );

      case 'Procedencia':
        return _texto(
          datos['procedencia'],
        );

      case 'Placa':
        return _texto(
          datos['placa'],
        );

      case 'Transportista':
        return _texto(
          datos['transportista'],
        );

      case 'Línea / Ruta':
        return _texto(
          datos['lineaRuta'],
        );

      case 'Kilometraje (KM)':
        return _texto(
          datos['kilometraje'],
        );

      case 'Cantidad de Personas':
        return _texto(
          datos['cantidadPersonas'],
        );

      case 'Descripción / Observaciones':
        return _texto(
          datos['descripcion'],
        );

      default:
        return '-';
    }
  }

  // ============================================================
  // SELECCIONAR FECHAS
  // ============================================================

  Future<void> _seleccionarRangoFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      currentDate: DateTime.now(),
      initialDateRange:
          _fechaInicio != null &&
                  _fechaFin != null
              ? DateTimeRange(
                  start: _fechaInicio!,
                  end: _fechaFin!,
                )
              : null,
      helpText:
          'Selecciona el rango de fechas',
      cancelText: 'CANCELAR',
      confirmText: 'APLICAR',
      fieldStartLabelText: 'Desde',
      fieldEndLabelText: 'Hasta',
    );

    if (rango == null) {
      return;
    }

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

  // ============================================================
  // TEXTO DEL RANGO
  // ============================================================

  String _textoRango() {
    if (_fechaInicio == null ||
        _fechaFin == null) {
      return 'Todas las fechas';
    }

    return '${_formatearFecha(_fechaInicio)}'
        '  →  '
        '${_formatearFecha(_fechaFin)}';
  }

  // ============================================================
  // LIMPIAR FILTROS
  // ============================================================

  void _limpiarFiltros() {
    _busquedaController.clear();

    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _actividadSeleccionada = null;
      _supervisorSeleccionado = null;
      _formatoSeleccionado = 'Todos';
      _busqueda = '';
    });
  }

  // ============================================================
  // EXPORTAR EXCEL
  // ============================================================

  Future<void> _exportarExcel() async {
    final registros =
        _registrosFiltrados();

    if (registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay registros para exportar.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(
            color: colorVerde,
          ),
        );
      },
    );

    try {
      final excel =
          excel_pkg.Excel.createExcel();

      // ========================================================
      // IMPORTANTE
      // SI ES "TODOS", TODO VA A UNA SOLA HOJA
      // ========================================================

      final nombreHoja =
          _formatoSeleccionado == 'Todos'
              ? 'Reporte General'
              : _nombreHojaExcel(
                  _formatoSeleccionado,
                );

      excel.rename(
        'Sheet1',
        nombreHoja,
      );

      final sheet = excel[nombreHoja];

      _construirHojaExcel(
        sheet,
        _formatoSeleccionado,
        registros,
      );

      final bytes = excel.save();

      if (bytes == null) {
        throw Exception(
          'No se pudo generar el archivo Excel.',
        );
      }

      final fechaArchivo =
          DateTime.now()
              .millisecondsSinceEpoch;

      final nombreArchivo =
          'Reporte_AZUNOSA_$fechaArchivo.xlsx';

      final blob = html.Blob(
        [
          bytes,
        ],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      final url =
          html.Url.createObjectUrlFromBlob(
        blob,
      );

      html.AnchorElement(
        href: url,
      )
        ..setAttribute(
          'download',
          nombreArchivo,
        )
        ..click();

      html.Url.revokeObjectUrl(url);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Excel generado correctamente. '
            '${registros.length} registros exportados.',
          ),
          backgroundColor: colorVerde,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al generar Excel: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // NOMBRE HOJA
  // ============================================================

  String _nombreHojaExcel(
    String formato,
  ) {
    switch (formato) {
      case 'F-OA-225':
        return 'F-OA-225';

      case 'F-066 Transporte':
        return 'F-066 Transporte';

      case 'F-066 Transporte de Agua':
        return 'F-066 Agua';

      default:
        return 'Reporte General';
    }
  }

  // ============================================================
  // CONSTRUIR HOJA EXCEL
  // ============================================================

  void _construirHojaExcel(
    excel_pkg.Sheet sheet,
    String formato,
    List<Map<String, dynamic>> registros,
  ) {
    // ----------------------------------------------------------
    // COLUMNAS
    // ----------------------------------------------------------

    final columnas =
        formato == 'Todos'
            ? _columnasGenerales()
            : _columnasReporte(
                formato,
              );

    final ultimaColumna =
        columnas.length - 1;

    final ultimaFila =
        registros.length + 4;

    // ----------------------------------------------------------
    // CONFIGURACIÓN
    // ----------------------------------------------------------

    sheet.showGridLines = false;

    sheet.zoom = 90;

    // ==========================================================
    // AZUNOSA
    // ==========================================================

    sheet.merge(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 0,
      ),
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: ultimaColumna,
        rowIndex: 0,
      ),
      customValue:
          excel_pkg.TextCellValue(
        'AZUNOSA',
      ),
    );

    sheet.setMergedCellStyle(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 0,
      ),
      _estiloTitulo(),
    );

    // ==========================================================
    // REPORTE
    // ==========================================================

    final tituloReporte =
        formato == 'Todos'
            ? 'REPORTE GENERAL'
            : 'REPORTE $formato';

    sheet.merge(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 1,
      ),
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: ultimaColumna,
        rowIndex: 1,
      ),
      customValue:
          excel_pkg.TextCellValue(
        tituloReporte,
      ),
    );

    sheet.setMergedCellStyle(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 1,
      ),
      _estiloSubtitulo(),
    );

    // ==========================================================
    // PERÍODO
    // ==========================================================

    sheet.merge(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 2,
      ),
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: ultimaColumna,
        rowIndex: 2,
      ),
      customValue:
          excel_pkg.TextCellValue(
        'Período: ${_textoRango()}',
      ),
    );

    sheet.setMergedCellStyle(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 2,
      ),
      _estiloPeriodo(),
    );

    // ==========================================================
    // TOTAL
    // ==========================================================

    sheet.merge(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 3,
      ),
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: ultimaColumna,
        rowIndex: 3,
      ),
      customValue:
          excel_pkg.TextCellValue(
        'Total de registros: ${registros.length}',
      ),
    );

    sheet.setMergedCellStyle(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 3,
      ),
      _estiloResumen(),
    );

    // ==========================================================
    // ENCABEZADOS
    // ==========================================================

    for (int columna = 0;
        columna < columnas.length;
        columna++) {
      final index =
          excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: columna,
        rowIndex: 4,
      );

      sheet.updateCell(
        index,
        excel_pkg.TextCellValue(
          columnas[columna],
        ),
        cellStyle:
            _estiloEncabezado(),
      );
    }

    // ==========================================================
    // TODOS LOS REGISTROS
    // ==========================================================

    for (int fila = 0;
        fila < registros.length;
        fila++) {
      final registro =
          registros[fila];

      for (int columna = 0;
          columna < columnas.length;
          columna++) {
        final valor =
            _valorColumna(
          columnas[columna],
          registro,
        );

        final index =
            excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: columna,
          rowIndex: fila + 5,
        );

        sheet.updateCell(
          index,
          excel_pkg.TextCellValue(
            valor,
          ),
          cellStyle:
              _estiloDato(),
        );
      }
    }

    // ==========================================================
    // FILTROS DE EXCEL
    // ==========================================================

    sheet.setAutoFilter(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 4,
      ),
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: ultimaColumna,
        rowIndex: ultimaFila,
      ),
    );

    // ==========================================================
    // CONGELAR FILAS
    // ==========================================================

    sheet.freezePanes(
      rows: 5,
      columns: 1,
    );

    // ==========================================================
    // ALTURAS
    // ==========================================================

    sheet.setRowHeight(
      0,
      30,
    );

    sheet.setRowHeight(
      1,
      26,
    );

    sheet.setRowHeight(
      2,
      22,
    );

    sheet.setRowHeight(
      3,
      22,
    );

    sheet.setRowHeight(
      4,
      36,
    );

    // ==========================================================
    // ANCHOS
    // ==========================================================

    for (int columna = 0;
        columna < columnas.length;
        columna++) {
      final nombre =
          columnas[columna];

      double ancho = 18;

      switch (nombre) {
        case 'Fecha':
          ancho = 14;
          break;

        case 'Supervisor':
          ancho = 24;
          break;

        case 'Formato':
          ancho = 25;
          break;

        case 'Actividad':
          ancho = 25;
          break;

        case 'Contratista':
          ancho = 24;
          break;

        case 'Subcontratista':
          ancho = 24;
          break;

        case 'Zafra':
          ancho = 12;
          break;

        case 'Finca / Lote':
          ancho = 25;
          break;

        case 'Procedencia':
          ancho = 24;
          break;

        case 'Placa':
          ancho = 16;
          break;

        case 'Transportista':
          ancho = 25;
          break;

        case 'Línea / Ruta':
          ancho = 24;
          break;

        case 'Kilometraje (KM)':
          ancho = 18;
          break;

        case 'Cantidad de Personas':
          ancho = 22;
          break;

        case 'Descripción / Observaciones':
          ancho = 40;
          break;
      }

      sheet.setColumnWidth(
        columna,
        ancho,
      );
    }

    // ==========================================================
    // ÁREA DE IMPRESIÓN
    // ==========================================================

    sheet.setPrintArea(
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: 0,
      ),
      excel_pkg.CellIndex.indexByColumnRow(
        columnIndex: ultimaColumna,
        rowIndex: ultimaFila,
      ),
    );

    sheet.setPrintTitleRows(
      0,
      4,
    );

    // ==========================================================
    // CONFIGURACIÓN DE PÁGINA
    // ==========================================================

    sheet.pageSetup =
        const excel_pkg.PageSetup(
      orientation:
          excel_pkg.PageOrientation.landscape,
      fitToWidth: 1,
      fitToHeight: 0,
      printGridLines: false,
      printHeadings: false,
    );
  }

  // ============================================================
  // ESTILO TÍTULO
  // ============================================================

  excel_pkg.CellStyle _estiloTitulo() {
    return excel_pkg.CellStyle(
      fontColorHex:
          excel_pkg.ExcelColor.white,
      backgroundColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#0F1E36',
      ),
      fontSize: 18,
      bold: true,
      horizontalAlign:
          excel_pkg.HorizontalAlign.Center,
      verticalAlign:
          excel_pkg.VerticalAlign.Center,
      textWrapping:
          excel_pkg.TextWrapping.WrapText,
    );
  }

  // ============================================================
  // ESTILO SUBTÍTULO
  // ============================================================

  excel_pkg.CellStyle _estiloSubtitulo() {
    return excel_pkg.CellStyle(
      fontColorHex:
          excel_pkg.ExcelColor.white,
      backgroundColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#2E7D32',
      ),
      fontSize: 14,
      bold: true,
      horizontalAlign:
          excel_pkg.HorizontalAlign.Center,
      verticalAlign:
          excel_pkg.VerticalAlign.Center,
      textWrapping:
          excel_pkg.TextWrapping.WrapText,
    );
  }

  // ============================================================
  // ESTILO PERÍODO
  // ============================================================

  excel_pkg.CellStyle _estiloPeriodo() {
    return excel_pkg.CellStyle(
      fontColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#333333',
      ),
      backgroundColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#E8F5E9',
      ),
      fontSize: 11,
      bold: true,
      horizontalAlign:
          excel_pkg.HorizontalAlign.Center,
      verticalAlign:
          excel_pkg.VerticalAlign.Center,
      textWrapping:
          excel_pkg.TextWrapping.WrapText,
    );
  }

  // ============================================================
  // ESTILO RESUMEN
  // ============================================================

  excel_pkg.CellStyle _estiloResumen() {
    return excel_pkg.CellStyle(
      fontColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#444444',
      ),
      backgroundColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#F5F7FA',
      ),
      fontSize: 11,
      bold: true,
      horizontalAlign:
          excel_pkg.HorizontalAlign.Left,
      verticalAlign:
          excel_pkg.VerticalAlign.Center,
    );
  }

  // ============================================================
  // ESTILO ENCABEZADO
  // ============================================================

  excel_pkg.CellStyle _estiloEncabezado() {
    return excel_pkg.CellStyle(
      fontColorHex:
          excel_pkg.ExcelColor.white,
      backgroundColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#2E7D32',
      ),
      fontSize: 11,
      bold: true,
      horizontalAlign:
          excel_pkg.HorizontalAlign.Center,
      verticalAlign:
          excel_pkg.VerticalAlign.Center,
      textWrapping:
          excel_pkg.TextWrapping.WrapText,
      bottomBorder:
          excel_pkg.Border(
        borderStyle:
            excel_pkg.BorderStyle.Thin,
        borderColorHex:
            excel_pkg.ExcelColor.white,
      ),
    );
  }

  // ============================================================
  // ESTILO DATOS
  // ============================================================

  excel_pkg.CellStyle _estiloDato() {
    return excel_pkg.CellStyle(
      fontColorHex:
          excel_pkg.ExcelColor.fromHexString(
        '#222222',
      ),
      backgroundColorHex:
          excel_pkg.ExcelColor.white,
      fontSize: 10,
      verticalAlign:
          excel_pkg.VerticalAlign.Center,
      textWrapping:
          excel_pkg.TextWrapping.WrapText,
      bottomBorder:
          excel_pkg.Border(
        borderStyle:
            excel_pkg.BorderStyle.Thin,
        borderColorHex:
            excel_pkg.ExcelColor.fromHexString(
          '#D9D9D9',
        ),
      ),
    );
  }

  // ============================================================
  // SELECTOR
  // ============================================================

  Widget _selector({
    required String titulo,
    required IconData icono,
    required String valorActual,
    required List<String> opciones,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: valorActual,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: titulo,
        prefixIcon: Icon(
          icono,
          color: colorVerde,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
      ),
      items: opciones.map(
        (opcion) {
          return DropdownMenuItem<String>(
            value: opcion,
            child: Text(
              opcion,
              overflow:
                  TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),
      onChanged: onChanged,
    );
  }

  // ============================================================
  // FILTROS
  // ============================================================

  Widget _construirFiltros() {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.05),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colorVerdeClaro,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: const Icon(
                  Icons.filter_alt,
                  color: colorVerde,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Text(
                  'Filtros del reporte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color: colorAzunosa,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    _limpiarFiltros,
                icon: const Icon(
                  Icons.clear_all,
                ),
                label: const Text(
                  'Limpiar',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ----------------------------------------------------
          // BUSCADOR
          // ----------------------------------------------------

          TextField(
            controller:
                _busquedaController,
            onChanged: (valor) {
              setState(() {
                _busqueda = valor;
              });
            },
            decoration:
                InputDecoration(
              labelText:
                  'Buscar en todos los datos',
              hintText:
                  'Actividad, finca, placa, transportista...',
              prefixIcon:
                  const Icon(
                Icons.search,
                color: colorVerde,
              ),
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
                          ),
                        )
                      : null,
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          // ----------------------------------------------------
          // SELECTORES
          // ----------------------------------------------------

          LayoutBuilder(
            builder:
                (context, constraints) {
              final ancho =
                  constraints.maxWidth;

              final anchoCampo =
                  ancho > 900
                      ? (ancho - 24) / 3
                      : ancho > 600
                          ? (ancho - 12) / 2
                          : ancho;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // FORMATO
                  SizedBox(
                    width: anchoCampo,
                    child: _selector(
                      titulo:
                          'Formato',
                      icono:
                          Icons.description,
                      valorActual:
                          _formatoSeleccionado,
                      opciones: const [
                        'Todos',
                        'F-OA-225',
                        'F-066 Transporte',
                        'F-066 Transporte de Agua',
                      ],
                      onChanged:
                          (valor) {
                        setState(() {
                          _formatoSeleccionado =
                              valor ??
                                  'Todos';
                        });
                      },
                    ),
                  ),

                  // ACTIVIDAD
                  SizedBox(
                    width: anchoCampo,
                    child: _selector(
                      titulo:
                          'Actividad',
                      icono:
                          Icons.agriculture,
                      valorActual:
                          _actividadSeleccionada ??
                              'Todas',
                      opciones: [
                        'Todas',
                        ..._actividades,
                      ],
                      onChanged:
                          (valor) {
                        setState(() {
                          _actividadSeleccionada =
                              valor ==
                                      'Todas'
                                  ? null
                                  : valor;
                        });
                      },
                    ),
                  ),

                  // SUPERVISOR
                  SizedBox(
                    width: anchoCampo,
                    child: _selector(
                      titulo:
                          'Supervisor',
                      icono:
                          Icons.person,
                      valorActual:
                          _supervisorSeleccionado ??
                              'Todos',
                      opciones: [
                        'Todos',
                        ..._supervisores,
                      ],
                      onChanged:
                          (valor) {
                        setState(() {
                          _supervisorSeleccionado =
                              valor ==
                                      'Todos'
                                  ? null
                                  : valor;
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(
            height: 14,
          ),

          // ----------------------------------------------------
          // FECHAS
          // ----------------------------------------------------

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _seleccionarRangoFechas,
                  icon: const Icon(
                    Icons.date_range,
                    color: colorVerde,
                  ),
                  label: Text(
                    _textoRango(),
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 15,
                      horizontal: 14,
                    ),
                    side: BorderSide(
                      color: Colors
                          .grey
                          .shade300,
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
                ),
              ),
              if (_fechaInicio != null ||
                  _fechaFin != null)
                IconButton(
                  tooltip:
                      'Quitar fechas',
                  onPressed: () {
                    setState(() {
                      _fechaInicio =
                          null;
                      _fechaFin = null;
                    });
                  },
                  icon:
                      const Icon(
                    Icons.close,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANCHO DE COLUMNAS DE LA TABLA
  // ============================================================

  double _anchoColumna(
    String columna,
  ) {
    switch (columna) {
      case 'Fecha':
        return 100;

      case 'Supervisor':
        return 170;

      case 'Formato':
        return 190;

      case 'Actividad':
        return 190;

      case 'Contratista':
        return 180;

      case 'Subcontratista':
        return 180;

      case 'Zafra':
        return 100;

      case 'Finca / Lote':
        return 180;

      case 'Procedencia':
        return 180;

      case 'Placa':
        return 110;

      case 'Transportista':
        return 180;

      case 'Línea / Ruta':
        return 180;

      case 'Kilometraje (KM)':
        return 130;

      case 'Cantidad de Personas':
        return 150;

      case 'Descripción / Observaciones':
        return 280;

      default:
        return 160;
    }
  }

  // ============================================================
  // TABLA DE PREVISUALIZACIÓN
  // ============================================================

  Widget _construirTabla() {
    final filtrados =
        _registrosFiltrados();

    // ----------------------------------------------------------
    // SI ES TODOS, MOSTRAR COLUMNAS GENERALES
    // ----------------------------------------------------------

    final columnas =
        _formatoSeleccionado == 'Todos'
            ? _columnasGenerales()
            : _columnasReporte(
                _formatoSeleccionado,
              );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.05),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ----------------------------------------------------
          // CABECERA
          // ----------------------------------------------------

          Padding(
            padding:
                const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart,
                  color: colorVerde,
                ),
                const SizedBox(
                  width: 10,
                ),
                const Expanded(
                  child: Text(
                    'Previsualización de datos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                      color: colorAzunosa,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colorVerdeClaro,
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child: Text(
                    '${filtrados.length} registros',
                    style:
                        const TextStyle(
                      color: colorVerde,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          // ----------------------------------------------------
          // SIN RESULTADOS
          // ----------------------------------------------------

          if (filtrados.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.all(60),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Text(
                    'No se encontraron registros',
                    style:
                        TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Colors.grey,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Prueba modificando los filtros.',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
                ],
              ),
            )

          // ----------------------------------------------------
          // TABLA
          // ----------------------------------------------------

          else
            SizedBox(
              height: 500,
              child: Scrollbar(
                child:
                    SingleChildScrollView(
                  scrollDirection:
                      Axis.vertical,
                  child:
                      SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal,
                    child: DataTable(
                      headingRowHeight:
                          55,
                      dataRowMinHeight:
                          52,
                      dataRowMaxHeight:
                          82,
                      columnSpacing: 22,
                      horizontalMargin:
                          18,
                      headingRowColor:
                          WidgetStateProperty
                              .all(
                        colorAzunosa,
                      ),
                      columns:
                          columnas.map(
                        (columna) {
                          return DataColumn(
                            label: Text(
                              columna,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      rows:
                          filtrados.map(
                        (registro) {
                          return DataRow(
                            cells:
                                columnas.map(
                              (columna) {
                                return DataCell(
                                  SizedBox(
                                    width:
                                        _anchoColumna(
                                      columna,
                                    ),
                                    child:
                                        Text(
                                      _valorColumna(
                                        columna,
                                        registro,
                                      ),
                                      maxLines:
                                          3,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ),
              ),
            ),

          // ----------------------------------------------------
          // BOTÓN EXPORTAR
          // ----------------------------------------------------

          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      filtrados.isEmpty
                          ? null
                          : _exportarExcel,
                  icon:
                      const Icon(
                    Icons.file_download,
                  ),
                  label:
                      const Text(
                    'Exportar a Excel',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        colorVerde,
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 22,
                      vertical: 15,
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
                ),
              ],
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
      appBar: AppBar(
        backgroundColor:
            colorAzunosa,
        foregroundColor:
            Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.assessment,
            ),
            SizedBox(
              width: 10,
            ),
            Text(
              'Módulo de Reportería',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: _cargando
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: colorVerde,
              ),
            )
          : RefreshIndicator(
              color: colorVerde,
              onRefresh:
                  _cargarDatos,
              child:
                  SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    // ------------------------------------------------
                    // ENCABEZADO
                    // ------------------------------------------------

                    Container(
                      padding:
                          const EdgeInsets
                              .all(22),
                      decoration:
                          BoxDecoration(
                        gradient:
                            const LinearGradient(
                          colors: [
                            colorAzunosa,
                            Color(
                              0xFF19335C,
                            ),
                          ],
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                      child:
                          const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Reportes y análisis',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  26,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          Text(
                            'Consulta, filtra y exporta la información registrada.',
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                              fontSize:
                                  14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ------------------------------------------------
                    // FILTROS
                    // ------------------------------------------------

                    _construirFiltros(),

                    const SizedBox(
                      height: 18,
                    ),

                    // ------------------------------------------------
                    // TABLA
                    // ------------------------------------------------

                    _construirTabla(),
                  ],
                ),
              ),
            ),
    );
  }
}