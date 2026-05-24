/// Configuración de conexión a PostgreSQL.
/// Estos valores se pueden mover a un archivo .env o secure_storage en producción.
class DbConstants {
  DbConstants._();

  static const String host = '192.168.1.100'; // IP del servidor (PC servidor)
  static const int port = 5432;
  static const String database = 'gestion_bodega';
  static const String username = 'bodega_user';
  static const String password = 'CAMBIAR_EN_PRODUCCION';

  static const Duration queryTimeout = Duration(seconds: 30);
}
