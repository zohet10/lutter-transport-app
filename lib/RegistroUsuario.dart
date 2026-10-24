import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class RegistroSupervisorScreen extends StatefulWidget {
  const RegistroSupervisorScreen({super.key});

  @override
  State<RegistroSupervisorScreen> createState() =>
      _RegistroSupervisorScreenState();
}

class _RegistroSupervisorScreenState
    extends State<RegistroSupervisorScreen> {
  // ============================================================
  // COLORES IGUALES A LOS OTROS FORMATOS
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  // ============================================================
  // CONTROLADORES
  // ============================================================

  final TextEditingController _nombreController =
      TextEditingController();

  final TextEditingController _usuarioController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _busquedaUsuariosController =
      TextEditingController();

  // ============================================================
  // ESTADOS
  // ============================================================

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _forzarCambioPassword = true;

  String _rolSeleccionado = 'Supervisor';

  String? _usuarioEditandoId;

  String _contrasenaActualGuardada = '';

  String _busquedaUsuarios = '';

  // ============================================================
  // ROLES
  // ============================================================

  final List<String> _rolesDisponibles = [
    'Supervisor',
    'Administración Agrícola',
    'Jefe de Zona',
    'Administrador',
  ];

  // ============================================================
  // PERMISOS
  // ============================================================

  Map<String, bool> _permisosFormatos = {};

  bool _cargandoPermisos = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _cargarPermisosDesdeFirebase();

    _nombreController.addListener(() {
      if (_usuarioEditandoId == null) {
        _usuarioController.text =
            _generarUsuarioAutomatico(_nombreController.text);
      }
    });

    _passwordController.text = _generarPasswordAleatoria();
  }

  // ============================================================
  // CARGAR PERMISOS
  // ============================================================

  Future<void> _cargarPermisosDesdeFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('config_formatos')
          .get();

      Map<String, bool> permisosTemp = {};

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final nombreFormato =
              doc.data()['nombre'] as String? ?? doc.id;

          permisosTemp[nombreFormato] = false;
        }

        // ========================================================
        // AGREGAMOS EL PERMISO NUEVO SI NO EXISTE
        // ========================================================

        permisosTemp.putIfAbsent(
          'Solicitudes de edición',
          () => false,
        );
      } else {
        permisosTemp = {
          'Control de Transporte (F-OA-225)': false,
          'Ruta de Transporte (F-OA-066)': false,
          'Control de Agua': false,
          'Subcontratista': false,
          'Supervisor': false,
          'Datos de Finca': false,
          'Registros Generales': false,
          'Reportes y Estadísticas': false,
          'Calculadora de Kilometraje': false,

          // NUEVO
          'Solicitudes de edición': false,
        };
      }

      if (!mounted) return;

      setState(() {
        _permisosFormatos = permisosTemp;
        _cargandoPermisos = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargandoPermisos = false;
      });
    }
  }

  // ============================================================
  // GENERAR USUARIO AUTOMÁTICO
  // ============================================================

  String _generarUsuarioAutomatico(String nombreCompleto) {
    List<String> partes =
        nombreCompleto.trim().split(RegExp(r'\s+'));

    if (partes.isEmpty || partes[0].isEmpty) {
      return '';
    }

    String inicial =
        partes[0].substring(0, 1).toLowerCase();

    String apellido =
        partes.length > 1 ? partes.last.toLowerCase() : '';

    if (apellido.isEmpty) {
      return inicial.replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
    }

    return '$inicial-$apellido'.replaceAll(
      RegExp(r'[^a-z0-9-]'),
      '',
    );
  }

  // ============================================================
  // GENERAR CONTRASEÑA
  // ============================================================

  String _generarPasswordAleatoria() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$!';

    Random rnd = Random();

    return List.generate(
      8,
      (index) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  // ============================================================
  // DECORACIÓN DE CAMPOS
  // ============================================================

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
    bool filled = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 14,
      ),

      prefixIcon: Icon(
        icon,
        color: colorVerde,
        size: 20,
      ),

      suffixIcon: suffixIcon,

      filled: filled,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 12,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: colorBorde,
          width: 1,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: colorVerde,
          width: 1.3,
        ),
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: colorBorde,
        ),
      ),
    );
  }

  // ============================================================
  // LIMPIAR FORMULARIO
  // ============================================================

  void _limpiarFormulario() {
    setState(() {
      _usuarioEditandoId = null;

      _nombreController.clear();

      _usuarioController.clear();

      _passwordController.text =
          _generarPasswordAleatoria();

      _forzarCambioPassword = true;

      _contrasenaActualGuardada = '';

      _rolSeleccionado = 'Supervisor';

      _permisosFormatos.updateAll(
        (key, value) => false,
      );
    });
  }

  // ============================================================
  // GUARDAR USUARIO
  // ============================================================

  Future<void> _guardarUsuarioEnFirebase() async {
    if (_nombreController.text.trim().isEmpty ||
        _usuarioController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor complete los campos obligatorios.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final datosUsuario = {
        'nombre_completo':
            _nombreController.text.trim(),

        'rol': _rolSeleccionado,

        'usuario':
            _usuarioController.text.trim().toLowerCase(),

        'contrasena':
            _passwordController.text.trim(),

        'primer_inicio':
            _forzarCambioPassword,

        'permisos':
            _permisosFormatos,
      };

      // ========================================================
      // NUEVO USUARIO
      // ========================================================

      if (_usuarioEditandoId == null) {
        datosUsuario['fecha_creacion'] =
            FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('usuarios')
            .add(datosUsuario);
      }

      // ========================================================
      // ACTUALIZAR USUARIO
      // ========================================================

      else {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_usuarioEditandoId)
            .update(datosUsuario);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _usuarioEditandoId == null
                ? '¡Usuario registrado correctamente!'
                : '¡Usuario actualizado correctamente!',
          ),
          backgroundColor: colorVerde,
          duration: const Duration(seconds: 4),
        ),
      );

      _limpiarFormulario();
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
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CARGAR USUARIO PARA EDITAR
  // ============================================================

  void _cargarUsuarioParaEditar(
    String id,
    Map<String, dynamic> data,
  ) {
    setState(() {
      _usuarioEditandoId = id;

      _nombreController.text =
          data['nombre_completo'] ?? '';

      _usuarioController.text =
          data['usuario'] ?? '';

      _passwordController.text =
          data['contrasena'] ?? '';

      _contrasenaActualGuardada =
          data['contrasena'] ?? '';

      _rolSeleccionado =
          data['rol'] ?? 'Supervisor';

      final dynamic primerInicioVal =
          data['primer_inicio'];

      _forzarCambioPassword =
          primerInicioVal is bool
              ? primerInicioVal
              : false;

      final permisosData =
          data['permisos'] as Map<dynamic, dynamic>?;

      _permisosFormatos.forEach((key, value) {
        if (permisosData != null &&
            permisosData.containsKey(key)) {
          _permisosFormatos[key] =
              permisosData[key] ?? false;
        } else {
          _permisosFormatos[key] = false;
        }
      });
    });
  }

  // ============================================================
  // ELIMINAR USUARIO
  // ============================================================

  Future<void> _eliminarUsuario(
    String id,
    String nombreUsuario,
  ) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirmar eliminación',
        ),
        content: Text(
          '¿Está seguro de eliminar al usuario "$nombreUsuario"?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(id)
            .delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Usuario eliminado correctamente',
            ),
            backgroundColor: Colors.red,
          ),
        );

        if (_usuarioEditandoId == id) {
          _limpiarFormulario();
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nombreController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _busquedaUsuariosController.dispose();

    super.dispose();
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
          // FRANJA SUPERIOR IGUAL A LOS OTROS FORMATOS
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
                builder: (context, constraints) {
                  final bool pantallaPequena =
                      constraints.maxWidth < 700;

                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(
                        horizontal:
                            pantallaPequena ? 8 : 24,
                        vertical:
                            pantallaPequena ? 12 : 18,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(14),

                        border: Border.all(
                          color: colorBorde,
                          width: 1,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.04),
                            blurRadius: 10,
                            offset:
                                const Offset(0, 3),
                          ),
                        ],
                      ),

                      child: Padding(
                        padding: EdgeInsets.all(
                          pantallaPequena
                              ? 16
                              : 20,
                        ),

                        child: ListView(
                          children: [
                            // ==================================================
                            // ENCABEZADO
                            // ==================================================

                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _usuarioEditandoId ==
                                                null
                                            ? 'Registro de Usuario y Asignación de Roles'
                                            : 'Editando Usuario: ${_usuarioController.text}',
                                        style:
                                            const TextStyle(
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
                                        'Complete los datos del personal. La contraseña se genera automáticamente para entregarla.',
                                        style:
                                            TextStyle(
                                          color:
                                              Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (_usuarioEditandoId !=
                                    null)
                                  TextButton.icon(
                                    onPressed:
                                        _limpiarFormulario,
                                    icon:
                                        const Icon(
                                      Icons.close,
                                      color:
                                          Colors.grey,
                                      size: 18,
                                    ),
                                    label:
                                        const Text(
                                      'Cancelar',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            const Divider(
                              color: colorBorde,
                              height: 1,
                            ),

                            const SizedBox(
                              height: 20,
                            ),

                            // ==================================================
                            // NOMBRE
                            // ==================================================

                            const Text(
                              'Nombre Completo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Colors.black87,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            TextField(
                              controller:
                                  _nombreController,
                              decoration:
                                  _inputDecoration(
                                hintText:
                                    'nombre y apellidos',
                                icon:
                                    Icons.person_outline,
                              ),
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            // ==================================================
                            // ROL
                            // ==================================================

                            const Text(
                              'Rol de Usuario',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Colors.black87,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            DropdownButtonFormField<String>(
                              value:
                                  _rolSeleccionado,
                              decoration:
                                  _inputDecoration(
                                hintText:
                                    'Seleccione un rol',
                                icon: Icons
                                    .admin_panel_settings_outlined,
                              ),
                              items: _rolesDisponibles
                                  .map(
                                    (
                                      String rol,
                                    ) {
                                      return DropdownMenuItem<
                                          String>(
                                        value: rol,
                                        child: Text(
                                          rol,
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                14,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                  .toList(),
                              onChanged:
                                  (String? nuevoRol) {
                                if (nuevoRol !=
                                    null) {
                                  setState(() {
                                    _rolSeleccionado =
                                        nuevoRol;
                                  });
                                }
                              },
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            // ==================================================
                            // USUARIO + CONTRASEÑA
                            // ==================================================

                            if (pantallaPequena)
                              Column(
                                children: [
                                  _campoUsuario(),
                                  const SizedBox(
                                    height: 16,
                                  ),
                                  _campoPassword(),
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
                                        _campoUsuario(),
                                  ),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child:
                                        _campoPassword(),
                                  ),
                                ],
                              ),

                            const SizedBox(
                              height: 14,
                            ),

                            // ==================================================
                            // CAMBIO DE CONTRASEÑA
                            // ==================================================

                            Container(
                              decoration:
                                  BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                                border: Border.all(
                                  color:
                                      colorBorde,
                                ),
                              ),
                              child:
                                  CheckboxListTile(
                                title: const Text(
                                  'Restablecer contraseña (Obligar cambio en su primer login)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),
                                value:
                                    _forzarCambioPassword,
                                activeColor:
                                    colorVerde,
                                dense: true,
                                visualDensity:
                                    VisualDensity
                                        .compact,
                                controlAffinity:
                                    ListTileControlAffinity
                                        .leading,
                                contentPadding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 8,
                                ),
                                onChanged:
                                    (bool? valor) {
                                  setState(() {
                                    _forzarCambioPassword =
                                        valor ??
                                            false;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(
                              height: 25,
                            ),

                            // ==================================================
                            // TÍTULO PERMISOS
                            // ==================================================

                            const Text(
                              'Permisos y Formatos Visibles',
                              style: TextStyle(
                                color: colorVerde,
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            const Text(
                              'Seleccione los módulos y formatos a los que este usuario tendrá acceso.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            // ==================================================
                            // LISTA DE PERMISOS
                            // ==================================================

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                                border: Border.all(
                                  color:
                                      colorBorde,
                                ),
                              ),
                              child: _cargandoPermisos
                                  ? const Center(
                                      child: Padding(
                                        padding:
                                            EdgeInsets
                                                .all(
                                          15,
                                        ),
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              colorVerde,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children:
                                          _permisosFormatos
                                              .keys
                                              .map(
                                        (
                                          String formato,
                                        ) {
                                          return CheckboxListTile(
                                            title:
                                                Text(
                                              formato,
                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    13,
                                                color:
                                                    Colors.black87,
                                              ),
                                            ),
                                            value:
                                                _permisosFormatos[
                                                        formato] ??
                                                    false,
                                            activeColor:
                                                colorVerde,
                                            dense:
                                                true,
                                            controlAffinity:
                                                ListTileControlAffinity
                                                    .leading,
                                            contentPadding:
                                                EdgeInsets
                                                    .zero,
                                            onChanged:
                                                (
                                              bool?
                                                  valor,
                                            ) {
                                              setState(
                                                () {
                                                  _permisosFormatos[
                                                          formato] =
                                                      valor ??
                                                          false;
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ).toList(),
                                    ),
                            ),

                            const SizedBox(
                              height: 25,
                            ),

                            // ==================================================
                            // BOTÓN GUARDAR
                            // ==================================================

                            SizedBox(
                              width:
                                  double.infinity,
                              height: 48,
                              child:
                                  ElevatedButton.icon(
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
                                                8),
                                  ),
                                ),
                                onPressed:
                                    _isLoading
                                        ? null
                                        : _guardarUsuarioEnFirebase,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Colors.white,
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : Icon(
                                        _usuarioEditandoId ==
                                                null
                                            ? Icons
                                                .person_add_alt_1
                                            : Icons.save,
                                        color:
                                            Colors.white,
                                      ),
                                label: Text(
                                  _isLoading
                                      ? 'Procesando...'
                                      : (_usuarioEditandoId ==
                                              null
                                          ? 'Registrar Usuario'
                                          : 'Actualizar Cambios'),
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 40,
                            ),

                            // ==================================================
                            // USUARIOS REGISTRADOS
                            // ==================================================

                            const Text(
                              'Usuarios Registrados en el Sistema',
                              style: TextStyle(
                                color:
                                    colorPrincipal,
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            const Text(
                              'Lista general de personal. Por seguridad, las contraseñas se encuentran ocultas.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            // ==================================================
                            // BUSCADOR
                            // ==================================================

                            TextField(
                              controller:
                                  _busquedaUsuariosController,
                              onChanged: (texto) {
                                setState(() {
                                  _busquedaUsuarios =
                                      texto
                                          .trim()
                                          .toLowerCase();
                                });
                              },
                              decoration:
                                  _inputDecoration(
                                hintText:
                                    'Buscar usuario por nombre...',
                                icon:
                                    Icons.search,
                                suffixIcon:
                                    _busquedaUsuarios
                                            .isNotEmpty
                                        ? IconButton(
                                            icon:
                                                const Icon(
                                              Icons.clear,
                                              color:
                                                  Colors.grey,
                                            ),
                                            onPressed:
                                                () {
                                              _busquedaUsuariosController
                                                  .clear();

                                              setState(
                                                () {
                                                  _busquedaUsuarios =
                                                      '';
                                                },
                                              );
                                            },
                                          )
                                        : null,
                              ),
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            // ==================================================
                            // STREAM DE USUARIOS
                            // ==================================================

                            StreamBuilder<
                                QuerySnapshot>(
                              stream:
                                  FirebaseFirestore
                                      .instance
                                      .collection(
                                          'usuarios')
                                      .snapshots(),
                              builder:
                                  (context, snapshot) {
                                if (snapshot
                                        .connectionState ==
                                    ConnectionState
                                        .waiting) {
                                  return const Center(
                                    child:
                                        Padding(
                                      padding:
                                          EdgeInsets
                                              .all(
                                        20,
                                      ),
                                      child:
                                          CircularProgressIndicator(
                                        color:
                                            colorVerde,
                                      ),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Container(
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      20,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  8),
                                      border:
                                          Border.all(
                                        color:
                                            colorBorde,
                                      ),
                                    ),
                                    child: Text(
                                      'Error al cargar usuarios: ${snapshot.error}',
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.red,
                                      ),
                                    ),
                                  );
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!
                                        .docs.isEmpty) {
                                  return Container(
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      25,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  8),
                                      border:
                                          Border.all(
                                        color:
                                            colorBorde,
                                      ),
                                    ),
                                    child:
                                        const Text(
                                      'No hay usuarios registrados todavía.',
                                      textAlign:
                                          TextAlign
                                              .center,
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.grey,
                                      ),
                                    ),
                                  );
                                }

                                // ============================================
                                // FILTRAR POR NOMBRE
                                // ============================================

                                final docs =
                                    snapshot.data!
                                        .docs;

                                final docsFiltrados =
                                    docs.where((doc) {
                                  final data =
                                      doc.data()
                                          as Map<String,
                                              dynamic>;

                                  final nombre =
                                      (data[
                                                  'nombre_completo'] ??
                                              '')
                                          .toString()
                                          .toLowerCase();

                                  return nombre.contains(
                                    _busquedaUsuarios,
                                  );
                                }).toList();

                                if (docsFiltrados
                                    .isEmpty) {
                                  return Container(
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      25,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  8),
                                      border:
                                          Border.all(
                                        color:
                                            colorBorde,
                                      ),
                                    ),
                                    child:
                                        Column(
                                      children: [
                                        const Icon(
                                          Icons
                                              .person_search_outlined,
                                          size: 40,
                                          color:
                                              Colors.grey,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        Text(
                                          'No se encontró ningún usuario con "$_busquedaUsuarios".',
                                          textAlign:
                                              TextAlign
                                                  .center,
                                          style:
                                              const TextStyle(
                                            color:
                                                Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView
                                    .builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount:
                                      docsFiltrados
                                          .length,
                                  itemBuilder:
                                      (context,
                                          index) {
                                    final doc =
                                        docsFiltrados[
                                            index];

                                    final data =
                                        doc.data()
                                            as Map<String,
                                                dynamic>;

                                    final id =
                                        doc.id;

                                    final nombre =
                                        data[
                                                'nombre_completo'] ??
                                            'Sin nombre';

                                    final usuario =
                                        data[
                                                'usuario'] ??
                                            'Sin usuario';

                                    final rol =
                                        data[
                                                'rol'] ??
                                            'Sin rol';

                                    final dynamic
                                        primerInicioRaw =
                                        data[
                                            'primer_inicio'];

                                    final bool
                                        primerInicio =
                                        primerInicioRaw
                                                is bool
                                            ? primerInicioRaw
                                            : false;

                                    return Container(
                                      margin:
                                          const EdgeInsets
                                              .only(
                                        bottom: 8,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            Colors.white,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    8),
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

                                        // ==================================
                                        // AVATAR
                                        // ==================================

                                        leading:
                                            CircleAvatar(
                                          backgroundColor:
                                              colorPrincipal,
                                          child:
                                              Text(
                                            nombre
                                                    .toString()
                                                    .isNotEmpty
                                                ? nombre
                                                    .toString()
                                                    .substring(
                                                      0,
                                                      1,
                                                    )
                                                    .toUpperCase()
                                                : 'U',
                                            style:
                                                const TextStyle(
                                              color:
                                                  Colors.white,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // ==================================
                                        // INFORMACIÓN
                                        // ==================================

                                        title:
                                            Text(
                                          nombre
                                              .toString(),
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

                                        subtitle:
                                            Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            const SizedBox(
                                              height:
                                                  3,
                                            ),

                                            Text(
                                              'Usuario: $usuario',
                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    12,
                                              ),
                                            ),

                                            Text(
                                              'Rol: $rol',
                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    12,
                                              ),
                                            ),

                                            const SizedBox(
                                              height:
                                                  3,
                                            ),

                                            Text(
                                              primerInicio
                                                  ? 'Estado: Pendiente de cambio en primer login'
                                                  : 'Estado: Contraseña activa',
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    11,
                                                color:
                                                    primerInicio
                                                        ? Colors.orange.shade800
                                                        : colorVerde,
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),

                                        isThreeLine:
                                            true,

                                        // ==================================
                                        // BOTONES
                                        // ==================================

                                        trailing:
                                            Wrap(
                                          spacing:
                                              0,
                                          children: [
                                            IconButton(
                                              icon:
                                                  const Icon(
                                                Icons.edit_outlined,
                                                color:
                                                    colorVerde,
                                              ),
                                              tooltip:
                                                  'Editar permisos o datos',
                                              onPressed:
                                                  () =>
                                                      _cargarUsuarioParaEditar(
                                                id,
                                                data,
                                              ),
                                            ),

                                            IconButton(
                                              icon:
                                                  const Icon(
                                                Icons.delete_outline,
                                                color:
                                                    Colors.red,
                                              ),
                                              tooltip:
                                                  'Eliminar usuario',
                                              onPressed:
                                                  () =>
                                                      _eliminarUsuario(
                                                id,
                                                usuario
                                                    .toString(),
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

  // ============================================================
  // CAMPO USUARIO
  // ============================================================

  Widget _campoUsuario() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Usuario de Acceso',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        TextField(
          controller: _usuarioController,
          decoration: _inputDecoration(
            hintText: 'Auto-generado',
            icon: Icons.alternate_email,
            filled: true,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CAMPO CONTRASEÑA
  // ============================================================

  Widget _campoPassword() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Contraseña Temporal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            TextButton.icon(
              onPressed: () {
                setState(() {
                  _passwordController.text =
                      _generarPasswordAleatoria();
                });
              },
              icon: const Icon(
                Icons.refresh,
                size: 14,
                color: colorVerde,
              ),
              label: const Text(
                'Generar Clave',
                style: TextStyle(
                  fontSize: 11,
                  color: colorVerde,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize:
                    const Size(50, 20),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 5,
        ),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: _inputDecoration(
            hintText: 'Clave temporal',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: colorVerde,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword =
                      !_obscurePassword;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}