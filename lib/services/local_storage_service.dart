import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../models/recebivel.dart';

class LocalStorageService {
  static const _transacoesKey = 'local_transacoes';
  static const _gruposKey = 'local_grupos';
  static const _recebiveisKey = 'local_recebiveis';

  // --- Transacoes ---

  static Future<List<Transacao>> carregarTransacoes() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_transacoesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Transacao.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> salvarTransacoes(List<Transacao> transacoes) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(transacoes.map((t) => t.toJson()).toList());
    await prefs.setString(_transacoesKey, json);
  }

  // --- Grupos ---

  static Future<List<Grupo>> carregarGrupos() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_gruposKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Grupo.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> salvarGrupos(List<Grupo> grupos) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(grupos.map((g) => g.toJson()).toList());
    await prefs.setString(_gruposKey, json);
  }

  // --- Recebiveis ---

  static Future<List<Recebivel>> carregarRecebiveis() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_recebiveisKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Recebivel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> salvarRecebiveis(List<Recebivel> recebiveis) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(recebiveis.map((r) => r.toJson()).toList());
    await prefs.setString(_recebiveisKey, json);
  }

  // --- Utils ---

  static Future<bool> temDados() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_transacoesKey) ||
        prefs.containsKey(_gruposKey) ||
        prefs.containsKey(_recebiveisKey);
  }

  static Future<void> limparTudo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transacoesKey);
    await prefs.remove(_gruposKey);
    await prefs.remove(_recebiveisKey);
  }
}
