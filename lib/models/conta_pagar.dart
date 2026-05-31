class ContaPagar {
  final String id;
  final String descricao;
  final double valor;
  final int mes;
  final int ano;
  final DateTime? data;
  final String? grupoId;
  final bool pago;
  final bool recorrente;
  final int? mesFim;
  final int? anoFim;
  final bool? isDigital;

  ContaPagar({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.mes,
    required this.ano,
    this.data,
    this.grupoId,
    this.pago = false,
    this.recorrente = false,
    this.mesFim,
    this.anoFim,
    this.isDigital,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'descricao': descricao,
    'valor': valor,
    'mes': mes,
    'ano': ano,
    if (data != null) 'data': data!.toIso8601String(),
    if (grupoId != null) 'grupoId': grupoId,
    'pago': pago,
    'recorrente': recorrente,
    if (mesFim != null) 'mesFim': mesFim,
    if (anoFim != null) 'anoFim': anoFim,
    if (isDigital != null) 'isDigital': isDigital,
  };

  factory ContaPagar.fromJson(Map<String, dynamic> json) => ContaPagar(
    id: json['id'],
    descricao: json['descricao'],
    valor: double.tryParse(json['valor'].toString()) ?? 0.0,
    mes: json['mes'] ?? 1,
    ano: json['ano'] ?? DateTime.now().year,
    data: json['data'] != null ? DateTime.parse(json['data']) : null,
    grupoId: json['grupoId'],
    pago: json['pago'] ?? false,
    recorrente: json['recorrente'] ?? false,
    mesFim: json['mesFim'],
    anoFim: json['anoFim'],
    isDigital: json['isDigital'],
  );

  String get mesAno => '${mes.toString().padLeft(2, '0')}/$ano';
}
