import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../models/recebivel.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;
  static RealtimeChannel? _realtimeChannel;

  static const _urlKey = 'supabase_url';
  static const _anonKey = 'supabase_anon_key';

  static SupabaseClient? get client => _client;

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

  // --- Realtime ---

  static void initRealtime({
    required void Function() onAnyChange,
  }) {
    if (!isConfigured) return;
    disposeRealtime();
    _realtimeChannel = _client!.channel('realtime-all');

    for (final table in ['transacoes', 'grupos', 'recebiveis']) {
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) {
          onAnyChange();
        },
      );
    }

    _realtimeChannel!.subscribe();
  }

  static void disposeRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  // --- Transacoes ---

  static Future<String?> upsertTransacao(Transacao t) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      await _client!.from('transacoes').upsert(t.toJson());
      return null;
    } catch (e) {
      return _tratarErro(e, 'transacoes');
    }
  }

  static Future<String?> deleteTransacao(String id) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      await _client!.from('transacoes').delete().eq('id', id);
      return null;
    } catch (e) {
      return _tratarErro(e, 'transacoes');
    }
  }

  static Future<List<Transacao>> fetchAllTransacoes() async {
    final response = await _client!.from('transacoes').select().order('data', ascending: false);
    return (response as List)
        .map((e) => Transacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Transacao>> fetchTransacoesPorAno(int ano) async {
    final inicio = DateTime(ano, 1, 1).toIso8601String();
    final fim = DateTime(ano, 12, 31, 23, 59, 59).toIso8601String();
    final response = await _client!
        .from('transacoes')
        .select()
        .gte('data', inicio)
        .lte('data', fim)
        .order('data', ascending: false);
    return (response as List)
        .map((e) => Transacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Transacao>> fetchTransacoesPorMesAno(int mes, int ano) async {
    final inicio = DateTime(ano, mes, 1).toIso8601String();
    final fim = DateTime(ano, mes + 1, 0, 23, 59, 59).toIso8601String();
    final response = await _client!
        .from('transacoes')
        .select()
        .gte('data', inicio)
        .lte('data', fim)
        .order('data', ascending: false);
    return (response as List)
        .map((e) => Transacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Transacao>> fetchTransacoesPorPeriodo(DateTime inicio, DateTime fim) async {
    final response = await _client!
        .from('transacoes')
        .select()
        .gte('data', inicio.toIso8601String())
        .lte('data', fim.toIso8601String())
        .order('data', ascending: false);
    return (response as List)
        .map((e) => Transacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Grupos ---

  static Future<String?> upsertGrupo(Grupo g) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      await _client!.from('grupos').upsert(g.toJson());
      return null;
    } catch (e) {
      return _tratarErro(e, 'grupos');
    }
  }

  static Future<String?> deleteGrupo(String id) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      await _client!.from('grupos').delete().eq('id', id);
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
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      await _client!.from('recebiveis').upsert(r.toJson());
      return null;
    } catch (e) {
      return _tratarErro(e, 'recebiveis');
    }
  }

  static Future<String?> deleteRecebivel(String id) async {
    if (!isConfigured) return 'Supabase não configurado.';
    try {
      await _client!.from('recebiveis').delete().eq('id', id);
      return null;
    } catch (e) {
      return _tratarErro(e, 'recebiveis');
    }
  }

  static Future<List<Recebivel>> fetchAllRecebiveis() async {
    final response = await _client!.from('recebiveis').select().order('ano', ascending: false);
    return (response as List)
        .map((e) => Recebivel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Recebivel>> fetchRecebiveisPorAno(int ano) async {
    final response = await _client!
        .from('recebiveis')
        .select()
        .gte('ano', ano)
        .lte('ano', ano)
        .order('ano', ascending: false);
    return (response as List)
        .map((e) => Recebivel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Recebivel>> fetchRecebiveisPorPeriodo(
    int mesInicio, int anoInicio, int? mesFim, int? anoFim,
  ) async {
    final anoIni = anoInicio;
    final anoF = (mesFim != null && anoFim != null) ? anoFim : anoInicio;
    final response = await _client!
        .from('recebiveis')
        .select()
        .gte('ano', anoIni)
        .lte('ano', anoF)
        .order('ano', ascending: false);
    final todos = (response as List)
        .map((e) => Recebivel.fromJson(e as Map<String, dynamic>))
        .toList();
    // filter in-memory to include recurring items overlapping the range
    final inicio = mesInicio + anoInicio * 12;
    final fim = (mesFim ?? mesInicio) + (anoFim ?? anoInicio) * 12;
    return todos.where((r) {
      final rInicio = r.mes + r.ano * 12;
      final rFim = (r.recorrente && r.mesFim != null && r.anoFim != null)
          ? r.mesFim! + r.anoFim! * 12
          : rInicio;
      return rInicio <= fim && rFim >= inicio;
    }).toList();
  }
}
