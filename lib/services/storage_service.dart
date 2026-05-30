import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../models/recebivel.dart';
import 'supabase_service.dart';

class StorageService {
  static const _transacoesKey = 'transacoes';
  static const _gruposKey = 'grupos';
  static const _recebiveisKey = 'recebiveis';

  Future<List<Transacao>> carregarTransacoes() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_transacoesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Transacao.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> salvarTransacoes(List<Transacao> transacoes) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(transacoes.map((e) => e.toJson()).toList());
    await prefs.setString(_transacoesKey, json);
  }

  Future<void> adicionarTransacao(Transacao t) async {
    final transacoes = await carregarTransacoes();
    transacoes.add(t);
    await salvarTransacoes(transacoes);
    SupabaseService.upsertTransacao(t).catchError((_) => null);
  }

  Future<void> removerTransacao(String id) async {
    final transacoes = await carregarTransacoes();
    transacoes.removeWhere((t) => t.id == id);
    await salvarTransacoes(transacoes);
    SupabaseService.deleteTransacao(id).catchError((_) => null);
  }

  Future<void> atualizarTransacao(Transacao t) async {
    final transacoes = await carregarTransacoes();
    final idx = transacoes.indexWhere((tr) => tr.id == t.id);
    if (idx < 0) return;
    transacoes[idx] = t;
    await salvarTransacoes(transacoes);
    SupabaseService.upsertTransacao(t).catchError((_) => null);
  }

  Future<List<Grupo>> carregarGrupos() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_gruposKey);
    if (json == null) {
      final padrao = _gruposPadrao();
      await salvarGrupos(padrao);
      return padrao;
    }
    final list = jsonDecode(json) as List;
    var grupos = list.map((e) => Grupo.fromJson(e as Map<String, dynamic>)).toList();
    final idsExistentes = grupos.map((g) => g.id).toSet();
    final faltantes = _gruposPadrao().where((g) => !idsExistentes.contains(g.id)).toList();
    if (faltantes.isNotEmpty) {
      grupos.addAll(faltantes);
      await salvarGrupos(grupos);
    }
    return grupos;
  }

  Future<void> salvarGrupos(List<Grupo> grupos) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(grupos.map((e) => e.toJson()).toList());
    await prefs.setString(_gruposKey, json);
  }

  Future<void> adicionarGrupo(Grupo g) async {
    final grupos = await carregarGrupos();
    grupos.add(g);
    await salvarGrupos(grupos);
    SupabaseService.upsertGrupo(g).catchError((_) => null);
  }

  Future<void> removerGrupo(String id) async {
    final grupos = await carregarGrupos();
    grupos.removeWhere((g) => g.id == id);
    await salvarGrupos(grupos);
    SupabaseService.deleteGrupo(id).catchError((_) => null);
  }

  Future<void> atualizarGrupo(Grupo g) async {
    final grupos = await carregarGrupos();
    final idx = grupos.indexWhere((gr) => gr.id == g.id);
    if (idx < 0) return;
    grupos[idx] = g;
    await salvarGrupos(grupos);
    SupabaseService.upsertGrupo(g).catchError((_) => null);
  }

  Future<List<Recebivel>> carregarRecebiveis() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_recebiveisKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Recebivel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> salvarRecebiveis(List<Recebivel> recebiveis) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(recebiveis.map((e) => e.toJson()).toList());
    await prefs.setString(_recebiveisKey, json);
  }

  Future<void> adicionarRecebivel(Recebivel r) async {
    final recebiveis = await carregarRecebiveis();
    recebiveis.add(r);
    await salvarRecebiveis(recebiveis);
    SupabaseService.upsertRecebivel(r).catchError((_) => null);
  }

  Future<void> atualizarRecebivel(Recebivel r) async {
    final recebiveis = await carregarRecebiveis();
    final idx = recebiveis.indexWhere((re) => re.id == r.id);
    if (idx < 0) return;
    recebiveis[idx] = r;
    await salvarRecebiveis(recebiveis);
    SupabaseService.upsertRecebivel(r).catchError((_) => null);
  }

  Future<void> removerRecebivel(String id) async {
    final recebiveis = await carregarRecebiveis();
    recebiveis.removeWhere((r) => r.id == id);
    await salvarRecebiveis(recebiveis);
    SupabaseService.deleteRecebivel(id).catchError((_) => null);
  }

  String? getNomeGrupo(String? grupoId, List<Grupo> grupos) {
    if (grupoId == null) return null;
    final idx = grupos.indexWhere((g) => g.id == grupoId);
    return idx >= 0 ? grupos[idx].nome : null;
  }

  IconData? getIconeGrupo(String? grupoId, List<Grupo> grupos) {
    if (grupoId == null) return null;
    final idx = grupos.indexWhere((g) => g.id == grupoId);
    return idx >= 0 ? grupos[idx].icone : null;
  }

  List<Grupo> _gruposPadrao() => [
    Grupo(id: 'rec_salario', nome: 'Salário', isReceita: true, icone: Icons.work),
    Grupo(id: 'rec_freela', nome: 'Freelance', isReceita: true, icone: Icons.computer),
    Grupo(id: 'rec_invest', nome: 'Investimentos', isReceita: true, icone: Icons.trending_up),
    Grupo(id: 'rec_outros', nome: 'Outros', isReceita: true, icone: Icons.attach_money),
    Grupo(id: 'desp_alimentacao', nome: 'Alimentação', isReceita: false, icone: Icons.restaurant),
    Grupo(id: 'desp_transporte', nome: 'Transporte', isReceita: false, icone: Icons.directions_car),
    Grupo(id: 'desp_moradia', nome: 'Moradia', isReceita: false, icone: Icons.home),
    Grupo(id: 'desp_saude', nome: 'Saúde', isReceita: false, icone: Icons.local_hospital),
    Grupo(id: 'desp_lazer', nome: 'Lazer', isReceita: false, icone: Icons.sports_esports),
    Grupo(id: 'desp_educacao', nome: 'Educação', isReceita: false, icone: Icons.school),
    Grupo(id: 'desp_vestuario', nome: 'Vestuário', isReceita: false, icone: Icons.checkroom),
    Grupo(id: 'desp_outros', nome: 'Outros', isReceita: false, icone: Icons.more_horiz),
    Grupo(id: 'rcv_salario', nome: 'Salário', isReceita: true, isRecebivel: true, icone: Icons.work),
    Grupo(id: 'rcv_investimentos', nome: 'Investimentos', isReceita: true, isRecebivel: true, icone: Icons.trending_up),
    Grupo(id: 'rcv_aluguel', nome: 'Aluguel', isReceita: true, isRecebivel: true, icone: Icons.home),
    Grupo(id: 'rcv_outros', nome: 'Outros', isReceita: true, isRecebivel: true, icone: Icons.more_horiz),
  ];
}
