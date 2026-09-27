class Holiday {
  final DateTime date;
  final String name;
  final bool isIrrenunciable;

  Holiday({
    required this.date,
    required this.name,
    required this.isIrrenunciable,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: DateTime.parse(json['fecha'] as String),
      name: json['nombre'] as String,
      isIrrenunciable: json['irrenunciable'] == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'nombre': name,
      'irrenunciable': isIrrenunciable ? '1' : '0',
    };
  }
}
