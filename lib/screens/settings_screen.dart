import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../services/sql_migration.dart';
import '../helpers/format_util.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const SettingsScreen({super.key, this.onToggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService.instance;
  bool _expandido = false;
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _limiteRFController = TextEditingController();
  double _limiteRF = 30639.90;
  static const _limiteRFKey = 'limite_receita_federal';


  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final creds = await SupabaseService.carregarCredenciais();
    _urlController.text = creds['url']!;
    _keyController.text = creds['anonKey']!;
    final prefs = await SharedPreferences.getInstance();
    _limiteRF = prefs.getDouble(_limiteRFKey) ?? 30639.90;
    _limiteRFController.text = _limiteRF.toStringAsFixed(2);
    if (mounted) setState(() {});
  }

  Future<void> _salvar() async {
    await SupabaseService.salvarCredenciais(
      _urlController.text.trim(),
      _keyController.text.trim(),
    );
    if (!mounted) return;

    final erroInit = await SupabaseService.initialize();
    if (erroInit != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credenciais salvas, mas erro ao conectar: $erroInit'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await StorageService.instance.init();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credenciais salvas! Dados carregados.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _mostrarSql() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Script SQL para Supabase'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              sqlMigration,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: sqlMigration));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SQL copiado para a área de transferência!')),
              );
            },
            child: const Text('Copiar SQL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarLimiteRF() async {
    final valor = double.tryParse(_limiteRFController.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido'), backgroundColor: Colors.red),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_limiteRFKey, valor);
    setState(() => _limiteRF = valor);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite salvo!'), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildLimiteRF() {
    return ExpansionTile(
      initiallyExpanded: false,
      leading: Icon(Icons.account_balance, color: Colors.amber, size: 20),
      title: const Text('Limite Receita Federal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      subtitle: Text(
        'Atual: R\$ ${formatBRL(_limiteRF)}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      collapsedShape: const Border(),
      shape: const Border(),
      children: [
        Text(
          'Valor máximo de rendimentos tributáveis no ano antes de precisar declarar Imposto de Renda. Apenas lançamentos digitais contam para este limite.',
          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _limiteRFController,
                decoration: const InputDecoration(
                  labelText: 'Limite anual (R\$)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _salvarLimiteRF,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageMode() {
    final currentMode = _storage.storageMode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: currentMode == StorageMode.local ? Colors.orange : Colors.teal),
                const SizedBox(width: 8),
                const Text('Modo de Armazenamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<StorageMode>(
              segments: const [
                ButtonSegment(value: StorageMode.local, label: Text('Local'), icon: Icon(Icons.phone_android)),
                ButtonSegment(value: StorageMode.supabase, label: Text('Supabase'), icon: Icon(Icons.cloud)),
              ],
              selected: {currentMode},
              onSelectionChanged: _alterarModo,
            ),
            const SizedBox(height: 8),
            Text(
              currentMode == StorageMode.local
                  ? 'Dados salvos apenas neste dispositivo. Conexão com Supabase desativada.'
                  : 'Dados sincronizados com Supabase na nuvem.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _alterarModo(Set<StorageMode> selected) async {
    final novo = selected.first;
    if (novo == _storage.storageMode) return;

    if (novo == StorageMode.local) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Modo Local'),
          content: const Text(
            'Os dados atuais serão salvos localmente e a conexão com o Supabase será encerrada.\n\n'
            'Você poderá voltar ao modo Supabase quando quiser.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
          ],
        ),
      );
      if (confirm != true) return;
      final erro = await _storage.switchToLocal();
      if (mounted) {
        if (erro != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(erro), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Modo local ativado!'), backgroundColor: Colors.green),
          );
        }
        setState(() {});
      }
      return;
    }

    // switching to Supabase
    final creds = await SupabaseService.carregarCredenciais();
    if (creds['url']!.isEmpty || creds['anonKey']!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configure as credenciais do Supabase primeiro.'), backgroundColor: Colors.orange),
        );
        setState(() => _expandido = true);
      }
      return;
    }

    final temDados = _storage.transacoes.isNotEmpty || _storage.grupos.isNotEmpty || _storage.recebiveis.isNotEmpty;

    if (!temDados) {
      if (!mounted) return;
      final opt = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Modo Supabase'),
          content: const Text(
            'Nenhum dado encontrado no aplicativo. O que deseja fazer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'baixar'),
              child: const Text('Baixar do banco'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'substituir'),
              child: const Text('Atualizar com dados locais'),
            ),
          ],
        ),
      );
      if (opt == null) return;

      if (opt == 'substituir') {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tem certeza?'),
            content: const Text(
              'Isso substituirá todos os dados no banco pelos dados locais (que estão vazios), '
              'efetivamente limpando o banco de dados.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
            ],
          ),
        );
        if (confirm != true) return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final String? erro;
      if (opt == 'baixar') {
        erro = await _storage.switchToSupabase(onlyLoad: true);
      } else {
        erro = await _storage.switchToSupabase();
      }

      if (mounted) {
        Navigator.pop(context);
        if (erro != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(erro), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Modo Supabase ativado!'), backgroundColor: Colors.green),
          );
        }
        setState(() {});
      }
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sincronizar com Supabase'),
        content: const Text(
          'Os dados locais serão sincronizados com o banco:\n\n'
          '• Novos dados serão enviados\n'
          '• Dados existentes serão atualizados\n'
          '• Dados removidos localmente serão removidos do banco\n\n'
          'Após a sincronização, o armazenamento local será limpo '
          'e o aplicativo passará a depender exclusivamente do banco.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sincronizar')),
        ],
      ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final erro = await _storage.switchToSupabase();

    if (mounted) {
      Navigator.pop(context);
      if (erro != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modo Supabase ativado!'), backgroundColor: Colors.green),
        );
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _limiteRFController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 2.0),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.teal),
                      const SizedBox(width: 8),
                      const Text('Modo Noturno', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Switch(
                        value: isDark,
                        onChanged: (_) => widget.onToggleTheme?.call(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildStorageMode(),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: _expandido,
              onExpansionChanged: (v) => setState(() => _expandido = v),
              leading: Icon(Icons.cloud_sync, color: isDark ? Colors.teal[300] : Colors.teal),
              title: const Text('Supabase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Sincronização com a nuvem',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              collapsedShape: const Border(),
              shape: const Border(),
              children: [
                Text(
                  'Configure as credenciais do seu projeto Supabase para sincronizar os dados.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Supabase URL',
                    hintText: 'https://seuprojeto.supabase.co',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Use a Project URL (ex: https://xyz.supabase.co), remova /rest/v1/ se tiver.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  decoration: const InputDecoration(
                    labelText: 'Anon Key',
                    hintText: 'sua-chave-anon-publica',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar Credenciais'),
                    onPressed: _salvar,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLimiteRF(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: Icon(Icons.storage, color: isDark ? Colors.blue[300] : Colors.blue),
              title: const Text('Banco de Dados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Script SQL para criar tabelas',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              collapsedShape: const Border(),
              shape: const Border(),
              children: [
                Text(
                  'Para criar as tabelas no Supabase, copie o script SQL e execute no SQL Editor do seu projeto.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.code),
                    label: const Text('Ver Script SQL'),
                    onPressed: _mostrarSql,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: isDark ? Colors.blue[200] : Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Como encontrar as credenciais:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue[200] : Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const _InstrucaoPasso('1. Crie um projeto em https://supabase.com'),
                      const _InstrucaoPasso('2. Vá em "Project Settings" → "API"'),
                      const _InstrucaoPasso('3. Copie o "Project URL" (campo URL)'),
                      const _InstrucaoPasso('4. Copie o "anon public" (campo Anon Key)'),
                      const _InstrucaoPasso('5. Vá em "SQL Editor" e execute o script acima'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InstrucaoPasso extends StatelessWidget {
  final String texto;
  const _InstrucaoPasso(this.texto);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, color: isDark ? Colors.blue[100] : Colors.blue[900]),
      ),
    );
  }
}
