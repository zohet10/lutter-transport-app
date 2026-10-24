import 'package:flutter/material.dart';

import 'package:transporte/formulario_066.dart';
import 'formulario_225.dart';
import 'SubContratista.dart';
import 'RegistroUsuario.dart';
import 'login.dart';
import 'PantallaRegistros.dart';
import 'reporte.dart';
import 'datosfinca.dart';
import 'CalcularKm.dart';
import 'actividad.dart';
import 'Formato066TransporteAgua.dart';

import 'autorizaciones/solicitudes_edicion_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.userData,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // ============================================================
  // COLORES ZAFI
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);

  // Verde manzana muy suave
  static const Color colorFondo = Color(0xFFF1F8F0);

  static const Color colorBorde = Color(0xFFD5E2D3);

  // ============================================================
  // DATOS DEL USUARIO
  // ============================================================

  String get _nombreUsuario {
    return widget.userData['nombre_completo']?.toString() ??
        widget.userData['nombre']?.toString() ??
        'Usuario';
  }

  String get _rolUsuario {
    return widget.userData['rol']?.toString() ?? 'Usuario';
  }

  // ============================================================
  // ROL NORMALIZADO
  // ============================================================

  String _rolNormalizado() {
    String rol =
        widget.userData['rol']?.toString().trim().toLowerCase() ?? '';

    rol = rol
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    return rol;
  }

  // ============================================================
  // ROLES
  // ============================================================

  bool get _esAdministrador {
    return _rolNormalizado() == 'administrador';
  }

  bool get _esAdministradorAgricola {
    final rol = _rolNormalizado();

    return rol == 'administracion agricola' ||
        rol == 'administrador agricola';
  }

  bool get _esJefeZona {
    final rol = _rolNormalizado();

    return rol == 'jefe de zona' ||
        rol == 'jefe zona' ||
        rol == 'jefe';
  }

  bool get _esSupervisor {
    return _rolNormalizado() == 'supervisor';
  }

  // ============================================================
  // PERMISOS
  // ============================================================

  bool _tieneAcceso(String nombreModulo) {
    if (_esAdministrador) {
      return true;
    }

    final Map<dynamic, dynamic>? permisos =
        widget.userData['permisos'];

    if (permisos != null &&
        permisos.containsKey(nombreModulo)) {
      return permisos[nombreModulo] == true;
    }

    return false;
  }

  // ============================================================
  // OPCIONES DEL SISTEMA
  // ============================================================

  List<Map<String, dynamic>> get _opcionesPermitidas {
    final List<Map<String, dynamic>> lista = [
      {
        'index': 0,
        'titulo': 'Inicio',
        'icono': Icons.dashboard_outlined,
        'modulo': 'Inicio',
        'descripcion': 'Panel principal',
      },
    ];

    // ==========================================================
    // F-OA-225
    // ==========================================================

    if (_tieneAcceso(
      'Control de Transporte (F-OA-225)',
    )) {
      lista.add({
        'index': 1,
        'titulo': 'F-OA-225',
        'icono': Icons.description_outlined,
        'modulo': 'Control de Transporte (F-OA-225)',
        'descripcion': 'Control de transporte',
      });
    }

    // ==========================================================
    // F-OA-066
    // ==========================================================

    if (_tieneAcceso(
      'Ruta de Transporte (F-OA-066)',
    )) {
      lista.add({
        'index': 2,
        'titulo': 'F-OA-066',
        'icono': Icons.route_outlined,
        'modulo': 'Ruta de Transporte (F-OA-066)',
        'descripcion': 'Ruta de transporte',
      });
    }

    // ==========================================================
    // TRANSPORTISTA
    // ==========================================================

    if (_tieneAcceso('Subcontratista')) {
      lista.add({
        'index': 3,
        'titulo': 'Transportista',
        'icono': Icons.local_shipping_outlined,
        'modulo': 'Subcontratista',
        'descripcion': 'Gestión de transportistas',
      });
    }

    // ==========================================================
    // USUARIO
    // ==========================================================

    if (_tieneAcceso('Supervisor')) {
      lista.add({
        'index': 4,
        'titulo': 'Usuario',
        'icono': Icons.people_outline,
        'modulo': 'Supervisor',
        'descripcion': 'Usuarios y supervisores',
      });
    }

    // ==========================================================
    // DATOS DE FINCA
    // ==========================================================

    if (_tieneAcceso('Datos de Finca')) {
      lista.add({
        'index': 5,
        'titulo': 'Datos de Finca',
        'icono': Icons.map_outlined,
        'modulo': 'Datos de Finca',
        'descripcion': 'Información de fincas',
      });
    }

    // ==========================================================
    // REGISTROS
    // ==========================================================

    if (_tieneAcceso('Registros Generales')) {
      lista.add({
        'index': 6,
        'titulo': 'Registros',
        'icono': Icons.fact_check_outlined,
        'modulo': 'Registros Generales',
        'descripcion': 'Consulta de registros',
      });
    }

    // ==========================================================
    // REPORTES
    // ==========================================================

    if (_tieneAcceso('Reportes y Estadísticas')) {
      lista.add({
        'index': 7,
        'titulo': 'Reportes',
        'icono': Icons.bar_chart_outlined,
        'modulo': 'Reportes y Estadísticas',
        'descripcion': 'Reportes y estadísticas',
      });
    }

    // ==========================================================
    // CALCULAR RUTA
    // ==========================================================

    if (_tieneAcceso(
      'Control de Transporte (F-OA-225)',
    )) {
      lista.add({
        'index': 8,
        'titulo': 'Calcular Ruta',
        'icono': Icons.directions_outlined,
        'modulo': 'Control de Transporte (F-OA-225)',
        'descripcion': 'Cálculo de rutas',
      });
    }

    // ==========================================================
    // ACTIVIDAD / LABOR
    // ==========================================================

    if (_tieneAcceso('Registros Generales') ||
        _tieneAcceso('Actividad / Labor')) {
      lista.add({
        'index': 9,
        'titulo': 'Actividad / Labor',
        'icono': Icons.agriculture_outlined,
        'modulo': 'Registros Generales',
        'descripcion': 'Actividades agrícolas',
      });
    }

    // ==========================================================
    // F-OA-066 AGUA
    // ==========================================================

    if (_tieneAcceso(
      'Ruta de Transporte (F-OA-066)',
    )) {
      lista.add({
        'index': 10,
        'titulo': 'F-OA-066 Agua',
        'icono': Icons.water_drop_outlined,
        'modulo': 'Ruta de Transporte (F-OA-066)',
        'descripcion': 'Transporte de agua',
      });
    }

    // ==========================================================
    // SOLICITUDES DE EDICIÓN
    // ==========================================================

    if (_esAdministrador || _esJefeZona) {
      lista.add({
        'index': 11,
        'titulo': 'Solicitudes de edición',
        'icono': Icons.assignment_outlined,
        'modulo': 'Solicitudes de edición',
        'descripcion': 'Autorizaciones de edición',
      });
    }

    return lista;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla =
        MediaQuery.of(context).size.width;

    final bool esDesktop =
        anchoPantalla >= 850;

    final bool indiceValido =
        _opcionesPermitidas.any(
      (opcion) =>
          opcion['index'] == _selectedIndex,
    );

    if (!indiceValido) {
      _selectedIndex = 0;
    }

    // ==========================================================
    // DESKTOP
    // ==========================================================

    if (esDesktop) {
      return Scaffold(
        backgroundColor: colorFondo,

        body: Row(
          children: [
            // ==================================================
            // MENÚ LATERAL
            // ==================================================

            SizedBox(
              width: 250,

              child: Container(
                color: Colors.white,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    _buildHeaderMenu(),

                    Container(
                      height: 1,
                      color: colorBorde,
                    ),

                    Expanded(
                      child: ListView(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 8,
                        ),

                        children:
                            _opcionesPermitidas
                                .map(
                          (opcion) {
                            return _buildMenuItem(
                              opcion['index'],
                              opcion['titulo'],
                              opcion['icono'],
                            );
                          },
                        ).toList(),
                      ),
                    ),

                    Container(
                      height: 1,
                      color: colorBorde,
                    ),

                    _buildLogoutTile(),

                    const SizedBox(
                      height: 8,
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // CONTENIDO
            // ==================================================

            Expanded(
              child: _obtenerVistaDerecha(),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // MÓVIL / TABLET
    // ==========================================================

    return Scaffold(
      backgroundColor: colorFondo,

      appBar: AppBar(
        elevation: 0,

        backgroundColor: colorPrincipal,

        foregroundColor: Colors.white,

        title: const Text(
          'ZAFI Field Management System',

          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      drawer: Drawer(
        backgroundColor: Colors.white,

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            _buildHeaderMenu(),

            Container(
              height: 1,
              color: colorBorde,
            ),

            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 8,
                ),

                children:
                    _opcionesPermitidas
                        .map(
                  (opcion) {
                    return _buildMobileMenuItem(
                      opcion['index'],
                      opcion['titulo'],
                      opcion['icono'],
                    );
                  },
                ).toList(),
              ),
            ),

            Container(
              height: 1,
              color: colorBorde,
            ),

            _buildLogoutTile(),

            const SizedBox(
              height: 8,
            ),
          ],
        ),
      ),

      body: _obtenerVistaDerecha(),
    );
  }

  // ============================================================
  // HEADER DEL MENÚ LATERAL
  // ============================================================

  Widget _buildHeaderMenu() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(
        18,
        22,
        18,
        18,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(
                  color: colorVerde,

                  borderRadius:
                      BorderRadius.circular(11),
                ),

                child: const Icon(
                  Icons.agriculture_outlined,

                  color: Colors.white,

                  size: 23,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Expanded(
                child: Text(
                  'ZAFI',

                  style: TextStyle(
                    color: colorPrincipal,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          const Text(
            'Field Management System',

            style: TextStyle(
              color: colorPrincipal,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          const Text(
            'Gestión de operaciones agrícolas',

            style: TextStyle(
              color: Colors.black45,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ITEM MENÚ DESKTOP
  // ============================================================

  Widget _buildMenuItem(
    int index,
    String title,
    IconData icon,
  ) {
    final bool seleccionado =
        _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius:
              BorderRadius.circular(9),

          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },

          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 180,
            ),

            padding:
                const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 10,
            ),

            decoration:
                BoxDecoration(
              color: seleccionado
                  ? colorVerde.withOpacity(0.09)
                  : Colors.transparent,

              borderRadius:
                  BorderRadius.circular(9),

              border: seleccionado
                  ? Border.all(
                      color: colorVerde
                          .withOpacity(0.18),
                    )
                  : null,
            ),

            child: Row(
              children: [
                Icon(
                  icon,

                  size: 20,

                  color: seleccionado
                      ? colorVerde
                      : Colors.black45,
                ),

                const SizedBox(
                  width: 11,
                ),

                Expanded(
                  child: Text(
                    title,

                    style: TextStyle(
                      fontSize: 12.5,

                      fontWeight:
                          seleccionado
                              ? FontWeight.w700
                              : FontWeight.w500,

                      color: seleccionado
                          ? colorPrincipal
                          : Colors.black87,
                    ),

                    maxLines: 2,

                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ITEM MENÚ MÓVIL
  // ============================================================

  Widget _buildMobileMenuItem(
    int index,
    String title,
    IconData icon,
  ) {
    final bool seleccionado =
        _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 1,
      ),

      child: ListTile(
        dense: true,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 11,
        ),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(9),
        ),

        leading: Icon(
          icon,

          size: 21,

          color: seleccionado
              ? colorVerde
              : Colors.black45,
        ),

        title: Text(
          title,

          style: TextStyle(
            fontSize: 14,

            fontWeight:
                seleccionado
                    ? FontWeight.bold
                    : FontWeight.w500,

            color: seleccionado
                ? colorPrincipal
                : Colors.black87,
          ),
        ),

        tileColor: seleccionado
            ? colorVerde.withOpacity(0.09)
            : null,

        onTap: () {
          setState(() {
            _selectedIndex = index;
          });

          Navigator.pop(context);
        },
      ),
    );
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  Widget _buildLogoutTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
      ),

      child: ListTile(
        dense: true,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(9),
        ),

        leading: const Icon(
          Icons.logout,

          color: Colors.red,

          size: 21,
        ),

        title: const Text(
          'Salir',

          style: TextStyle(
            color: Colors.red,
            fontWeight:
                FontWeight.w600,
            fontSize: 14,
          ),
        ),

        onTap: () {
          Navigator.pushAndRemoveUntil(
            context,

            MaterialPageRoute(
              builder: (context) =>
                  const LoginScreen(),
            ),

            (route) => false,
          );
        },
      ),
    );
  }

  // ============================================================
  // VISTA DE LOS MÓDULOS
  // ============================================================

  Widget _obtenerVistaDerecha() {
    switch (_selectedIndex) {
      case 1:
        return FormularioTransporteScreen(
          usuarioActual:
              widget.userData[
                      'nombre_completo']
                  ?.toString(),
        );

      case 2:
        return Formato066RutaTransporteScreen(
          usuarioActual:
              widget.userData[
                      'nombre_completo']
                  ?.toString(),
        );

      case 3:
        return const FormatoSubcontratistaScreen();

      case 4:
        return const RegistroSupervisorScreen();

      case 5:
        return const MapaFincaScreen();

      case 6:
        return ListaRegistrosAdminScreen(
          userData: widget.userData,
        );

      case 7:
        return const MenuReporteriaScreen();

      case 8:
        return CalcularKmScreen();

      case 9:
        return const ActividadLaborScreen();

      case 10:
        return Formato066TransporteAguaScreen(
          usuarioActual:
              widget.userData[
                      'nombre_completo']
                  ?.toString(),
        );

      case 11:
        return SolicitudesEdicionScreen(
          userData: widget.userData,
        );

      default:
        return _buildMenuPrincipalContent();
    }
  }

  // ============================================================
  // PANTALLA PRINCIPAL
  // ============================================================

  Widget _buildMenuPrincipalContent() {
    final List<Map<String, dynamic>> botonesVisibles =
        _opcionesPermitidas
            .where(
              (opcion) =>
                  opcion['index'] != 0,
            )
            .toList();

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final double ancho =
            constraints.maxWidth;

        // ======================================================
        // RESPONSIVE
        // ======================================================

        final bool movil =
            ancho < 600;

        final bool tablet =
            ancho >= 600 &&
            ancho < 1000;

        int columnas;

        if (movil) {
          columnas = 2;
        } else if (tablet) {
          columnas = 3;
        } else {
          columnas = 4;
        }

        return Container(
          color: colorFondo,

          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                movil ? 12 : 22,
              ),

              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 1150,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      // ==================================================
                      // ENCABEZADO RESPONSIVE
                      // ==================================================

                      _buildEncabezadoPrincipal(
                        movil,
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // ==================================================
                      // TÍTULO MÓDULOS
                      // ==================================================

                      const Text(
                        'Módulos',

                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              colorPrincipal,
                        ),
                      ),

                      const SizedBox(
                        height: 9,
                      ),

                      // ==================================================
                      // GRID
                      // ==================================================

                      GridView.builder(
                        shrinkWrap: true,

                        physics:
                            const NeverScrollableScrollPhysics(),

                        itemCount:
                            botonesVisibles
                                .length,

                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              columnas,

                          crossAxisSpacing:
                              movil
                                  ? 9
                                  : 13,

                          mainAxisSpacing:
                              movil
                                  ? 9
                                  : 13,

                          childAspectRatio:
                              movil
                                  ? 1.08
                                  : tablet
                                      ? 1.25
                                      : 1.35,
                        ),

                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final opcion =
                              botonesVisibles[
                                  index];

                          return _buildTarjetaModulo(
                            codigo:
                                opcion[
                                    'titulo'],

                            icono:
                                opcion[
                                    'icono'],

                            descripcion:
                                opcion[
                                        'descripcion'] ??
                                    '',

                            indexDestino:
                                opcion[
                                    'index'],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ENCABEZADO PRINCIPAL
  // ============================================================

  Widget _buildEncabezadoPrincipal(
    bool movil,
  ) {
    // ==========================================================
    // MÓVIL
    // ==========================================================

    if (movil) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(13),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(12),

          border: Border.all(
            color: colorBorde,
            width: 1,
          ),
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                _buildIconoZafi(
                  38,
                ),

                const SizedBox(
                  width: 10,
                ),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        'ZAFI Field Management System',

                        style:
                            TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              colorPrincipal,
                        ),

                        maxLines: 1,

                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),

                      SizedBox(
                        height: 2,
                      ),

                      Text(
                        'Gestión de operaciones agrícolas',

                        style:
                            TextStyle(
                          fontSize: 9,
                          color:
                              Colors.black45,
                        ),

                        maxLines: 1,

                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            // ================================================
            // USUARIO
            // ================================================

            _buildUsuarioRol(
              compacto: true,
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // TABLET / PC
    // ==========================================================

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(12),

        border: Border.all(
          color: colorBorde,
          width: 1,
        ),
      ),

      child: Row(
        children: [
          _buildIconoZafi(
            42,
          ),

          const SizedBox(
            width: 11,
          ),

          // ==================================================
          // NOMBRE DEL SISTEMA
          // ==================================================

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'ZAFI Field Management System',

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        colorPrincipal,
                  ),

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,
                ),

                SizedBox(
                  height: 2,
                ),

                Text(
                  'Gestión de operaciones agrícolas',

                  style: TextStyle(
                    fontSize: 10,
                    color:
                        Colors.black45,
                  ),

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 15,
          ),

          // ==================================================
          // USUARIO Y ROL
          // ==================================================

          _buildUsuarioRol(
            compacto: false,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ICONO ZAFI
  // ============================================================

  Widget _buildIconoZafi(
    double tamanio,
  ) {
    return Container(
      width: tamanio,
      height: tamanio,

      decoration: BoxDecoration(
        color: colorVerde.withOpacity(
          0.10,
        ),

        borderRadius:
            BorderRadius.circular(10),
      ),

      child: Icon(
        Icons.agriculture_outlined,

        color: colorVerde,

        size: tamanio * 0.57,
      ),
    );
  }

  // ============================================================
  // USUARIO + ROL
  // ============================================================

  Widget _buildUsuarioRol({
    required bool compacto,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 9 : 10,
        vertical: compacto ? 7 : 7,
      ),

      decoration: BoxDecoration(
        color: colorFondo,

        borderRadius:
            BorderRadius.circular(10),

        border: Border.all(
          color: colorBorde,
          width: 1,
        ),
      ),

      child: Row(
        mainAxisSize:
            compacto
                ? MainAxisSize.max
                : MainAxisSize.min,

        children: [
          Container(
            width: 30,
            height: 30,

            decoration: BoxDecoration(
              color:
                  colorVerde.withOpacity(
                0.12,
              ),

              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons.person_outline,

              size: 18,

              color: colorVerde,
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            flex: compacto ? 1 : 0,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              mainAxisSize:
                  MainAxisSize.min,

              children: [
                Text(
                  _nombreUsuario,

                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        colorPrincipal,
                  ),

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  _rolUsuario,

                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        Colors.black45,
                  ),

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TARJETA DE MÓDULO
  // ============================================================

  Widget _buildTarjetaModulo({
    required String codigo,
    required IconData icono,
    required String descripcion,
    required int indexDestino,
  }) {
    return Material(
      color: Colors.white,

      borderRadius:
          BorderRadius.circular(12),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),

        onTap: () {
          setState(() {
            _selectedIndex =
                indexDestino;
          });
        },

        child: Container(
          padding:
              const EdgeInsets.all(9),

          decoration:
              BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(12),

            border: Border.all(
              color: colorBorde,
              width: 1,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(
                  0.035,
                ),

                blurRadius: 5,

                offset:
                    const Offset(0, 2),
              ),
            ],
          ),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              // ==================================================
              // ICONO
              // ==================================================

              Container(
                width: 44,
                height: 44,

                decoration:
                    BoxDecoration(
                  color: colorVerde
                      .withOpacity(
                    0.09,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),

                child: Icon(
                  icono,

                  color:
                      colorVerde,

                  size: 25,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              // ==================================================
              // NOMBRE
              // ==================================================

              Text(
                codigo,

                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      colorPrincipal,
                ),

                textAlign:
                    TextAlign.center,

                maxLines: 2,

                overflow:
                    TextOverflow.ellipsis,
              ),

              const SizedBox(
                height: 3,
              ),

              // ==================================================
              // DESCRIPCIÓN
              // ==================================================

              Text(
                descripcion,

                style:
                    const TextStyle(
                  fontSize: 9,
                  color:
                      Colors.black45,
                ),

                textAlign:
                    TextAlign.center,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}