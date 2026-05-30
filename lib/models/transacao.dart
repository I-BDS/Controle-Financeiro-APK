class Transacao {
  final String id;
  final String descricao;
  final double valor;
  final bool isReceita;
  final DateTime data;
  final String? grupoId;
  final String? recebivelId;

  Transacao({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.isReceita,
    required this.data,
    this.grupoId,
    this.recebivelId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'descricao': descricao,
    'valor': valor,
    'isReceita': isReceita,
    'data': data.toIso8601String(),
    if (grupoId != null) 'grupoId': grupoId,
    if (recebivelId != null) 'recebivelId': recebivelId,
  };

  factory Transacao.fromJson(Map<String, dynamic> json) => Transacao(
    id: json['id'],
    descricao: json['descricao'],
    valor: json['valor'],
    isReceita: json['isReceita'],
    data: DateTime.parse(json['data']),
    grupoId: json['grupoId'],
    recebivelId: json['recebivelId'],
  );

  String get mesAno => '${data.month.toString().padLeft(2, '0')}/${data.year}';
}
