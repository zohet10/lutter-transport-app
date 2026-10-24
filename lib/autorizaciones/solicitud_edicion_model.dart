class SolicitudEdicion {
  final String id;
  final String registroId;
  final String coleccion;
  final String formato;
  final String actividad;
  final String motivo;

  final String solicitadoPor;
  final String solicitadoPorUid;

  final DateTime? fechaSolicitud;

  final String estado;

  final String? autorizadoPor;
  final String? autorizadoPorUid;
  final DateTime? fechaAutorizacion;

  final DateTime? fechaFinalizacion;

  SolicitudEdicion({
    required this.id,
    required this.registroId,
    required this.coleccion,
    required this.formato,
    required this.actividad,
    required this.motivo,
    required this.solicitadoPor,
    required this.solicitadoPorUid,
    required this.fechaSolicitud,
    required this.estado,
    this.autorizadoPor,
    this.autorizadoPorUid,
    this.fechaAutorizacion,
    this.fechaFinalizacion,
  });

  factory SolicitudEdicion.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return SolicitudEdicion(
      id: id,
      registroId: data['registroId']?.toString() ?? '',
      coleccion: data['coleccion']?.toString() ?? '',
      formato: data['formato']?.toString() ?? '',
      actividad: data['actividad']?.toString() ?? '',
      motivo: data['motivo']?.toString() ?? '',
      solicitadoPor: data['solicitadoPor']?.toString() ?? '',
      solicitadoPorUid: data['solicitadoPorUid']?.toString() ?? '',
      fechaSolicitud: _convertirFecha(data['fechaSolicitud']),
      estado: data['estado']?.toString() ?? 'pendiente',
      autorizadoPor: data['autorizadoPor']?.toString(),
      autorizadoPorUid: data['autorizadoPorUid']?.toString(),
      fechaAutorizacion: _convertirFecha(
        data['fechaAutorizacion'],
      ),
      fechaFinalizacion: _convertirFecha(
        data['fechaFinalizacion'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'registroId': registroId,
      'coleccion': coleccion,
      'formato': formato,
      'actividad': actividad,
      'motivo': motivo,
      'solicitadoPor': solicitadoPor,
      'solicitadoPorUid': solicitadoPorUid,
      'fechaSolicitud': fechaSolicitud,
      'estado': estado,
      'autorizadoPor': autorizadoPor,
      'autorizadoPorUid': autorizadoPorUid,
      'fechaAutorizacion': fechaAutorizacion,
      'fechaFinalizacion': fechaFinalizacion,
    };
  }

  static DateTime? _convertirFecha(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is DateTime) {
      return valor;
    }

    // Compatible con Timestamp de Firebase
    try {
      return valor.toDate();
    } catch (_) {}

    if (valor is String) {
      return DateTime.tryParse(valor);
    }

    return null;
  }
}