class Vehiculo {
  Vehiculo({
    required this.id,
    required this.placa,
    this.marca,
    this.modelo,
    this.anio,
    this.color,
    this.tipoCombustible,
  });

  final String id;
  final String placa;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? color;
  final String? tipoCombustible;

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: json['id'] as String,
      placa: json['placa'] as String,
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      anio: json['anio'] as int?,
      color: json['color'] as String?,
      tipoCombustible: json['tipo_combustible'] as String?,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'placa': placa,
        if (marca != null) 'marca': marca,
        if (modelo != null) 'modelo': modelo,
        if (anio != null) 'anio': anio,
        if (color != null) 'color': color,
        if (tipoCombustible != null) 'tipo_combustible': tipoCombustible,
      };

  String get label {
    final parts = [placa, marca, modelo].whereType<String>().where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }
}
