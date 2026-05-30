import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../models/recebivel.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;

  static const _urlKey = 'supabase_url';
  static const _anonKey = 'supabase_anon_key';

  static Future<Map<String, String>> carregarCredenciais() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString(_urlKey) ?? '',
      'anonKey': prefs.getString(_anonKey) ?? '',
    };
  }

  static Future<void> salvarCredenciais(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
    await prefs.setString(_anonKey, anonKey);
  }

  static bool get isConfigured => _initialized && _client != null;

  static String _sanitizarUrl(String url) {
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.contains('/rest/v1')) {
      url = url.split('/rest/v1').first;
    }
    return url;
  }

  static Future<String?> initialize() async {
    final creds = await carregarCredenciais();
    if (creds['url']!.isEmpty || creds['anonKey']!.isEmpty) {
      return 'Credenciais não configuradas.';
    }
    try {
      final url = _sanitizarUrl(creds['url']!);
      _client = SupabaseClient(url, creds['anonKey']!);
      _initialized = true;
      return null;
    } catch (e) {
      _initialized = false;
      return 'Erro ao conectar: $e';
    }
  }

  static String? _tratarErro(dynamic e, String tabela) {
    final msg = e.toString();
    if (msg.contains('PGRST125')) {
      return 'Tabela "$tabela" não encontrada. Vá em Supabase > API > "Refresh schema cache" ou execute: NOTIFY pgrst, \'reload schema\';';
    }
    return 'Erro ao sincronizar $tabela: $e';
  }

  // --- Transacoes ---

  static Future<String?> upsertTransacao(Transacao t) async {
    if (!isConfigured) return null;
    try {
      await _client!.from('transacoes').upsert(t.toJson());
      return null;
    } catch (e) {
      return _tratarErro(e, 'transacoes');
    }
  }

  static Future<String?> deleteTransacao(String id) async {
    if (!isConfigured) return null;
    try {
      await _client!.from('transacoes').delete().eq('id', id);
      return null;
    } catch (e) {
      return _tratarErro(e, 'transacoes');
    }
  }

  static Future<String?> _syncTransacoes(List<Transacao> transacoes) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      final data = transacoes.map((t) => t.toJson()).toList();
      await _client!.from('transacoes').upsert(data);
      return null;
    } catch (e) {
      return _tratarErro(e, 'transacoes');
    }
  }

  static Future<List<Transacao>> fetchTransacoesPorAno(int ano) async {
    final inicio = DateTime(ano, 1, 1).toIso8601String();
    final fim = DateTime(ano, 12, 31, 23, 59, 59).toIso8601String();
    final response = await _client!
        .from('transacoes')
        .select()
        .gte('data', inicio)
        .lte('data', fim);
    return (response as List)
        .map((e) => Transacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Grupos ---

  static Future<String?> upsertGrupo(Grupo g) async {
    if (!isConfigured) return null;
    try {
      await _client!.from('grupos').upsert(g.toJson());
      return null;
    } catch (e) {
      return _tratarErro(e, 'grupos');
    }
  }

  static Future<String?> deleteGrupo(String id) async {
    if (!isConfigured) return null;
    try {
      await _client!.from('grupos').delete().eq('id', id);
      return null;
    } catch (e) {
      return _tratarErro(e, 'grupos');
    }
  }

  static Future<String?> _syncGrupos(List<Grupo> grupos) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      final data = grupos.map((g) => g.toJson()).toList();
      await _client!.from('grupos').upsert(data);
      return null;
    } catch (e) {
      return _tratarErro(e, 'grupos');
    }
  }

  static Future<List<Grupo>> fetchGrupos() async {
    final response = await _client!.from('grupos').select();
    return (response as List)
        .map((e) => Grupo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Recebiveis ---

  static Future<String?> upsertRecebivel(Recebivel r) async {
    if (!isConfigured) return null;
    try {
      await _client!.from('recebiveis').upsert(r.toJson());
      return null;
    } catch (e) {
      return _tratarErro(e, 'recebiveis');
    }
  }

  static Future<String?> deleteRecebivel(String id) async {
    if (!isConfigured) return null;
    try {
      await _client!.from('recebiveis').delete().eq('id', id);
      return null;
    } catch (e) {
      return _tratarErro(e, 'recebiveis');
    }
  }

  static Future<String?> _syncRecebiveis(List<Recebivel> recebiveis) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      final data = recebiveis.map((r) => r.toJson()).toList();
      await _client!.from('recebiveis').upsert(data);
      return null;
    } catch (e) {
      return _tratarErro(e, 'recebiveis');
    }
  }

  static Future<List<Recebivel>> fetchRecebiveisPorAno(int ano) async {
    final response = await _client!.from('recebiveis').select();
    return (response as List)
        .map((e) => Recebivel.fromJson(e as Map<String, dynamic>))
        .where((r) => r.ano <= ano && (r.anoFim == null || r.anoFim! >= ano))
        .toList();
  }

  // --- Sync inicial / fundo ---

  static Future<String?> syncAno({
    required int ano,
    required List<Transacao> transacoesLocais,
    required List<Grupo> gruposLocais,
    required List<Recebivel> recebiveisLocais,
    required Future<void> Function(List<Transacao>) salvarTransacoes,
    required Future<void> Function(List<Grupo>) salvarGrupos,
    required Future<void> Function(List<Recebivel>) salvarRecebiveis,
  }) async {
    final erro = await initialize();
    if (erro != null) return erro;

    try {
      final transacoesCloud = await fetchTransacoesPorAno(ano);
      final recebiveisCloud = await fetchRecebiveisPorAno(ano);
      final gruposCloud = await fetchGrupos();

      final localTIds = transacoesLocais.map((t) => t.id).toSet();
      final localRIds = recebiveisLocais.map((r) => r.id).toSet();
      final localGIds = gruposLocais.map((g) => g.id).toSet();

      final cloudTIds = transacoesCloud.map((t) => t.id).toSet();
      final cloudRIds = recebiveisCloud.map((r) => r.id).toSet();
      final cloudGIds = gruposCloud.map((g) => g.id).toSet();

      final uploadT = transacoesLocais.where((t) => !cloudTIds.contains(t.id)).toList();
      final uploadR = recebiveisLocais.where((r) => !cloudRIds.contains(r.id)).toList();
      final uploadG = gruposLocais.where((g) => !cloudGIds.contains(g.id)).toList();

      if (uploadT.isNotEmpty) {
        final r = await _syncTransacoes(uploadT);
        if (r != null) return r;
      }
      if (uploadR.isNotEmpty) {
        final r = await _syncRecebiveis(uploadR);
        if (r != null) return r;
      }
      if (uploadG.isNotEmpty) {
        final r = await _syncGrupos(uploadG);
        if (r != null) return r;
      }

      final novosT = transacoesCloud.where((t) => !localTIds.contains(t.id)).toList();
      final novosR = recebiveisCloud.where((r) => !localRIds.contains(r.id)).toList();
      final novosG = gruposCloud.where((g) => !localGIds.contains(g.id)).toList();

      if (novosT.isNotEmpty || novosR.isNotEmpty || novosG.isNotEmpty) {
        await salvarTransacoes([...transacoesLocais, ...novosT]);
        await salvarRecebiveis([...recebiveisLocais, ...novosR]);
        await salvarGrupos([...gruposLocais, ...novosG]);
      }

      return null;
    } catch (e) {
      return 'Erro ao sincronizar: $e';
    }
  }
}
