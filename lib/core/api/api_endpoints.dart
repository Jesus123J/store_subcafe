class ApiEndpoints {
  ApiEndpoints._();

  // Cambiar a la IP del servidor en LAN, ej: http://192.168.1.100:8080/api
  static const String baseUrl = 'http://localhost:8080/api';

  // Auth
  static const String login = '/auth/login';

  // Usuarios
  static const String usuarios = '/usuarios';
  static String usuarioById(String id) => '/usuarios/$id';

  // Proveedores
  static const String proveedores = '/proveedores';

  // Productos
  static const String productos = '/productos';

  // Ventas
  static const String ventas = '/ventas';

  // Compras
  static const String compras = '/compras';

  // Cajas
  static const String cajas = '/cajas';
  static const String cajaAbierta = '/cajas/abierta';
  static const String abrirCaja = '/cajas/abrir';
  static String cerrarCaja(String id) => '/cajas/$id/cerrar';
  static String avanceCaja(String id) => '/cajas/$id/avances';

  // Créditos
  static const String creditos = '/creditos';

  // Reportes
  static const String reporteVentasDiarias = '/reportes/ventas-diarias';
  static const String reporteStock = '/reportes/stock';
  static const String reporteStockBajo = '/reportes/stock-bajo';
  static const String reporteTopProductos = '/reportes/top-productos';
  static const String reporteCreditos = '/reportes/creditos';

  // Configuración
  static const String configuracion = '/configuracion';

  // Clientes (publico general de bodega — puntos/vales)
  static const String clientes = '/clientes';
  static const String clientesImport = '/clientes/import';

  // Trabajadores (passthrough a FinantialTracker.employees — sin tabla local)
  static const String trabajadores = '/trabajadores';

  // Vales
  static const String vales = '/vales';
  static const String emitirVale = '/vales/emitir';
  static String anularVale(String id) => '/vales/$id/anular';

  // Puntos
  static const String puntosSaldos = '/puntos/saldos';
  static const String puntosCanjeables = '/puntos/canjeables';
  static const String puntosReglaActiva = '/puntos/regla-activa';

  // Créditos: cierre mensual
  static const String creditosDelMes = '/creditos/del-mes';
  static const String creditosDeudaAcumulada = '/creditos/deuda-acumulada';
  static const String creditosCierres = '/creditos/cierres';
  static const String creditosCerrarMes = '/creditos/cerrar-mes';

  // Integracion FinantialTracker (planilla del HSJ)
  static const String ftEnvios = '/integracion/ft/envios';
  static const String ftHealth = '/integracion/ft/health';
  static String ftEnviarCierre(String cierreId) =>
      '/integracion/ft/enviar-cierre/$cierreId';
  static String ftEnviarCredito(String creditoId) =>
      '/integracion/ft/enviar-credito/$creditoId';
  static String ftRevertir(String envioId) =>
      '/integracion/ft/revertir/$envioId';
}
