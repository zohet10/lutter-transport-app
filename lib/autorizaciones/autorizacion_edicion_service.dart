import 'package:cloud_firestore/cloud_firestore.dart';

import 'solicitud_edicion_model.dart';

class AutorizacionEdicionService {
  static final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  static const String coleccionSolicitudes =
      'solicitudes_edicion';

  // ============================================================
  // CREAR SOLICITUD
  // ============================================================

  static Future<String> crearSolicitud({
    required String registroId,
    required String coleccion,
    required String formato,
    required String actividad,
    required String motivo,
    required String solicitadoPor,
    required String solicitadoPorUid,
  }) async {
    // Antes de crear una solicitud verificamos si ya existe
    // una solicitud pendiente o autorizada para ese registro.

    final existentes = await _db
        .collection(coleccionSolicitudes)
        .where(
          'registroId',
          isEqualTo: registroId,
        )
        .get();

    for (final documento in existentes.docs) {
      final data = documento.data();

      final mismaColeccion =
          data['coleccion']?.toString() == coleccion;

      final estado =
          data['estado']?.toString() ?? '';

      if (mismaColeccion &&
          (estado == 'pendiente' ||
              estado == 'autorizada')) {
        throw Exception(
          'Ya existe una solicitud pendiente o autorizada para este registro.',
        );
      }
    }

    final referencia = await _db
        .collection(coleccionSolicitudes)
        .add({
      'registroId': registroId,
      'coleccion': coleccion,
      'formato': formato,
      'actividad': actividad,
      'motivo': motivo,

      'solicitadoPor': solicitadoPor,
      'solicitadoPorUid': solicitadoPorUid,

      'fechaSolicitud':
          FieldValue.serverTimestamp(),

      'estado': 'pendiente',

      'autorizadoPor': null,
      'autorizadoPorUid': null,
      'fechaAutorizacion': null,

      'fechaFinalizacion': null,
    });

    return referencia.id;
  }

  // ============================================================
  // OBTENER SOLICITUD DE UN REGISTRO
  // ============================================================

  static Future<SolicitudEdicion?> obtenerSolicitudRegistro({
    required String registroId,
    required String coleccion,
  }) async {
    final resultado = await _db
        .collection(coleccionSolicitudes)
        .where(
          'registroId',
          isEqualTo: registroId,
        )
        .get();

    SolicitudEdicion? mejorSolicitud;

    for (final documento in resultado.docs) {
      final data = documento.data();

      if (data['coleccion']?.toString() != coleccion) {
        continue;
      }

      final solicitud = SolicitudEdicion.fromMap(
        documento.id,
        data,
      );

      // Preferimos una solicitud pendiente o autorizada.
      if (solicitud.estado == 'pendiente' ||
          solicitud.estado == 'autorizada') {
        return solicitud;
      }

      mejorSolicitud ??= solicitud;
    }

    return mejorSolicitud;
  }

  // ============================================================
  // VERIFICAR SI EL JEFE PUEDE EDITAR
  // ============================================================

  static Future<bool> puedeEditarRegistro({
    required String registroId,
    required String coleccion,
    required String usuarioUid,
  }) async {
    final solicitud = await obtenerSolicitudRegistro(
      registroId: registroId,
      coleccion: coleccion,
    );

    if (solicitud == null) {
      return false;
    }

    if (solicitud.estado != 'autorizada') {
      return false;
    }

    // La autorización pertenece al registro y fue solicitada
    // por el usuario correspondiente.
    if (solicitud.solicitadoPorUid != usuarioUid) {
      return false;
    }

    return true;
  }

  // ============================================================
  // AUTORIZAR
  // ============================================================

  static Future<void> autorizarSolicitud({
    required String solicitudId,
    required String autorizadoPor,
    required String autorizadoPorUid,
  }) async {
    await _db
        .collection(coleccionSolicitudes)
        .doc(solicitudId)
        .update({
      'estado': 'autorizada',
      'autorizadoPor': autorizadoPor,
      'autorizadoPorUid': autorizadoPorUid,
      'fechaAutorizacion':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // RECHAZAR
  // ============================================================

  static Future<void> rechazarSolicitud({
    required String solicitudId,
    required String autorizadoPor,
    required String autorizadoPorUid,
  }) async {
    await _db
        .collection(coleccionSolicitudes)
        .doc(solicitudId)
        .update({
      'estado': 'rechazada',
      'autorizadoPor': autorizadoPor,
      'autorizadoPorUid': autorizadoPorUid,
      'fechaAutorizacion':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // COMPLETAR SOLICITUD
  // ============================================================

  static Future<void> completarSolicitud({
    required String solicitudId,
  }) async {
    await _db
        .collection(coleccionSolicitudes)
        .doc(solicitudId)
        .update({
      'estado': 'completada',
      'fechaFinalizacion':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // CANCELAR / RECHAZAR UNA SOLICITUD PENDIENTE
  // ============================================================

  static Future<void> cancelarSolicitud({
    required String solicitudId,
  }) async {
    await _db
        .collection(coleccionSolicitudes)
        .doc(solicitudId)
        .update({
      'estado': 'cancelada',
      'fechaFinalizacion':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // STREAM DE SOLICITUDES
  // ============================================================

  static Stream<List<SolicitudEdicion>>
      escucharSolicitudes() {
    return _db
        .collection(coleccionSolicitudes)
        .snapshots()
        .map((snapshot) {
      final solicitudes = snapshot.docs.map((doc) {
        return SolicitudEdicion.fromMap(
          doc.id,
          doc.data(),
        );
      }).toList();

      // Más recientes primero.
      solicitudes.sort((a, b) {
        final fechaA = a.fechaSolicitud;
        final fechaB = b.fechaSolicitud;

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

      return solicitudes;
    });
  }
}