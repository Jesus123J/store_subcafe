class Validators {
  Validators._();

  static String? required(String? value, {String fieldName = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  static String? ruc(String? value) {
    if (value == null || value.isEmpty) return 'RUC requerido';
    if (value.length != 11) return 'RUC debe tener 11 dígitos';
    if (int.tryParse(value) == null) return 'RUC solo debe contener números';
    return null;
  }

  static String? dni(String? value) {
    if (value == null || value.isEmpty) return 'DNI requerido';
    if (value.length != 8) return 'DNI debe tener 8 dígitos';
    if (int.tryParse(value) == null) return 'DNI solo debe contener números';
    return null;
  }

  static String? minLength(String? value, int min) {
    if (value == null || value.length < min) {
      return 'Mínimo $min caracteres';
    }
    return null;
  }

  static String? positiveNumber(String? value) {
    if (value == null || value.isEmpty) return 'Requerido';
    final n = double.tryParse(value);
    if (n == null) return 'Debe ser un número';
    if (n < 0) return 'Debe ser positivo';
    return null;
  }
}
