import 'package:intl/intl.dart';

class ControlZafra {
  /// Valida si una fecha (dd/MM/yyyy) pertenece a la semana operativa actual.
  ///
  /// La semana operativa va de DOMINGO a SÁBADO.
  ///
  /// Ejemplo:
  /// Domingo 30/08/2026
  /// hasta
  /// Sábado 05/09/2026
  ///
  /// A partir del domingo 06/09/2026,
  /// la semana anterior queda cerrada para Supervisor/Jefe.
  static bool esSemanaActualEditable(String fechaStr) {
    try {
      final partes = fechaStr.split('/');

      if (partes.length != 3) return false;

      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final anio = int.parse(partes[2]);

      final fechaRegistro = DateTime(anio, mes, dia);

      final now = DateTime.now();

      final hoy = DateTime(
        now.year,
        now.month,
        now.day,
      );

      // Dart:
      // Lunes = 1
      // Martes = 2
      // Miércoles = 3
      // Jueves = 4
      // Viernes = 5
      // Sábado = 6
      // Domingo = 7

      // Calculamos el domingo de la semana actual.
      final diasDesdeDomingo = now.weekday == DateTime.sunday
          ? 0
          : now.weekday;

      final inicioSemana = hoy.subtract(
        Duration(days: diasDesdeDomingo),
      );

      // El sábado es 6 días después del domingo.
      final finSemana = inicioSemana.add(
        const Duration(days: 6),
      );

      // La fecha solamente es editable si está
      // entre domingo y sábado de esta semana.
      return !fechaRegistro.isBefore(inicioSemana) &&
          !fechaRegistro.isAfter(finSemana);
    } catch (e) {
      // Si no se puede interpretar la fecha,
      // por seguridad se bloquea.
      return false;
    }
  }
}