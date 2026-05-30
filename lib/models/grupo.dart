import 'package:flutter/material.dart';

class Grupo {
  final String id;
  final String nome;
  final bool isReceita;
  final bool isRecebivel;
  final IconData icone;
  final double? limite;

  Grupo({
    required this.id,
    required this.nome,
    required this.isReceita,
    this.isRecebivel = false,
    this.icone = Icons.category,
    this.limite,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'isReceita': isReceita,
    'isRecebivel': isRecebivel,
    'iconCodePoint': icone.codePoint,
    if (limite != null) 'limite': limite,
  };

  factory Grupo.fromJson(Map<String, dynamic> json) => Grupo(
    id: json['id'],
    nome: json['nome'],
    isReceita: json['isReceita'],
    isRecebivel: json['isRecebivel'] ?? false,
    icone: IconData((json['iconCodePoint'] as int?) ?? Icons.category.codePoint),
    limite: (json['limite'] as num?)?.toDouble(),
  );
}
