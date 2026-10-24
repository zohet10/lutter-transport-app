import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'menu.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usuarioController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;

  // ============================================================
  // RECORDAR USUARIO
  // ============================================================

  bool _recordarUsuario = false;

  // ============================================================
  // COLORES ZAFI
  // ============================================================

  static const Color colorPrincipal =
      Color(0xFF0F1E36);

  static const Color colorVerde =
      Color(0xFF2E7D32);

  // Verde manzana muy suave
  static const Color colorFondo =
      Color(0xFFF1F8F0);

  static const Color colorBorde =
      Color(0xFFD5E2D3);

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _cargarUsuarioRecordado();
  }

  // ============================================================
  // CARGAR USUARIO RECORDADO
  // ============================================================

  Future<void> _cargarUsuarioRecordado() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final bool recordar =
          prefs.getBool('recordar_usuario') ??
              false;

      final String usuario =
          prefs.getString('usuario_recordado') ??
              '';

      if (!mounted) return;

      setState(() {
        _recordarUsuario = recordar;

        if (recordar && usuario.isNotEmpty) {
          _usuarioController.text = usuario;
        }
      });
    } catch (e) {
      // Si ocurre algún problema con almacenamiento local,
      // el login sigue funcionando normalmente.
    }
  }

  // ============================================================
  // GUARDAR USUARIO
  // ============================================================

  Future<void> _guardarUsuarioRecordado(
    String usuario,
  ) async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      if (_recordarUsuario) {
        await prefs.setBool(
          'recordar_usuario',
          true,
        );

        await prefs.setString(
          'usuario_recordado',
          usuario,
        );
      } else {
        await prefs.setBool(
          'recordar_usuario',
          false,
        );

        await prefs.remove(
          'usuario_recordado',
        );
      }
    } catch (e) {
      // No impedimos el inicio de sesión
      // si falla el almacenamiento local.
    }
  }

  // ============================================================
  // INICIAR SESIÓN
  // ============================================================

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final usuarioIngresado =
          _usuarioController.text
              .trim()
              .toLowerCase();

      final passwordIngresada =
          _passwordController.text.trim();

      // ========================================================
      // CONSULTA FIREBASE
      // ========================================================

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .where(
                'usuario',
                isEqualTo: usuarioIngresado,
              )
              .where(
                'contrasena',
                isEqualTo: passwordIngresada,
              )
              .get();

      if (!mounted) return;

      // ========================================================
      // USUARIO ENCONTRADO
      // ========================================================

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc =
            querySnapshot.docs.first;

        // ======================================================
        // GUARDAR USUARIO SI ESTÁ MARCADO
        // ======================================================

        await _guardarUsuarioRecordado(
          usuarioIngresado,
        );

        // ======================================================
        // DATOS DEL USUARIO
        // ======================================================

        final Map<String, dynamic> userData = {
          'id': userDoc.id,
          ...userDoc.data(),
        };

        final bool primerInicio =
            userData['primer_inicio'] ?? false;

        // ======================================================
        // PRIMER INICIO
        // ======================================================

        if (primerInicio) {
          _mostrarModalCambioObligatorio(
            context,
            userDoc.id,
            userData,
          );
        } else {
          // ====================================================
          // ENTRAR AL SISTEMA
          // ====================================================

          Navigator.pushReplacement(
            context,

            MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(
                userData: userData,
              ),
            ),
          );
        }
      } else {
        // ======================================================
        // CREDENCIALES INCORRECTAS
        // ======================================================

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Usuario o contraseña incorrectos',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al conectar con la base de datos: $e',
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
  // MODAL CAMBIO DE CONTRASEÑA
  // ============================================================

  void _mostrarModalCambioObligatorio(
    BuildContext context,
    String docId,
    Map<String, dynamic> userData,
  ) {
    final TextEditingController nuevaPassCtrl =
        TextEditingController();

    final TextEditingController confirmarPassCtrl =
        TextEditingController();

    bool obscureNuevo = true;

    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (context) => StatefulBuilder(
        builder: (
          context,
          setStateModal,
        ) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(15),
            ),

            title: const Text(
              'Cambio de Contraseña Requerido',

              style: TextStyle(
                color: colorPrincipal,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            content:
                SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,

                children: [
                  const Text(
                    'Por seguridad, al ser tu primer ingreso debes establecer una nueva contraseña personal.',

                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  TextField(
                    controller:
                        nuevaPassCtrl,

                    obscureText:
                        obscureNuevo,

                    decoration:
                        InputDecoration(
                      labelText:
                          'Nueva Contraseña',

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(8),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(8),

                        borderSide:
                            const BorderSide(
                          color:
                              colorVerde,

                          width: 1.5,
                        ),
                      ),

                      suffixIcon:
                          IconButton(
                        icon: Icon(
                          obscureNuevo
                              ? Icons
                                  .visibility_off
                              : Icons
                                  .visibility,

                          color:
                              colorVerde,
                        ),

                        onPressed: () {
                          setStateModal(() {
                            obscureNuevo =
                                !obscureNuevo;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  TextField(
                    controller:
                        confirmarPassCtrl,

                    obscureText: true,

                    decoration:
                        InputDecoration(
                      labelText:
                          'Confirmar Contraseña',

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(8),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(8),

                        borderSide:
                            const BorderSide(
                          color:
                              colorVerde,

                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              ElevatedButton(
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
                        BorderRadius.circular(8),
                  ),
                ),

                onPressed: () async {
                  final nuevaPass =
                      nuevaPassCtrl.text.trim();

                  final confirmar =
                      confirmarPassCtrl.text.trim();

                  // ==========================================
                  // VALIDAR CAMPOS
                  // ==========================================

                  if (nuevaPass.isEmpty ||
                      confirmar.isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Rellene todos los campos',
                        ),

                        backgroundColor:
                            Colors.orange,
                      ),
                    );

                    return;
                  }

                  // ==========================================
                  // VALIDAR CONTRASEÑAS
                  // ==========================================

                  if (nuevaPass != confirmar) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Las contraseñas no coinciden',
                        ),

                        backgroundColor:
                            Colors.red,
                      ),
                    );

                    return;
                  }

                  try {
                    // ========================================
                    // ACTUALIZAR FIREBASE
                    // ========================================

                    await FirebaseFirestore
                        .instance
                        .collection('usuarios')
                        .doc(docId)
                        .update({
                      'contrasena':
                          nuevaPass,

                      'primer_inicio':
                          false,
                    });

                    // ========================================
                    // ACTUALIZAR DATOS LOCALES
                    // ========================================

                    userData['contrasena'] =
                        nuevaPass;

                    userData['primer_inicio'] =
                        false;

                    if (!context.mounted) {
                      return;
                    }

                    // ========================================
                    // CERRAR MODAL
                    // ========================================

                    Navigator.pop(context);

                    // ========================================
                    // ENTRAR AL SISTEMA
                    // ========================================

                    Navigator.pushReplacement(
                      context,

                      MaterialPageRoute(
                        builder:
                            (context) =>
                                HomeScreen(
                          userData:
                              userData,
                        ),
                      ),
                    );

                    // ========================================
                    // MENSAJE
                    // ========================================

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '¡Contraseña actualizada correctamente!',
                        ),

                        backgroundColor:
                            colorVerde,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error al actualizar la contraseña: $e',
                        ),

                        backgroundColor:
                            Colors.red,
                      ),
                    );
                  }
                },

                child: const Text(
                  'Guardar y Entrar',

                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),

            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 420,
              ),

              child: Card(
                elevation: 3,

                color: Colors.white,

                shadowColor:
                    Colors.black
                        .withOpacity(0.08),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),

                  side:
                      const BorderSide(
                    color: colorBorde,
                    width: 1,
                  ),
                ),

                child: Padding(
                  padding:
                      const EdgeInsets.all(28),

                  child: Form(
                    key: _formKey,

                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,

                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,

                      children: [
                        // ========================================
                        // LOGO
                        // ========================================

                        Center(
                          child: Container(
                            width: 76,
                            height: 76,

                            decoration:
                                BoxDecoration(
                              color:
                                  colorVerde,

                              borderRadius:
                                  BorderRadius
                                      .circular(20),
                            ),

                            child:
                                const Icon(
                              Icons
                                  .agriculture_outlined,

                              size: 43,

                              color:
                                  Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        // ========================================
                        // ZAFI
                        // ========================================

                        const Text(
                          'ZAFI',

                          textAlign:
                              TextAlign.center,

                          style:
                              TextStyle(
                            fontSize: 25,

                            fontWeight:
                                FontWeight.bold,

                            color:
                                colorPrincipal,

                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        const Text(
                          'Field Management System',

                          textAlign:
                              TextAlign.center,

                          style:
                              TextStyle(
                            fontSize: 13,

                            fontWeight:
                                FontWeight.w600,

                            color:
                                colorPrincipal,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        const Text(
                          'Gestión de operaciones agrícolas',

                          textAlign:
                              TextAlign.center,

                          style:
                              TextStyle(
                            fontSize: 10,

                            color:
                                Colors.black45,
                          ),
                        ),

                        const SizedBox(
                          height: 25,
                        ),

                        // ========================================
                        // USUARIO
                        // ========================================

                        const Text(
                          'Usuario',

                          style:
                              TextStyle(
                            fontSize: 12,

                            fontWeight:
                                FontWeight.bold,

                            color:
                                colorPrincipal,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        TextFormField(
                          controller:
                              _usuarioController,

                          textInputAction:
                              TextInputAction
                                  .next,

                          decoration:
                              InputDecoration(
                            hintText:
                                'Ingrese su usuario',

                            prefixIcon:
                                const Icon(
                              Icons
                                  .alternate_email,

                              color:
                                  Colors.black45,
                            ),

                            filled: true,

                            fillColor:
                                Colors.white,

                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(8),

                              borderSide:
                                  const BorderSide(
                                color:
                                    colorBorde,
                              ),
                            ),

                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(8),

                              borderSide:
                                  const BorderSide(
                                color:
                                    colorBorde,
                              ),
                            ),

                            focusedBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(8),

                              borderSide:
                                  const BorderSide(
                                color:
                                    colorVerde,

                                width: 1.5,
                              ),
                            ),

                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                          ),

                          validator:
                              (value) {
                            if (value ==
                                    null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Por favor ingrese su usuario';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        // ========================================
                        // CONTRASEÑA
                        // ========================================

                        const Text(
                          'Contraseña',

                          style:
                              TextStyle(
                            fontSize: 12,

                            fontWeight:
                                FontWeight.bold,

                            color:
                                colorPrincipal,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        TextFormField(
                          controller:
                              _passwordController,

                          obscureText:
                              _obscureText,

                          textInputAction:
                              TextInputAction
                                  .done,

                          onFieldSubmitted:
                              (_) {
                            if (!_isLoading) {
                              _iniciarSesion();
                            }
                          },

                          decoration:
                              InputDecoration(
                            hintText:
                                'Ingrese su contraseña',

                            prefixIcon:
                                const Icon(
                              Icons.lock_outline,

                              color:
                                  Colors.black45,
                            ),

                            suffixIcon:
                                IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons
                                        .visibility_off
                                    : Icons
                                        .visibility,

                                color:
                                    Colors.black45,
                              ),

                              onPressed: () {
                                setState(() {
                                  _obscureText =
                                      !_obscureText;
                                });
                              },
                            ),

                            filled: true,

                            fillColor:
                                Colors.white,

                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(8),

                              borderSide:
                                  const BorderSide(
                                color:
                                    colorBorde,
                              ),
                            ),

                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(8),

                              borderSide:
                                  const BorderSide(
                                color:
                                    colorBorde,
                              ),
                            ),

                            focusedBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(8),

                              borderSide:
                                  const BorderSide(
                                color:
                                    colorVerde,

                                width: 1.5,
                              ),
                            ),

                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                          ),

                          validator:
                              (value) {
                            if (value ==
                                    null ||
                                value.isEmpty) {
                              return 'Por favor ingrese su contraseña';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 7,
                        ),

                        // ========================================
                        // RECORDAR USUARIO
                        // ========================================

                        InkWell(
                          borderRadius:
                              BorderRadius
                                  .circular(6),

                          onTap: () {
                            setState(() {
                              _recordarUsuario =
                                  !_recordarUsuario;
                            });
                          },

                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 3,
                            ),

                            child: Row(
                              children: [
                                Checkbox(
                                  value:
                                      _recordarUsuario,

                                  activeColor:
                                      colorVerde,

                                  checkColor:
                                      Colors.white,

                                  side:
                                      const BorderSide(
                                    color:
                                        Colors.black54,
                                  ),

                                  materialTapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,

                                  visualDensity:
                                      VisualDensity
                                          .compact,

                                  onChanged:
                                      (value) {
                                    setState(() {
                                      _recordarUsuario =
                                          value ??
                                              false;
                                    });
                                  },
                                ),

                                const SizedBox(
                                  width: 3,
                                ),

                                const Text(
                                  'Recordar usuario',

                                  style:
                                      TextStyle(
                                    fontSize: 13,

                                    color:
                                        Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        // ========================================
                        // BOTÓN INICIAR SESIÓN
                        // ========================================

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
                                        .circular(8),
                              ),
                            ),

                            onPressed:
                                _isLoading
                                    ? null
                                    : _iniciarSesion,

                            child: _isLoading
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
                                : const Text(
                                    'Iniciar Sesión',

                                    style:
                                        TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize:
                                          15,

                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        // ========================================
                        // PIE
                        // ========================================

                        const Text(
                          'Sistema de gestión de campo',

                          textAlign:
                              TextAlign.center,

                          style:
                              TextStyle(
                            fontSize: 9,

                            color:
                                Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}