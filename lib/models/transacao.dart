class Transacao {
  final String id;
  final String descricao;
  final double valor;
  final bool isReceita;
  final DateTime data;
  final String? grupoId;
  final String? recebivelId;
  final bool? isDigital;

  Transacao({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.isReceita,
    required this.data,
    this.grupoId,
    this.recebivelId,
    this.isDigital,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'descricao': descricao,
    'valor': valor,
    'isReceita': isReceita,
    'data': data.toIso8601String(),
    if (grupoId != null) 'grupoId': grupoId,
    if (recebivelId != null) 'recebivelId': recebivelId,
    if (isDigital != null) 'isDigital': isDigital,
  };

  factory Transacao.fromJson(Map<String, dynamic> json) => Transacao(
    id: json['id'],
    descricao: json['descricao'],
    valor: double.tryParse(json['valor'].toString()) ?? 0.0,
    isReceita: json['isReceita'],
    data: DateTime.parse(json['data']),
    grupoId: json['grupoId'],
    recebivelId: json['recebivelId'],
    isDigital: json['isDigital'],
  );

  String get mesAno => '${data.month.toString().padLeft(2, '0')}/${data.year}';
}
