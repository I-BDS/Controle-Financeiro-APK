import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conta_pagar.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../services/storage_service.dart';
import 'add_conta_pagar_screen.dart';
import 'grupos_screen.dart';
import '../helpers/format_util.dart';

class ContasPagarScreen extends StatefulWidget {
  final VoidCallback? onTransacaoChanged;

  const ContasPagarScreen({super.key, this.onTransacaoChanged});

  @override
  State<ContasPagarScreen> createState() => ContasPagarScreenState();
}

class ContasPagarScreenState extends State<ContasPagarScreen> {
  final _storage = StorageService.instance;

  int _mesInicio = DateTime.now().month;
  int _anoInicio = DateTime.now().year;
  int _mesFim = DateTime.now().month;
  int _anoFim = DateTime.now().year;

  String _filtroNome = '';
  final Set<String> _filtroGrupos = {};

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

  Future<void> reload() => _carregarPeriodo();

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

  Future<void> _carregarPeriodo() async {
    await _storage.carregarContasPagarPeriodo(_mesInicio, _anoInicio, _mesFim, _anoFim);
  }

  int _toMonthCount(int mes, int ano) => ano * 12 + mes;

  (int, int) _fromMonthCount(int count) =>
      ((count - 1) % 12 + 1, (count - 1) ~/ 12);

  bool _isInPeriod(ContaPagar c) {
    final targetInicio = _toMonthCount(_mesInicio, _anoInicio);
    final targetFim = _toMonthCount(_mesFim, _anoFim);
    final cInicio = _toMonthCount(c.mes, c.ano);
    final cFim = c.recorrente && c.mesFim != null && c.anoFim != null
        ? _toMonthCount(c.mesFim!, c.anoFim!)
        : cInicio;
    return cInicio <= targetFim && cFim >= targetInicio;
  }

  List<ContaPagar> get _contasFiltradas {
    return _storage.contasPagar.where((c) {
      if (_filtroNome.isNotEmpty &&
          !c.descricao.toLowerCase().contains(_filtroNome.toLowerCase())) {
        return false;
      }
      if (_filtroGrupos.isNotEmpty &&
          (c.grupoId == null || !_filtroGrupos.contains(c.grupoId))) {
        return false;
      }
      return _isInPeriod(c);
    }).toList()
      ..sort((a, b) {
        if (a.data != null && b.data != null) return a.data!.compareTo(b.data!);
        if (a.data != null) return -1;
        if (b.data != null) return 1;
        return a.descricao.compareTo(b.descricao);
      });
  }

  double get _totalPendente => _contasFiltradas
      .where((c) => !c.pago)
      .fold(0.0, (s, c) => s + c.valor);
  double get _totalPago => _contasFiltradas
      .where((c) => c.pago)
      .fold(0.0, (s, c) => s + c.valor);

  Future<void> _marcarPago(ContaPagar c) async {
    if (c.pago) {
      final remover = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desmarcar pagamento'),
          content: Text('Deseja remover "${c.descricao}" (R\$ ${formatBRL(c.valor)}) dos lançamentos da despesa no saldo total?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Só desmarcar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover lançamento'),
            ),
          ],
        ),
      );
      if (remover == null) return;

      if (remover) {
        final transacoes = _storage.transacoes;
        final match = transacoes.where((t) => t.recebivelId == c.id).toList();
        for (final t in match) {
          await _storage.removerTransacao(t.id);
        }
      }
      widget.onTransacaoChanged?.call();

      await _storage.removerContaPagar(c.id);
      await _tentarMesclarRecorrente(c);
      _carregar();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagamento confirmado'),
        content: Text('Deseja lançar "${c.descricao}" (R\$ ${formatBRL(c.valor)}) como despesa na carteira?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Só marcar pago'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lançar como despesa'),
          ),
        ],
      ),
    );
    if (confirm == null) return;

    if (confirm) {
      if (!mounted) return;
      bool isDigital = c.isDigital ?? true;
      final tipoDialog = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool tempDigital = isDigital;
            return AlertDialog(
              title: const Text('Tipo de lançamento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Este pagamento é digital ou papel?'),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Digital'), icon: Icon(Icons.phone_android)),
                      ButtonSegment(value: false, label: Text('Dinheiro'), icon: Icon(Icons.receipt)),
                    ],
                    selected: {tempDigital},
                    onSelectionChanged: (v) => setDialogState(() => tempDigital = v.first),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, tempDigital),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        ),
      );
      if (tipoDialog == null) return;
      if (!mounted) return;

      isDigital = tipoDialog;

      if (c.recorrente && c.mesFim != null && c.anoFim != null) {
        await _marcarRecorrentePago(c, isDigital, true);
      } else {
        final transacao = Transacao(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          descricao: c.descricao,
          valor: c.valor,
          isReceita: false,
          data: c.data ?? DateTime.now(),
          grupoId: c.grupoId,
          recebivelId: c.id,
          isDigital: isDigital,
        );
        await _storage.adicionarTransacao(transacao);

        final atualizado = ContaPagar(
          id: c.id, descricao: c.descricao, valor: c.valor,
          mes: c.mes, ano: c.ano, data: c.data, grupoId: c.grupoId,
          pago: true, recorrente: false,
          mesFim: null, anoFim: null, isDigital: isDigital,
        );
        await _storage.atualizarContaPagar(atualizado);
      }
      _carregar();
      return;
    }
    widget.onTransacaoChanged?.call();

    if (c.recorrente && c.mesFim != null && c.anoFim != null) {
      await _marcarRecorrentePago(c, c.isDigital ?? true, false);
    } else {
      final atualizado = ContaPagar(
        id: c.id, descricao: c.descricao, valor: c.valor,
        mes: c.mes, ano: c.ano, data: c.data, grupoId: c.grupoId,
        pago: true, recorrente: false,
        mesFim: null, anoFim: null, isDigital: c.isDigital,
      );
      await _storage.atualizarContaPagar(atualizado);
    }
    _carregar();
  }

  Future<void> _marcarRecorrentePago(ContaPagar c, bool isDigital, bool criarTransacao) async {
    final targetMes = _mesInicio;
    final targetAno = _anoInicio;

    final paidRecord = ContaPagar(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: c.descricao,
      valor: c.valor,
      mes: targetMes,
      ano: targetAno,
      data: c.data,
      grupoId: c.grupoId,
      pago: true,
      recorrente: false,
      isDigital: isDigital,
    );
    await _storage.adicionarContaPagar(paidRecord);

    if (criarTransacao) {
      final transacao = Transacao(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        descricao: c.descricao,
        valor: c.valor,
        isReceita: false,
        data: c.data ?? DateTime(targetAno, targetMes),
        grupoId: c.grupoId,
        recebivelId: paidRecord.id,
        isDigital: isDigital,
      );
      await _storage.adicionarTransacao(transacao);
    }
    widget.onTransacaoChanged?.call();

    final startCount = _toMonthCount(c.mes, c.ano);
    final endCount = _toMonthCount(c.mesFim!, c.anoFim!);
    final targetCount = _toMonthCount(targetMes, targetAno);

    if (startCount == endCount) {
      await _storage.removerContaPagar(c.id);
    } else if (targetCount == startCount) {
      final next = _fromMonthCount(startCount + 1);
      final updated = ContaPagar(
        id: c.id, descricao: c.descricao, valor: c.valor,
        mes: next.$1, ano: next.$2, data: c.data, grupoId: c.grupoId,
        pago: false, recorrente: true,
        mesFim: c.mesFim, anoFim: c.anoFim, isDigital: c.isDigital,
      );
      await _storage.atualizarContaPagar(updated);
    } else if (targetCount == endCount) {
      final prev = _fromMonthCount(endCount - 1);
      final updated = ContaPagar(
        id: c.id, descricao: c.descricao, valor: c.valor,
        mes: c.mes, ano: c.ano, data: c.data, grupoId: c.grupoId,
        pago: false, recorrente: true,
        mesFim: prev.$1, anoFim: prev.$2, isDigital: c.isDigital,
      );
      await _storage.atualizarContaPagar(updated);
    } else {
      final prev = _fromMonthCount(targetCount - 1);
      final truncated = ContaPagar(
        id: c.id, descricao: c.descricao, valor: c.valor,
        mes: c.mes, ano: c.ano, data: c.data, grupoId: c.grupoId,
        pago: false, recorrente: true,
        mesFim: prev.$1, anoFim: prev.$2, isDigital: c.isDigital,
      );
      await _storage.atualizarContaPagar(truncated);

      final next = _fromMonthCount(targetCount + 1);
      final tail = ContaPagar(
        id: '${c.id}_${next.$1}_${next.$2}',
        descricao: c.descricao, valor: c.valor,
        mes: next.$1, ano: next.$2, data: c.data, grupoId: c.grupoId,
        pago: false, recorrente: true,
        mesFim: c.mesFim, anoFim: c.anoFim, isDigital: c.isDigital,
      );
      await _storage.adicionarContaPagar(tail);
    }
  }

  Future<void> _tentarMesclarRecorrente(ContaPagar pago) async {
    final targetCount = _toMonthCount(pago.mes, pago.ano);
    final adjacentes = _storage.contasPagar.where((other) =>
      other.id != pago.id &&
      other.descricao == pago.descricao &&
      other.valor == pago.valor &&
      other.recorrente &&
      other.mesFim != null &&
      other.anoFim != null
    ).toList();

    ContaPagar? antes;
    ContaPagar? depois;
    for (final adj in adjacentes) {
      final adjEnd = _toMonthCount(adj.mesFim!, adj.anoFim!);
      if (adjEnd == targetCount - 1) antes = adj;
      final adjStart = _toMonthCount(adj.mes, adj.ano);
      if (adjStart == targetCount + 1) depois = adj;
    }

    if (antes != null && depois != null) {
      final merged = ContaPagar(
        id: antes.id, descricao: antes.descricao, valor: antes.valor,
        mes: antes.mes, ano: antes.ano, data: antes.data, grupoId: antes.grupoId,
        pago: false, recorrente: true,
        mesFim: depois.mesFim, anoFim: depois.anoFim, isDigital: antes.isDigital,
      );
      await _storage.atualizarContaPagar(merged);
      await _storage.removerContaPagar(depois.id);
    } else if (antes != null) {
      final merged = ContaPagar(
        id: antes.id, descricao: antes.descricao, valor: antes.valor,
        mes: antes.mes, ano: antes.ano, data: antes.data, grupoId: antes.grupoId,
        pago: false, recorrente: true,
        mesFim: pago.mes, anoFim: pago.ano, isDigital: antes.isDigital,
      );
      await _storage.atualizarContaPagar(merged);
    } else if (depois != null) {
      final merged = ContaPagar(
        id: depois.id, descricao: depois.descricao, valor: depois.valor,
        mes: pago.mes, ano: pago.ano, data: depois.data, grupoId: depois.grupoId,
        pago: false, recorrente: true,
        mesFim: depois.mesFim, anoFim: depois.anoFim, isDigital: depois.isDigital,
      );
      await _storage.atualizarContaPagar(merged);
    }
  }

  void _definirMesInicio(int mes, int ano) {
    setState(() { _mesInicio = mes; _anoInicio = ano; });
    _carregarPeriodo();
  }

  void _definirMesFim(int mes, int ano) {
    setState(() { _mesFim = mes; _anoFim = ano; });
    _carregarPeriodo();
  }

  void _mesAnterior() {
    setState(() {
      if (_mesInicio == 1) { _mesInicio = 12; _anoInicio--; }
      else { _mesInicio--; }
      if (_mesFim == 1) { _mesFim = 12; _anoFim--; }
      else { _mesFim--; }
    });
    _carregarPeriodo();
  }

  void _mesProximo() {
    setState(() {
      if (_mesInicio == 12) { _mesInicio = 1; _anoInicio++; }
      else { _mesInicio++; }
      if (_mesFim == 12) { _mesFim = 1; _anoFim++; }
      else { _mesFim++; }
    });
    _carregarPeriodo();
  }

  void _irParaMesAtual() {
    final agora = DateTime.now();
    setState(() {
      _mesInicio = agora.month;
      _anoInicio = agora.year;
      _mesFim = agora.month;
      _anoFim = agora.year;
    });
    _carregarPeriodo();
  }

  Future<void> _adicionar() async {
    await Navigator.push(
      context, MaterialPageRoute(builder: (_) => const AddContaPagarScreen()),
    );
    _carregar();
  }

  Future<void> _editar(ContaPagar c) async {
    await Navigator.push(
      context, MaterialPageRoute(builder: (_) => AddContaPagarScreen(contaPagar: c)),
    );
    _carregar();
  }

  Future<void> _remover(ContaPagar c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover conta a pagar'),
        content: Text('Excluir "${c.descricao}"?'),
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
      await _storage.removerContaPagar(c.id);
      _carregar();
    }
  }

  Future<void> _abrirSeletorGrupos() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _SeletorGruposContaPagar(
        grupos: _storage.grupos.where((g) => !g.isReceita && !g.isRecebivel).toList(),
        selecionados: Set<String>.from(_filtroGrupos),
      ),
    );
    if (result != null) setState(() { _filtroGrupos..clear()..addAll(result); });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lista = _contasFiltradas;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contas a Pagar',
          style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 2.0, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Gerenciar Grupos',
            onPressed: () async {
              await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const GruposScreen()),
              );
              _carregar();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionar,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _carregarPeriodo,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTotalCard(),
            const SizedBox(height: 12),
            _buildMesSelector(),
            const SizedBox(height: 8),
            _buildFiltros(),
            const SizedBox(height: 12),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhuma conta a pagar encontrada.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: isDark ? Colors.red.shade800 : Colors.red.shade100,
                      child: Text(
                        '${_meses[_mesInicio - 1]} $_anoInicio — ${_meses[_mesFim - 1]} $_anoFim',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : null),
                      ),
                    ),
                    ...lista.map((c) => _buildContaPagarTile(c)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      color: isDark ? Colors.red.shade900 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Total a Pagar', style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              'R\$ ${formatBRL(_totalPendente)}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            if (_totalPago > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Pago: R\$ ${formatBRL(_totalPago)}',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMesSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: isDark ? Colors.white70 : null),
              onPressed: _mesAnterior,
            ),
            Expanded(
              child: _buildDataButton(
                label: 'De',
                mes: _mesInicio,
                ano: _anoInicio,
                onTap: () => _selecionarMesAno(true),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            ),
            Expanded(
              child: _buildDataButton(
                label: 'Até',
                mes: _mesFim,
                ano: _anoFim,
                onTap: () => _selecionarMesAno(false),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: isDark ? Colors.white70 : null),
              onPressed: _mesProximo,
            ),
          ],
        ),
        GestureDetector(
          onTap: _irParaMesAtual,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Voltar ao mês atual',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataButton({required String label, required int mes, required int ano, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$label: ${_meses[mes - 1]} $ano',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : null),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selecionarMesAno(bool isInicio) async {
    final tempMes = isInicio ? _mesInicio : _mesFim;
    final tempAno = isInicio ? _anoInicio : _anoFim;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        int m = tempMes;
        int a = tempAno;
        return StatefulBuilder(
          builder: (_, setDialogState) => AlertDialog(
            title: Text(isInicio ? 'Mês de início' : 'Mês de fim'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setDialogState(() {
                    if (m == 1) { m = 12; a--; } else { m--; }
                  }),
                ),
                const SizedBox(width: 8),
                Text('${_meses[m - 1]} $a', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setDialogState(() {
                    if (m == 12) { m = 1; a++; } else { m++; }
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, DateTime(a, m)),
                child: const Text('Selecionar'),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      if (isInicio) {
        _definirMesInicio(picked.month, picked.year);
      } else {
        _definirMesFim(picked.month, picked.year);
      }
    }
  }

  Widget _buildFiltros() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por nome...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : null),
          onChanged: (v) => setState(() => _filtroNome = v),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _abrirSeletorGrupos,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.category_outlined, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _filtroGrupos.isEmpty
                        ? 'Todos os grupos'
                        : '${_filtroGrupos.length} grupo(s) selecionado(s)',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContaPagarTile(ContaPagar c) {
    final nomeGrupo = _storage.getNomeGrupo(c.grupoId);
    final periodoStr = c.recorrente && c.mesFim != null && c.anoFim != null
        ? '${_meses[c.mes - 1]} ${c.ano} — ${_meses[c.mesFim! - 1]} ${c.anoFim}'
        : null;

    return Opacity(
      opacity: c.pago ? 0.5 : 1.0,
      child: ListTile(
        dense: true,
        leading: InkWell(
          onTap: () => _marcarPago(c),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: c.pago ? Colors.red : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: c.pago ? Colors.red : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: c.pago
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          c.descricao,
          style: TextStyle(
            fontSize: 14,
            decoration: c.pago ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [
            ?nomeGrupo,
            if (c.data != null) DateFormat('dd/MM').format(c.data!),
            ?periodoStr,
            if (c.isDigital != null) (c.isDigital! ? 'Digital' : 'Dinheiro'),
          ].join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-R\$ ${formatBRL(c.valor)}',
              style: TextStyle(
                color: c.pago ? Colors.grey : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[500]),
              onSelected: (v) {
                if (v == 'edit') _editar(c);
                if (v == 'delete') _remover(c);
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
      ),
    );
  }
}

class _SeletorGruposContaPagar extends StatefulWidget {
  final List<Grupo> grupos;
  final Set<String> selecionados;

  const _SeletorGruposContaPagar({required this.grupos, required this.selecionados});

  @override
  State<_SeletorGruposContaPagar> createState() => _SeletorGruposContaPagarState();
}

class _SeletorGruposContaPagarState extends State<_SeletorGruposContaPagar> {
  late Set<String> _selecionados;

  @override
  void initState() {
    super.initState();
    _selecionados = Set<String>.from(widget.selecionados);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar por Grupos'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.grupos.map((g) => CheckboxListTile(
            value: _selecionados.contains(g.id),
            onChanged: (v) => setState(() {
              if (v == true) { _selecionados.add(g.id); }
              else { _selecionados.remove(g.id); }
            }),
            title: Row(
              children: [
                Icon(g.icone, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                Text(g.nome),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () { _selecionados.clear(); Navigator.pop(context, _selecionados); },
          child: const Text('Limpar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selecionados),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
