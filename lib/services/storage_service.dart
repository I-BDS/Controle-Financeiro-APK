import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../models/recebivel.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

enum StorageMode { local, supabase }

class StorageService extends ChangeNotifier {
  StorageService._();
  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;

  StorageMode _storageMode = StorageMode.supabase;
  StorageMode get storageMode => _storageMode;

  // Currently loaded period tracking (used for scoped sync and realtime reload)
  int? transacoesMes;
  int? transacoesAno;
  int? recebiveisMesInicio;
  int? recebiveisAnoInicio;
  int? recebiveisMesFim;
  int? recebiveisAnoFim;
  int? analiseAno;

  List<Transacao> _transacoes = [];
  List<Grupo> _grupos = [];
  List<Recebivel> _recebiveis = [];

  List<Transacao> get transacoes => _transacoes;
  List<Grupo> get grupos => _grupos;
  List<Recebivel> get recebiveis => _recebiveis;

  Future<String?> init() async {
    await _initMode();

    if (_storageMode == StorageMode.local) {
      await _carregarInicial();
      return null;
    }

    final erro = await SupabaseService.initialize();
    if (erro != null) return erro;

    SupabaseService.initRealtime(onAnyChange: _onRealtimeChange);
    await _carregarInicial();
    return null;
  }

  Future<void> _initMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('storage_mode');
    _storageMode = modeStr == 'local' ? StorageMode.local : StorageMode.supabase;
  }

  void disposeService() {
    SupabaseService.disposeRealtime();
    dispose();
  }

  Future<void> _onRealtimeChange() async {
    if (transacoesMes != null && transacoesAno != null) {
      await carregarTransacoesMesAno(transacoesMes!, transacoesAno!);
    }
    if (recebiveisMesInicio != null) {
      await carregarRecebiveisPeriodo(
        recebiveisMesInicio!, recebiveisAnoInicio!,
        recebiveisMesFim, recebiveisAnoFim,
      );
    }
    try {
      _grupos = await SupabaseService.fetchGrupos();
    } catch (_) {}
    notifyListeners();
  }

  // --- Initial load (lightweight) ---

  Future<void> _carregarInicial() async {
    try {
      if (_storageMode == StorageMode.local) {
        _grupos = await LocalStorageService.carregarGrupos();
        _transacoes = await LocalStorageService.carregarTransacoes();
        _recebiveis = await LocalStorageService.carregarRecebiveis();
      } else {
        _grupos = await SupabaseService.fetchGrupos();
        // Load current month as default
        final now = DateTime.now();
        transacoesMes = now.month;
        transacoesAno = now.year;
        _transacoes = await SupabaseService.fetchTransacoesPorMesAno(now.month, now.year);
        recebiveisMesInicio = now.month;
        recebiveisAnoInicio = now.year;
        _recebiveis = await SupabaseService.fetchRecebiveisPorPeriodo(now.month, now.year, null, null);
      }
      notifyListeners();
    } catch (_) {}
  }

  // --- Period-specific load methods ---

  Future<void> carregarTransacoesMesAno(int mes, int ano) async {
    transacoesMes = mes;
    transacoesAno = ano;
    try {
      if (_storageMode == StorageMode.local) {
        _transacoes = await LocalStorageService.carregarTransacoes();
      } else {
        _transacoes = await SupabaseService.fetchTransacoesPorMesAno(mes, ano);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarTransacoesAno(int ano) async {
    transacoesMes = null;
    transacoesAno = ano;
    try {
      if (_storageMode == StorageMode.local) {
        _transacoes = await LocalStorageService.carregarTransacoes();
      } else {
        _transacoes = await SupabaseService.fetchTransacoesPorAno(ano);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarTransacoesPeriodo(DateTime inicio, DateTime fim) async {
    transacoesMes = null;
    transacoesAno = null;
    try {
      if (_storageMode == StorageMode.local) {
        _transacoes = await LocalStorageService.carregarTransacoes();
      } else {
        _transacoes = await SupabaseService.fetchTransacoesPorPeriodo(inicio, fim);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarRecebiveisPeriodo(
    int mesInicio, int anoInicio, int? mesFim, int? anoFim,
  ) async {
    recebiveisMesInicio = mesInicio;
    recebiveisAnoInicio = anoInicio;
    recebiveisMesFim = mesFim;
    recebiveisAnoFim = anoFim;
    try {
      if (_storageMode == StorageMode.local) {
        _recebiveis = await LocalStorageService.carregarRecebiveis();
      } else {
        _recebiveis = await SupabaseService.fetchRecebiveisPorPeriodo(mesInicio, anoInicio, mesFim, anoFim);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarRecebiveisAno(int ano) async {
    recebiveisMesInicio = null;
    recebiveisAnoInicio = ano;
    try {
      if (_storageMode == StorageMode.local) {
        _recebiveis = await LocalStorageService.carregarRecebiveis();
      } else {
        _recebiveis = await SupabaseService.fetchRecebiveisPorAno(ano);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> carregarGrupos() async {
    try {
      if (_storageMode == StorageMode.local) {
        _grupos = await LocalStorageService.carregarGrupos();
      } else {
        _grupos = await SupabaseService.fetchGrupos();
      }
      notifyListeners();
    } catch (_) {}
  }

  // --- CRUD Transacoes ---

  Future<String?> adicionarTransacao(Transacao t) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarTransacoes();
      list.insert(0, t);
      await LocalStorageService.salvarTransacoes(list);
      _transacoes.insert(0, t);
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.upsertTransacao(t);
    if (erro == null) {
      _transacoes.insert(0, t);
      notifyListeners();
    }
    return erro;
  }

  Future<String?> atualizarTransacao(Transacao t) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarTransacoes();
      final idx = list.indexWhere((tr) => tr.id == t.id);
      if (idx >= 0) list[idx] = t;
      await LocalStorageService.salvarTransacoes(list);
      final idx2 = _transacoes.indexWhere((tr) => tr.id == t.id);
      if (idx2 >= 0) _transacoes[idx2] = t;
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.upsertTransacao(t);
    if (erro == null) {
      final idx = _transacoes.indexWhere((tr) => tr.id == t.id);
      if (idx >= 0) _transacoes[idx] = t;
      notifyListeners();
    }
    return erro;
  }

  Future<String?> removerTransacao(String id) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarTransacoes();
      list.removeWhere((t) => t.id == id);
      await LocalStorageService.salvarTransacoes(list);
      _transacoes.removeWhere((t) => t.id == id);
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.deleteTransacao(id);
    if (erro == null) {
      _transacoes.removeWhere((t) => t.id == id);
      notifyListeners();
    }
    return erro;
  }

  // --- CRUD Grupos ---

  Future<String?> adicionarGrupo(Grupo g) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarGrupos();
      list.add(g);
      await LocalStorageService.salvarGrupos(list);
      _grupos.add(g);
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.upsertGrupo(g);
    if (erro == null) {
      _grupos.add(g);
      notifyListeners();
    }
    return erro;
  }

  Future<String?> atualizarGrupo(Grupo g) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarGrupos();
      final idx = list.indexWhere((gr) => gr.id == g.id);
      if (idx >= 0) list[idx] = g;
      await LocalStorageService.salvarGrupos(list);
      final idx2 = _grupos.indexWhere((gr) => gr.id == g.id);
      if (idx2 >= 0) _grupos[idx2] = g;
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.upsertGrupo(g);
    if (erro == null) {
      final idx = _grupos.indexWhere((gr) => gr.id == g.id);
      if (idx >= 0) _grupos[idx] = g;
      notifyListeners();
    }
    return erro;
  }

  Future<String?> removerGrupo(String id) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarGrupos();
      list.removeWhere((g) => g.id == id);
      await LocalStorageService.salvarGrupos(list);
      _grupos.removeWhere((g) => g.id == id);
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.deleteGrupo(id);
    if (erro == null) {
      _grupos.removeWhere((g) => g.id == id);
      notifyListeners();
    }
    return erro;
  }

  // --- CRUD Recebiveis ---

  Future<String?> adicionarRecebivel(Recebivel r) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarRecebiveis();
      list.insert(0, r);
      await LocalStorageService.salvarRecebiveis(list);
      _recebiveis.insert(0, r);
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.upsertRecebivel(r);
    if (erro == null) {
      _recebiveis.insert(0, r);
      notifyListeners();
    }
    return erro;
  }

  Future<String?> atualizarRecebivel(Recebivel r) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarRecebiveis();
      final idx = list.indexWhere((re) => re.id == r.id);
      if (idx >= 0) list[idx] = r;
      await LocalStorageService.salvarRecebiveis(list);
      final idx2 = _recebiveis.indexWhere((re) => re.id == r.id);
      if (idx2 >= 0) _recebiveis[idx2] = r;
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.upsertRecebivel(r);
    if (erro == null) {
      final idx = _recebiveis.indexWhere((re) => re.id == r.id);
      if (idx >= 0) _recebiveis[idx] = r;
      notifyListeners();
    }
    return erro;
  }

  Future<String?> removerRecebivel(String id) async {
    if (_storageMode == StorageMode.local) {
      final list = await LocalStorageService.carregarRecebiveis();
      list.removeWhere((r) => r.id == id);
      await LocalStorageService.salvarRecebiveis(list);
      _recebiveis.removeWhere((r) => r.id == id);
      notifyListeners();
      return null;
    }
    final erro = await SupabaseService.deleteRecebivel(id);
    if (erro == null) {
      _recebiveis.removeWhere((r) => r.id == id);
      notifyListeners();
    }
    return erro;
  }

  // --- Mode Switching ---

  Future<String?> switchToLocal() async {
    await LocalStorageService.salvarTransacoes(_transacoes);
    await LocalStorageService.salvarGrupos(_grupos);
    await LocalStorageService.salvarRecebiveis(_recebiveis);

    SupabaseService.disposeRealtime();
    _storageMode = StorageMode.local;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storage_mode', 'local');

    notifyListeners();
    return null;
  }

  Future<String?> switchToSupabase({bool onlyLoad = false}) async {
    final erro = await SupabaseService.initialize();
    if (erro != null) return erro;

    if (!onlyLoad) {
      // Determine scope: use tracked period or fallback to all data
      final escopoTransacoes = transacoesMes != null && transacoesAno != null;
      final escopoAno = analiseAno != null;

      if (escopoTransacoes) {
        final mes = transacoesMes!;
        final ano = transacoesAno!;
        try {
          final dbList = await SupabaseService.fetchTransacoesPorMesAno(mes, ano);
          final idsLocais = _transacoes.where((t) {
            final d = t.data;
            return d.year == ano && d.month == mes;
          }).map((t) => t.id).toSet();
          for (final t in dbList) {
            if (!idsLocais.contains(t.id)) {
              final e = await SupabaseService.deleteTransacao(t.id);
              if (e != null) return e;
            }
          }
        } catch (_) {}
        for (final t in _transacoes) {
          if (t.data.year == ano && t.data.month == mes) {
            final e = await SupabaseService.upsertTransacao(t);
            if (e != null) return e;
          }
        }
      } else if (escopoAno) {
        // Sync by year (analytics scope)
        final ano = analiseAno!;
        try {
          final dbList = await SupabaseService.fetchTransacoesPorAno(ano);
          final idsLocais = _transacoes.where((t) => t.data.year == ano).map((t) => t.id).toSet();
          for (final t in dbList) {
            if (!idsLocais.contains(t.id)) {
              final e = await SupabaseService.deleteTransacao(t.id);
              if (e != null) return e;
            }
          }
        } catch (_) {}
        for (final t in _transacoes) {
          if (t.data.year == ano) {
            final e = await SupabaseService.upsertTransacao(t);
            if (e != null) return e;
          }
        }
      } else {
        // No tracked scope — sync all local data
        try {
          final dbList = await SupabaseService.fetchAllTransacoes();
          final idsLocais = _transacoes.map((t) => t.id).toSet();
          for (final t in dbList) {
            if (!idsLocais.contains(t.id)) {
              final e = await SupabaseService.deleteTransacao(t.id);
              if (e != null) return e;
            }
          }
        } catch (_) {}
        for (final t in _transacoes) {
          final e = await SupabaseService.upsertTransacao(t);
          if (e != null) return e;
        }
      }

      // Always sync grupos fully (small dataset)
      try {
        final dbList = await SupabaseService.fetchGrupos();
        final idsLocais = _grupos.map((g) => g.id).toSet();
        for (final g in dbList) {
          if (!idsLocais.contains(g.id)) {
            final e = await SupabaseService.deleteGrupo(g.id);
            if (e != null) return e;
          }
        }
      } catch (_) {}
      for (final g in _grupos) {
        final e = await SupabaseService.upsertGrupo(g);
        if (e != null) return e;
      }

      // Sync recebiveis by tracked period or all
      if (recebiveisMesInicio != null) {
        try {
          final dbList = await SupabaseService.fetchRecebiveisPorPeriodo(
            recebiveisMesInicio!, recebiveisAnoInicio!, recebiveisMesFim, recebiveisAnoFim,
          );
          final idsLocais = _recebiveis.map((r) => r.id).toSet();
          for (final r in dbList) {
            if (!idsLocais.contains(r.id)) {
              final e = await SupabaseService.deleteRecebivel(r.id);
              if (e != null) return e;
            }
          }
        } catch (_) {}
        for (final r in _recebiveis) {
          final e = await SupabaseService.upsertRecebivel(r);
          if (e != null) return e;
        }
      }
    }

    await LocalStorageService.limparTudo();
    SupabaseService.initRealtime(onAnyChange: _onRealtimeChange);
    _storageMode = StorageMode.supabase;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storage_mode', 'supabase');

    await _carregarInicial();
    return null;
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
