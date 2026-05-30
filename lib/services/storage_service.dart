import 'package:flutter/material.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../models/recebivel.dart';
import 'supabase_service.dart';

class StorageService extends ChangeNotifier {
  StorageService._();
  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;

  List<Transacao> _transacoes = [];
  List<Grupo> _grupos = [];
  List<Recebivel> _recebiveis = [];

  List<Transacao> get transacoes => _transacoes;
  List<Grupo> get grupos => _grupos;
  List<Recebivel> get recebiveis => _recebiveis;

  Future<String?> init() async {
    final erro = await SupabaseService.initialize();
    if (erro != null) return erro;

    SupabaseService.initRealtime(onAnyChange: _onRealtimeChange);

    await carregarTudo();
    return null;
  }

  void disposeService() {
    SupabaseService.disposeRealtime();
    dispose();
  }

  Future<void> _onRealtimeChange() async {
    await carregarTudo();
  }

  Future<void> carregarTudo() async {
    try {
      _transacoes = await SupabaseService.fetchAllTransacoes();
      _grupos = await SupabaseService.fetchGrupos();
      _recebiveis = await SupabaseService.fetchAllRecebiveis();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarTransacoes() async {
    try {
      _transacoes = await SupabaseService.fetchAllTransacoes();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarGrupos() async {
    try {
      _grupos = await SupabaseService.fetchGrupos();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarRecebiveis() async {
    try {
      _recebiveis = await SupabaseService.fetchAllRecebiveis();
      notifyListeners();
    } catch (_) {}
  }

  // --- Transacoes ---

  Future<String?> adicionarTransacao(Transacao t) async {
    final erro = await SupabaseService.upsertTransacao(t);
    if (erro == null) {
      _transacoes.insert(0, t);
      notifyListeners();
    }
    return erro;
  }

  Future<String?> atualizarTransacao(Transacao t) async {
    final erro = await SupabaseService.upsertTransacao(t);
    if (erro == null) {
      final idx = _transacoes.indexWhere((tr) => tr.id == t.id);
      if (idx >= 0) _transacoes[idx] = t;
      notifyListeners();
    }
    return erro;
  }

  Future<String?> removerTransacao(String id) async {
    final erro = await SupabaseService.deleteTransacao(id);
    if (erro == null) {
      _transacoes.removeWhere((t) => t.id == id);
      notifyListeners();
    }
    return erro;
  }

  // --- Grupos ---

  Future<String?> adicionarGrupo(Grupo g) async {
    final erro = await SupabaseService.upsertGrupo(g);
    if (erro == null) {
      _grupos.add(g);
      notifyListeners();
    }
    return erro;
  }

  Future<String?> atualizarGrupo(Grupo g) async {
    final erro = await SupabaseService.upsertGrupo(g);
    if (erro == null) {
      final idx = _grupos.indexWhere((gr) => gr.id == g.id);
      if (idx >= 0) _grupos[idx] = g;
      notifyListeners();
    }
    return erro;
  }

  Future<String?> removerGrupo(String id) async {
    final erro = await SupabaseService.deleteGrupo(id);
    if (erro == null) {
      _grupos.removeWhere((g) => g.id == id);
      notifyListeners();
    }
    return erro;
  }

  // --- Recebiveis ---

  Future<String?> adicionarRecebivel(Recebivel r) async {
    final erro = await SupabaseService.upsertRecebivel(r);
    if (erro == null) {
      _recebiveis.insert(0, r);
      notifyListeners();
    }
    return erro;
  }

  Future<String?> atualizarRecebivel(Recebivel r) async {
    final erro = await SupabaseService.upsertRecebivel(r);
    if (erro == null) {
      final idx = _recebiveis.indexWhere((re) => re.id == r.id);
      if (idx >= 0) _recebiveis[idx] = r;
      notifyListeners();
    }
    return erro;
  }

  Future<String?> removerRecebivel(String id) async {
    final erro = await SupabaseService.deleteRecebivel(id);
    if (erro == null) {
      _recebiveis.removeWhere((r) => r.id == id);
      notifyListeners();
    }
    return erro;
  }

  // --- Helpers ---

  String? getNomeGrupo(String? grupoId) {
    if (grupoId == null) return null;
    final idx = _grupos.indexWhere((g) => g.id == grupoId);
    return idx >= 0 ? _grupos[idx].nome : null;
  }

  IconData? getIconeGrupo(String? grupoId) {
    if (grupoId == null) return null;
    final idx = _grupos.indexWhere((g) => g.id == grupoId);
    return idx >= 0 ? _grupos[idx].icone : null;
  }
}
