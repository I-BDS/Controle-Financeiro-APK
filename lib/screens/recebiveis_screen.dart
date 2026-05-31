import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recebivel.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../services/storage_service.dart';
import 'add_recebivel_screen.dart';
import 'grupos_screen.dart';
import '../helpers/format_util.dart';

class RecebiveisScreen extends StatefulWidget {
  final VoidCallback? onTransacaoChanged;

  const RecebiveisScreen({super.key, this.onTransacaoChanged});

  @override
  State<RecebiveisScreen> createState() => RecebiveisScreenState();
}

class RecebiveisScreenState extends State<RecebiveisScreen> {
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
    await _storage.carregarRecebiveisPeriodo(_mesInicio, _anoInicio, _mesFim, _anoFim);
  }

  int _toMonthCount(int mes, int ano) => ano * 12 + mes;

  bool _isInPeriod(Recebivel r) {
    final targetInicio = _toMonthCount(_mesInicio, _anoInicio);
    final targetFim = _toMonthCount(_mesFim, _anoFim);
    final recInicio = _toMonthCount(r.mes, r.ano);
    final recFim = r.recorrente && r.mesFim != null && r.anoFim != null
        ? _toMonthCount(r.mesFim!, r.anoFim!)
        : recInicio;
    return recInicio <= targetFim && recFim >= targetInicio;
  }

  List<Recebivel> get _recebiveisFiltrados {
    return _storage.recebiveis.where((r) {
      if (_filtroNome.isNotEmpty &&
          !r.descricao.toLowerCase().contains(_filtroNome.toLowerCase())) {
        return false;
      }
      if (_filtroGrupos.isNotEmpty &&
          (r.grupoId == null || !_filtroGrupos.contains(r.grupoId))) {
        return false;
      }
      return _isInPeriod(r);
    }).toList()
      ..sort((a, b) {
        if (a.data != null && b.data != null) return a.data!.compareTo(b.data!);
        if (a.data != null) return -1;
        if (b.data != null) return 1;
        return a.descricao.compareTo(b.descricao);
      });
  }

  double get _totalPendente => _recebiveisFiltrados
      .where((r) => !r.recebido)
      .fold(0.0, (s, r) => s + r.valor);
  double get _totalRecebido => _recebiveisFiltrados
      .where((r) => r.recebido)
      .fold(0.0, (s, r) => s + r.valor);

  Future<void> _marcarRecebido(Recebivel r) async {
    if (r.recebido) {
      final remover = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desmarcar recebimento'),
          content: Text('Deseja remover "${r.descricao}" (R\$ ${formatBRL(r.valor)}) dos lançamentos da receita no saldo total?'),
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
        final match = transacoes.where((t) => t.recebivelId == r.id).toList();
        for (final t in match) {
          await _storage.removerTransacao(t.id);
        }
      }
      widget.onTransacaoChanged?.call();

      final atualizado = Recebivel(
        id: r.id, descricao: r.descricao, valor: r.valor,
        mes: r.mes, ano: r.ano, data: r.data, grupoId: r.grupoId,
        recebido: false, recorrente: r.recorrente,
        mesFim: r.mesFim, anoFim: r.anoFim, isDigital: r.isDigital,
      );
      await _storage.atualizarRecebivel(atualizado);
      _carregar();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recebimento confirmado'),
        content: Text('Deseja lançar "${r.descricao}" (R\$ ${formatBRL(r.valor)}) como receita na carteira?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Só marcar recebido'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lançar como receita'),
          ),
        ],
      ),
    );
    if (confirm == null) return;

    if (confirm) {
      if (!mounted) return;
      bool isDigital = r.isDigital ?? true;
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
                  const Text('Este recebimento é digital ou papel?'),
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
      final transacao = Transacao(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        descricao: r.descricao,
        valor: r.valor,
        isReceita: true,
        data: r.data ?? DateTime.now(),
        grupoId: r.grupoId,
        recebivelId: r.id,
        isDigital: isDigital,
      );
      await _storage.adicionarTransacao(transacao);

      final atualizado = Recebivel(
        id: r.id, descricao: r.descricao, valor: r.valor,
        mes: r.mes, ano: r.ano, data: r.data, grupoId: r.grupoId,
        recebido: true, recorrente: r.recorrente,
        mesFim: r.mesFim, anoFim: r.anoFim, isDigital: isDigital,
      );
      await _storage.atualizarRecebivel(atualizado);
      _carregar();
      return;
    }
    widget.onTransacaoChanged?.call();

    final atualizado = Recebivel(
      id: r.id, descricao: r.descricao, valor: r.valor,
      mes: r.mes, ano: r.ano, data: r.data, grupoId: r.grupoId,
      recebido: true, recorrente: r.recorrente,
      mesFim: r.mesFim, anoFim: r.anoFim, isDigital: r.isDigital,
    );
    await _storage.atualizarRecebivel(atualizado);
    _carregar();
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
      context, MaterialPageRoute(builder: (_) => const AddRecebivelScreen()),
    );
    _carregar();
  }

  Future<void> _editar(Recebivel r) async {
    await Navigator.push(
      context, MaterialPageRoute(builder: (_) => AddRecebivelScreen(recebivel: r)),
    );
    _carregar();
  }

  Future<void> _remover(Recebivel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover recebível'),
        content: Text('Excluir "${r.descricao}"?'),
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
      await _storage.removerRecebivel(r.id);
      _carregar();
    }
  }

  Future<void> _abrirSeletorGrupos() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _SeletorGruposRecebivel(
        grupos: _storage.grupos.where((g) => g.isRecebivel).toList(),
        selecionados: Set<String>.from(_filtroGrupos),
      ),
    );
    if (result != null) setState(() { _filtroGrupos..clear()..addAll(result); });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lista = _recebiveisFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recebíveis',
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
                        'Nenhum recebível encontrado.',
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
                      color: isDark ? Colors.green.shade800 : Colors.green.shade100,
                      child: Text(
                        '${_meses[_mesInicio - 1]} $_anoInicio — ${_meses[_mesFim - 1]} $_anoFim',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : null),
                      ),
                    ),
                    ...lista.map((r) => _buildRecebivelTile(r)),
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
      color: isDark ? Colors.green.shade900 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Total a Receber', style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              'R\$ ${formatBRL(_totalPendente)}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            if (_totalRecebido > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Recebido: R\$ ${formatBRL(_totalRecebido)}',
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

  Widget _buildRecebivelTile(Recebivel r) {
    final nomeGrupo = _storage.getNomeGrupo(r.grupoId);
    final periodoStr = r.recorrente && r.mesFim != null && r.anoFim != null
        ? '${_meses[r.mes - 1]} ${r.ano} — ${_meses[r.mesFim! - 1]} ${r.anoFim}'
        : null;

    return Opacity(
      opacity: r.recebido ? 0.5 : 1.0,
      child: ListTile(
        dense: true,
        leading: InkWell(
          onTap: () => _marcarRecebido(r),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: r.recebido ? Colors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: r.recebido ? Colors.green : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: r.recebido
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          r.descricao,
          style: TextStyle(
            fontSize: 14,
            decoration: r.recebido ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [
            ?nomeGrupo,
            if (r.data != null) DateFormat('dd/MM').format(r.data!),
            ?periodoStr,
            if (r.isDigital != null) (r.isDigital! ? 'Digital' : 'Dinheiro'),
          ].join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+R\$ ${formatBRL(r.valor)}',
              style: TextStyle(
                color: r.recebido ? Colors.grey : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[500]),
              onSelected: (v) {
                if (v == 'edit') _editar(r);
                if (v == 'delete') _remover(r);
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

class _SeletorGruposRecebivel extends StatefulWidget {
  final List<Grupo> grupos;
  final Set<String> selecionados;

  const _SeletorGruposRecebivel({required this.grupos, required this.selecionados});

  @override
  State<_SeletorGruposRecebivel> createState() => _SeletorGruposRecebivelState();
}

class _SeletorGruposRecebivelState extends State<_SeletorGruposRecebivel> {
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
                Icon(g.icone, size: 20, color: Colors.green),
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
