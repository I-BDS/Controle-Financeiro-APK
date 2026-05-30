import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transacao.dart';
import '../services/storage_service.dart';
import 'add_transacao_screen.dart';
import 'grupos_screen.dart';
import 'settings_screen.dart';
import '../helpers/format_util.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onTransacaoChanged;
  final VoidCallback? onToggleTheme;

  const HomeScreen({super.key, this.onTransacaoChanged, this.onToggleTheme});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService.instance;

  Future<void> reload() => _carregar();

  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _usarFiltroData = false;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    _storage.addListener(_onDataChanged);
    _carregar();
  }

  @override
  void dispose() {
    _storage.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _carregar() async {
    setState(() {});
  }

  List<Transacao> get _transacoesFiltradas {
    return _storage.transacoes.where((t) {
      if (t.data.month != _mesSelecionado || t.data.year != _anoSelecionado) return false;
      if (_usarFiltroData) {
        if (_dataInicio != null && t.data.isBefore(_dataInicio!)) return false;
        if (_dataFim != null && t.data.isAfter(_dataFim!.add(const Duration(days: 1)))) return false;
      }
      return true;
    }).toList();
  }

  double get _saldoTotal {
    double total = 0;
    for (final t in _storage.transacoes) {
      total += t.isReceita ? t.valor : -t.valor;
    }
    return total;
  }

  void _mesAnterior() {
    setState(() {
      if (_mesSelecionado == 1) {
        _mesSelecionado = 12;
        _anoSelecionado--;
      } else {
        _mesSelecionado--;
      }
    });
  }

  void _mesProximo() {
    setState(() {
      if (_mesSelecionado == 12) {
        _mesSelecionado = 1;
        _anoSelecionado++;
      } else {
        _mesSelecionado++;
      }
    });
  }

  void _irParaMesAtual() {
    final agora = DateTime.now();
    setState(() {
      _mesSelecionado = agora.month;
      _anoSelecionado = agora.year;
    });
  }

  Future<void> _selecionarDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime(_anoSelecionado, _mesSelecionado, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _selecionarDataFim() async {
    final ultimoDia = DateTime(_anoSelecionado, _mesSelecionado + 1, 0).day;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataFim ?? DateTime(_anoSelecionado, _mesSelecionado, ultimoDia),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataFim = picked);
  }

  Future<void> _remover(Transacao t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover transação'),
        content: Text('Excluir "${t.descricao}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.removerTransacao(t.id);
      _carregar();
      widget.onTransacaoChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final transacoes = _transacoesFiltradas..sort((a, b) => b.data.compareTo(a.data));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          tooltip: 'Configurações',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(onToggleTheme: widget.onToggleTheme),
              ),
            );
            _carregar();
          },
        ),
        title: const Text(
          'Gestão Financeira',
          style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 2.0, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.category, color: Colors.white),
            tooltip: 'Gerenciar Grupos',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GruposScreen()),
              );
              _carregar();
              widget.onTransacaoChanged?.call();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSaldoCard(),
            const SizedBox(height: 16),
            _buildBotoes(),
            const SizedBox(height: 24),
            _buildUltimosLancamentos(transacoes),
          ],
        ),
      ),
    );
  }

  Widget _buildSaldoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      color: isDark ? Colors.teal.shade900 : Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Saldo Total', style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              'R\$ ${formatBRL(_saldoTotal)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _saldoTotal >= 0 ? Colors.teal : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotoes() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            label: const Text('Receita'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransacaoScreen(isReceita: true)),
              );
              _carregar();
              widget.onTransacaoChanged?.call();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.remove_circle, color: Colors.white),
            label: const Text('Despesa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransacaoScreen(isReceita: false)),
              );
              _carregar();
              widget.onTransacaoChanged?.call();
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildKpiLimites() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comLimite = _storage.grupos.where((g) => !g.isReceita && g.limite != null && g.limite! > 0);
    final gastos = <String, double>{};
    for (final t in _transacoesFiltradas) {
      if (!t.isReceita && t.grupoId != null) {
        gastos[t.grupoId!] = (gastos[t.grupoId!] ?? 0) + t.valor;
      }
    }
    final excedidos = comLimite.where((g) => (gastos[g.id] ?? 0) > g.limite!).toList();
    if (excedidos.isEmpty) return [];

    excedidos.sort((a, b) {
      final excessoA = (gastos[a.id] ?? 0) - a.limite!;
      final excessoB = (gastos[b.id] ?? 0) - b.limite!;
      return excessoB.compareTo(excessoA);
    });
    final kpiHeight = excedidos.length <= 3 ? excedidos.length * 115.0 : 345.0;

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: isDark ? Colors.red[300] : Colors.red[700]),
            const SizedBox(width: 6),
            Text(
              'Limites Excedidos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.red[300] : Colors.red[700]),
            ),
          ],
        ),
      ),
      SizedBox(
        height: kpiHeight,
        child: SingleChildScrollView(
          child: Column(
            children: excedidos.map((g) {
            final gasto = gastos[g.id] ?? 0;
            final excesso = gasto - g.limite!;
            final proporcao = (gasto / g.limite!).clamp(0.0, 1.0).toDouble();
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              color: isDark ? Colors.red.shade900 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(g.icone, size: 18, color: isDark ? Colors.orange[300] : Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(g.nome, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.red[900])),
                        const Spacer(),
                        Text('R\$ ${formatBRL(excesso)}', style: TextStyle(color: isDark ? Colors.orange[300] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: proporcao,
                        backgroundColor: isDark ? Colors.red.shade800 : Colors.red.shade100,
                        color: Colors.red,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Limite: R\$ ${formatBRL(g.limite!)}', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        Text('Gasto: R\$ ${formatBRL(gasto)}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.red[700])),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildUltimosLancamentos(List<Transacao> transacoes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildKpiLimites(),
        const Text(
          'Últimos Lançamentos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildMesSelector(),
        const SizedBox(height: 4),
        _buildFiltroData(),
        const SizedBox(height: 8),
        if (transacoes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhuma transação neste período.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          _buildMesCard(transacoes),
      ],
    );
  }

  Widget _buildMesSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = '${_meses[_mesSelecionado - 1]} $_anoSelecionado';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: _mesAnterior, icon: Icon(Icons.chevron_left, color: isDark ? Colors.white70 : null)),
        GestureDetector(
          onTap: _irParaMesAtual,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.teal.shade800 : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)),
          ),
        ),
        IconButton(onPressed: _mesProximo, icon: Icon(Icons.chevron_right, color: isDark ? Colors.white70 : null)),
      ],
    );
  }

  Widget _buildFiltroData() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _usarFiltroData = !_usarFiltroData),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _usarFiltroData ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Filtrar por data',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                Icon(
                  _usarFiltroData ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (_usarFiltroData)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('De: ', style: TextStyle(fontSize: 13)),
                GestureDetector(
                  onTap: _selecionarDataInicio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _dataInicio != null
                          ? DateFormat('dd/MM/yyyy').format(_dataInicio!)
                          : DateFormat('dd/MM/yyyy').format(DateTime(_anoSelecionado, _mesSelecionado, 1)),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : null),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Até: ', style: TextStyle(fontSize: 13)),
                GestureDetector(
                  onTap: _selecionarDataFim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _dataFim != null
                          ? DateFormat('dd/MM/yyyy').format(_dataFim!)
                          : DateFormat('dd/MM/yyyy').format(DateTime(_anoSelecionado, _mesSelecionado, DateTime(_anoSelecionado, _mesSelecionado + 1, 0).day)),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMesCard(List<Transacao> transacoes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receitas = transacoes
        .where((t) => t.isReceita)
        .fold<double>(0, (sum, t) => sum + t.valor);
    final despesas = transacoes
        .where((t) => !t.isReceita)
        .fold<double>(0, (sum, t) => sum + t.valor);
    final saldoMes = receitas - despesas;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? Colors.teal.shade800 : Colors.teal.shade100,
            child: Text(
              '${_meses[_mesSelecionado - 1]} $_anoSelecionado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : null),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                _buildLinhaResumo('Receitas', receitas, Colors.green),
                const SizedBox(height: 4),
                _buildLinhaResumo('Despesas', despesas, Colors.red),
                const Divider(height: 20),
                _buildLinhaResumo('Saldo', saldoMes, saldoMes >= 0 ? Colors.teal : Colors.red),
              ],
            ),
          ),
          if (transacoes.length <= 5)
            Column(
              children: transacoes.map((t) => _buildTransacaoTile(t)).toList(),
            )
          else
            SizedBox(
              height: 324,
              child: SingleChildScrollView(
                child: Column(
                  children: transacoes.map((t) => _buildTransacaoTile(t)).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinhaResumo(String label, double valor, Color cor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          'R\$ ${formatBRL(valor)}',
          style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _editarTransacao(Transacao t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransacaoScreen(
        isReceita: t.isReceita,
        transacao: t,
      )),
    );
    _carregar();
    widget.onTransacaoChanged?.call();
  }

  Widget _buildTransacaoTile(Transacao t) {
    final nomeGrupo = _storage.getNomeGrupo(t.grupoId);
    final iconeGrupo = _storage.getIconeGrupo(t.grupoId);

    return ListTile(
      dense: true,
      leading: iconeGrupo != null
          ? Icon(iconeGrupo, color: t.isReceita ? Colors.green : Colors.red, size: 20)
          : Icon(
              t.isReceita ? Icons.arrow_upward : Icons.arrow_downward,
              color: t.isReceita ? Colors.green : Colors.red,
              size: 20,
            ),
      title: Text(t.descricao, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        [
          nomeGrupo ?? '',
          '${t.data.day}/${t.data.month}/${t.data.year}',
          if (t.isDigital != null) (t.isDigital! ? 'Digital' : 'Dinheiro'),
        ].where((s) => s.isNotEmpty).join(' • '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${t.isReceita ? '+' : '-'}R\$ ${formatBRL(t.valor)}',
            style: TextStyle(
              color: t.isReceita ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[500]),
            onSelected: (v) {
              if (v == 'edit') _editarTransacao(t);
              if (v == 'delete') _remover(t);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(
                children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')],
              )),
              const PopupMenuItem(value: 'delete', child: Row(
                children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Excluir', style: TextStyle(color: Colors.red))],
              )),
            ],
          ),
        ],
      ),
    );
  }
}
