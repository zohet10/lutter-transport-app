import 'package:flutter/material.dart';

import 'autorizacion_edicion_service.dart';
import 'solicitud_edicion_model.dart';

class SolicitudesEdicionScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const SolicitudesEdicionScreen({
    super.key,
    required this.userData,
  });

  // ============================================================
  // COLORES GENERALES DE LA APLICACIÓN
  // ============================================================

  static const Color colorPrincipal = Color(0xFF0F1E36);
  static const Color colorVerde = Color(0xFF2E7D32);
  static const Color colorFondo = Color(0xFFEEF2F6);
  static const Color colorBorde = Color(0xFFD5DCE5);

  // ============================================================
  // DATOS DEL USUARIO
  // ============================================================

  String get nombreUsuario {
    return userData['nombre_completo']?.toString() ?? 'Usuario';
  }

  String get uidUsuario {
    return userData['uid']?.toString() ??
        userData['usuarioUid']?.toString() ??
        '';
  }

  String get rolUsuario {
    return userData['rol']?.toString() ?? '';
  }

  bool get esAdministrador {
    return rolUsuario.toLowerCase() == 'administrador';
  }

  bool get esJefe {
    return rolUsuario.toLowerCase() == 'jefe';
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorPrincipal,
        foregroundColor: Colors.white,
        title: const Text(
          'Solicitudes de edición',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: StreamBuilder<List<SolicitudEdicion>>(
        stream: AutorizacionEdicionService.escucharSolicitudes(),

        builder: (context, snapshot) {
          // ====================================================
          // CARGANDO
          // ====================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: colorVerde,
              ),
            );
          }

          // ====================================================
          // ERROR
          // ====================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 600,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorBorde,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Error al cargar las solicitudes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: colorPrincipal,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // ====================================================
          // SOLICITUDES
          // ====================================================

          var solicitudes = snapshot.data ?? [];

          // El Administrador ve todas.
          //
          // Los demás usuarios solamente ven
          // sus propias solicitudes.

          if (!esAdministrador) {
            solicitudes = solicitudes.where((solicitud) {
              return solicitud.solicitadoPorUid == uidUsuario;
            }).toList();
          }

          // ====================================================
          // SIN SOLICITUDES
          // ====================================================

          if (solicitudes.isEmpty) {
            return _estadoVacio();
          }

          // ====================================================
          // LISTA RESPONSIVE
          // ====================================================

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool pantallaPequena =
                  constraints.maxWidth < 700;

              return RefreshIndicator(
                color: colorVerde,

                onRefresh: () async {
                  await Future.delayed(
                    const Duration(milliseconds: 300),
                  );
                },

                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: pantallaPequena ? 12 : 24,
                    vertical: 20,
                  ),

                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1100,
                        ),

                        child: Column(
                          children: [
                            _encabezadoLista(
                              solicitudes.length,
                              pantallaPequena,
                            ),

                            const SizedBox(height: 16),

                            ...solicitudes.map(
                              (solicitud) => _tarjetaSolicitud(
                                context,
                                solicitud,
                                pantallaPequena,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // ESTADO VACÍO
  // ============================================================

  Widget _estadoVacio() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),

        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),

          padding: const EdgeInsets.all(30),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),

            border: Border.all(
              color: colorBorde,
              width: 1,
            ),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Container(
                width: 80,
                height: 80,

                decoration: BoxDecoration(
                  color: colorVerde.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 42,
                  color: colorVerde,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'No hay solicitudes',
                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorPrincipal,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Las solicitudes de edición aparecerán aquí.',
                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ENCABEZADO DE LA LISTA
  // ============================================================

  Widget _encabezadoLista(
    int cantidad,
    bool pantallaPequena,
  ) {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(
        pantallaPequena ? 16 : 20,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: colorBorde,
          width: 1,
        ),
      ),

      child: pantallaPequena
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Solicitudes de edición',

                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: colorPrincipal,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  esAdministrador
                      ? 'Solicitudes pendientes de revisión'
                      : 'Tus solicitudes de edición',

                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 12),

                _contadorSolicitudes(cantidad),
              ],
            )

          : Row(
              children: [
                Container(
                  width: 46,
                  height: 46,

                  decoration: BoxDecoration(
                    color: colorVerde.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: const Icon(
                    Icons.assignment_outlined,
                    color: colorVerde,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Solicitudes de edición',

                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: colorPrincipal,
                        ),
                      ),

                      SizedBox(height: 4),

                      Text(
                        'Gestión de solicitudes de modificación de registros',

                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                _contadorSolicitudes(cantidad),
              ],
            ),
    );
  }

  // ============================================================
  // CONTADOR
  // ============================================================

  Widget _contadorSolicitudes(int cantidad) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      decoration: BoxDecoration(
        color: colorPrincipal,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        '$cantidad ${cantidad == 1 ? 'solicitud' : 'solicitudes'}',

        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // TARJETA DE SOLICITUD
  // ============================================================

  Widget _tarjetaSolicitud(
    BuildContext context,
    SolicitudEdicion solicitud,
    bool pantallaPequena,
  ) {
    final estado = solicitud.estado;

    Color colorEstado;
    IconData iconoEstado;

    switch (estado) {
      case 'pendiente':
        colorEstado = Colors.orange;
        iconoEstado = Icons.hourglass_empty;
        break;

      case 'autorizada':
        colorEstado = colorVerde;
        iconoEstado = Icons.check_circle_outline;
        break;

      case 'rechazada':
        colorEstado = Colors.red;
        iconoEstado = Icons.cancel_outlined;
        break;

      case 'completada':
        colorEstado = Colors.blue;
        iconoEstado = Icons.task_alt;
        break;

      case 'cancelada':
        colorEstado = Colors.grey;
        iconoEstado = Icons.block;
        break;

      default:
        colorEstado = Colors.grey;
        iconoEstado = Icons.help_outline;
    }

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(
        bottom: 14,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: colorBorde,
          width: 1,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Padding(
        padding: EdgeInsets.all(
          pantallaPequena ? 15 : 20,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ==================================================
            // ENCABEZADO
            // ==================================================

            if (pantallaPequena)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    solicitud.actividad.isEmpty
                        ? 'Actividad sin nombre'
                        : solicitud.actividad,

                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorPrincipal,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _estadoChip(
                    estado,
                    colorEstado,
                    iconoEstado,
                  ),
                ],
              )

            else
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Expanded(
                    child: Text(
                      solicitud.actividad.isEmpty
                          ? 'Actividad sin nombre'
                          : solicitud.actividad,

                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorPrincipal,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  _estadoChip(
                    estado,
                    colorEstado,
                    iconoEstado,
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // ==================================================
            // INFORMACIÓN DEL REGISTRO
            //
            // SOLO SE MUESTRA:
            // - Solicitado por
            // - Formato
            //
            // Colección y Registro NO se muestran.
            // ==================================================

            _dato(
              Icons.person_outline,
              'Solicitado por',
              solicitud.solicitadoPor,
            ),

            const SizedBox(height: 8),

            _dato(
              Icons.description_outlined,
              'Formato',
              solicitud.formato,
            ),

            const SizedBox(height: 14),

            // ==================================================
            // MOTIVO
            // ==================================================

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(13),

              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: BorderRadius.circular(10),

                border: Border.all(
                  color: colorBorde,
                  width: 1,
                ),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 17,
                        color: colorPrincipal,
                      ),

                      SizedBox(width: 7),

                      Text(
                        'Motivo de la solicitud',

                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colorPrincipal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  Text(
                    solicitud.motivo.isEmpty
                        ? 'Sin motivo especificado'
                        : solicitud.motivo,

                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // AUTORIZADOR
            // ==================================================

            if (solicitud.autorizadoPor != null &&
                solicitud.autorizadoPor!.isNotEmpty) ...[
              const SizedBox(height: 12),

              _dato(
                Icons.verified_user_outlined,
                'Procesado por',
                solicitud.autorizadoPor!,
              ),
            ],

            // ==================================================
            // BOTONES DEL ADMINISTRADOR
            // ==================================================

            if (esAdministrador &&
                estado == 'pendiente') ...[
              const SizedBox(height: 16),

              _botonesAdministrador(
                context,
                solicitud,
                pantallaPequena,
              ),
            ],

            // ==================================================
            // MENSAJE AUTORIZADA
            // ==================================================

            if (estado == 'autorizada') ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EC),

                  borderRadius:
                      BorderRadius.circular(10),

                  border: Border.all(
                    color: colorVerde.withOpacity(0.25),
                    width: 1,
                  ),
                ),

                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: colorVerde,
                    ),

                    SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'Esta solicitud fue autorizada. '
                        'El registro puede ser editado por el usuario que realizó la solicitud.',

                        style: TextStyle(
                          color: colorVerde,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CHIP DE ESTADO
  // ============================================================

  Widget _estadoChip(
    String estado,
    Color colorEstado,
    IconData iconoEstado,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: colorEstado.withOpacity(0.10),

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color: colorEstado.withOpacity(0.20),
          width: 1,
        ),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            iconoEstado,
            size: 16,
            color: colorEstado,
          ),

          const SizedBox(width: 5),

          Text(
            _textoEstado(estado),

            style: TextStyle(
              color: colorEstado,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTONES ADMINISTRADOR
  // ============================================================

  Widget _botonesAdministrador(
    BuildContext context,
    SolicitudEdicion solicitud,
    bool pantallaPequena,
  ) {
    final botonRechazar =
        OutlinedButton.icon(
      onPressed: () {
        _rechazar(
          context,
          solicitud,
        );
      },

      icon: const Icon(
        Icons.close,
        size: 18,
      ),

      label: const Text(
        'Rechazar',
      ),

      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,

        side: const BorderSide(
          color: Colors.red,
        ),

        padding: const EdgeInsets.symmetric(
          vertical: 13,
        ),

        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(9),
        ),
      ),
    );

    final botonAutorizar =
        ElevatedButton.icon(
      onPressed: () {
        _autorizar(
          context,
          solicitud,
        );
      },

      icon: const Icon(
        Icons.check,
        size: 18,
      ),

      label: const Text(
        'Autorizar',
      ),

      style: ElevatedButton.styleFrom(
        backgroundColor: colorVerde,
        foregroundColor: Colors.white,
        elevation: 0,

        padding: const EdgeInsets.symmetric(
          vertical: 13,
        ),

        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(9),
        ),
      ),
    );

    // ==========================================================
    // CELULAR
    // ==========================================================

    if (pantallaPequena) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: botonAutorizar,
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: botonRechazar,
          ),
        ],
      );
    }

    // ==========================================================
    // PC / TABLET
    // ==========================================================

    return Row(
      children: [
        Expanded(
          child: botonRechazar,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: botonAutorizar,
        ),
      ],
    );
  }

  // ============================================================
  // DATO
  // ============================================================

  Widget _dato(
    IconData icono,
    String titulo,
    String valor,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Icon(
          icono,
          size: 18,
          color: colorPrincipal,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),

              children: [
                TextSpan(
                  text: '$titulo: ',

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorPrincipal,
                  ),
                ),

                TextSpan(
                  text: valor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TEXTO ESTADO
  // ============================================================

  String _textoEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'PENDIENTE';

      case 'autorizada':
        return 'AUTORIZADA';

      case 'rechazada':
        return 'RECHAZADA';

      case 'completada':
        return 'COMPLETADA';

      case 'cancelada':
        return 'CANCELADA';

      default:
        return estado.toUpperCase();
    }
  }

  // ============================================================
  // AUTORIZAR
  // ============================================================

  Future<void> _autorizar(
    BuildContext context,
    SolicitudEdicion solicitud,
  ) async {
    try {
      await AutorizacionEdicionService
          .autorizarSolicitud(
        solicitudId: solicitud.id,
        autorizadoPor: nombreUsuario,
        autorizadoPorUid: uidUsuario,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud autorizada correctamente.',
          ),

          backgroundColor: colorVerde,

          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al autorizar: $e',
          ),

          backgroundColor: Colors.red,

          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // RECHAZAR
  // ============================================================

  Future<void> _rechazar(
    BuildContext context,
    SolicitudEdicion solicitud,
  ) async {
    final confirmar =
        await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Rechazar solicitud',

            style: TextStyle(
              color: colorPrincipal,
              fontWeight: FontWeight.bold,
            ),
          ),

          content: const Text(
            '¿Está seguro de rechazar esta solicitud de edición?',
          ),

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
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

                style: TextStyle(
                  color: colorPrincipal,
                ),
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
                foregroundColor: Colors.white,
                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8),
                ),
              ),

              child: const Text(
                'Rechazar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      await AutorizacionEdicionService
          .rechazarSolicitud(
        solicitudId: solicitud.id,
        autorizadoPor: nombreUsuario,
        autorizadoPorUid: uidUsuario,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud rechazada.',
          ),

          backgroundColor: Colors.red,

          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al rechazar: $e',
          ),

          backgroundColor: Colors.red,

          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }
}