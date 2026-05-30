import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../services/storage_service.dart';
import '../helpers/format_util.dart';

class AnaliseScreen extends StatefulWidget {
  const AnaliseScreen({super.key});

  @override
  State<AnaliseScreen> createState() => AnaliseScreenState();
}

class AnaliseScreenState extends State<AnaliseScreen> {
  final _storage = StorageService.instance;
  int _ano = DateTime.now().year;
  double _limiteRF = 30639.90;
  static const _limiteRFKey = 'limite_receita_federal';

  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _usarFiltroData = false;

  final Set<String> _gruposFiltro = {};
  bool _expandirRF = false;

  @override
  void initState() {
    super.initState();
    _storage.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _storage.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final limite = prefs.getDouble(_limiteRFKey) ?? 30639.90;
    if (mounted) {
      setState(() {
        _limiteRF = limite;
      });
    }
  }

  List<Transacao> get _transacoesFiltradas {
    return _storage.transacoes.where((t) {
      if (t.data.year != _ano) return false;
      if (_usarFiltroData) {
        if (_dataInicio != null && t.data.isBefore(_dataInicio!)) return false;
        if (_dataFim != null && t.data.isAfter(_dataFim!.add(const Duration(days: 1)))) return false;
      }
      if (_gruposFiltro.isNotEmpty && (t.grupoId == null || !_gruposFiltro.contains(t.grupoId))) return false;
      return true;
    }).toList();
  }

  Future<void> _selecionarDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime(_ano, 1, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _selecionarDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataFim ?? DateTime(_ano, 12, 31),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataFim = picked);
  }

  bool get _temDados {
    return _transacoesFiltradas.isNotEmpty ||
        _storage.recebiveis.any((r) => r.ano == _ano && !r.recebido) ||
        _storage.recebiveis.any((r) =>
            r.recorrente &&
            r.anoFim != null &&
            r.ano <= _ano &&
            r.anoFim! >= _ano);
  }

  double get _totalReceitasAno {
    return _storage.transacoes
        .where((t) => t.data.year == _ano && t.isReceita && (t.isDigital == true))
        .fold(0.0, (s, t) => s + t.valor);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtradas = _transacoesFiltradas;

    double totalReceitas = 0, totalDespesas = 0, totalAReceber = 0;
    final receitasMes = <int, double>{};
    final despesasMes = <int, double>{};
    final aReceberMes = <int, double>{};

    for (final t in filtradas) {
      if (t.isReceita) {
        receitasMes[t.data.month] = (receitasMes[t.data.month] ?? 0) + t.valor;
        totalReceitas += t.valor;
      } else {
        despesasMes[t.data.month] = (despesasMes[t.data.month] ?? 0) + t.valor;
        totalDespesas += t.valor;
      }
    }

    for (final r in _storage.recebiveis.where((r) => !r.recebido)) {
      if (r.ano > _ano) continue;
      if (r.ano < _ano && (!r.recorrente || r.mesFim == null)) continue;
      if (r.recorrente && r.anoFim != null && r.anoFim! < _ano) continue;

      if (r.recorrente && r.mesFim != null && r.anoFim != null) {
        final start = r.ano < _ano ? 1 : r.mes;
        final end = r.anoFim! > _ano ? 12 : r.mesFim!;
        for (int m = start; m <= end; m++) {
          aReceberMes[m] = (aReceberMes[m] ?? 0) + r.valor;
          totalAReceber += r.valor;
        }
      } else if (r.ano == _ano) {
        aReceberMes[r.mes] = (aReceberMes[r.mes] ?? 0) + r.valor;
        totalAReceber += r.valor;
      }
    }

    final maxY = _calcularMaxY(receitasMes, despesasMes, aReceberMes);
    final restanteRF = (_limiteRF - _totalReceitasAno).clamp(0.0, _limiteRF);
    final proporcaoRF = _limiteRF > 0 ? (_totalReceitasAno / _limiteRF).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Análise',
          style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 2.0, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAnoSelector(),
            const SizedBox(height: 8),
            _buildFiltroData(),
            const SizedBox(height: 8),
            _buildFiltroGrupos(),
            const SizedBox(height: 12),
            _buildResumoAnual(totalReceitas, totalDespesas, totalAReceber),
            const SizedBox(height: 16),
            _buildLimiteRFCard(isDark, restanteRF, proporcaoRF),
            const SizedBox(height: 16),
            if (_temDados) ...[
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          const meses = [
                            'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                            'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
                          ];
                          const labels = ['Receita', 'Despesa', 'A Receber'];
                          final label = rodIndex < labels.length ? labels[rodIndex] : '';
                          return BarTooltipItem(
                            '${meses[group.x - 1]}\n$label: R\$ ${formatBRL(rod.toY)}',
                            TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() < 1 || value.toInt() > 12) return const SizedBox.shrink();
                            const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(meses[value.toInt() - 1], style: const TextStyle(fontSize: 10)),
                            );
                          },
                          reservedSize: 22,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            return Text('R\$ ${value.toInt()}', style: const TextStyle(fontSize: 9));
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(12, (i) {
                      final mes = i + 1;
                      return BarChartGroupData(
                        x: mes,
                        barRods: [
                          BarChartRodData(
                            toY: receitasMes[mes] ?? 0,
                            color: Colors.green,
                            width: 10,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: despesasMes[mes] ?? 0,
                            color: Colors.red,
                            width: 10,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: aReceberMes[mes] ?? 0,
                            color: Colors.orange,
                            width: 10,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                        barsSpace: 3,
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegenda(Colors.green, 'Receitas'),
                  const SizedBox(width: 20),
                  _buildLegenda(Colors.red, 'Despesas'),
                  const SizedBox(width: 20),
                  _buildLegenda(Colors.orange, 'A Receber'),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'Nenhum dado para o período selecionado.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoAnual(double totalReceitas, double totalDespesas, double totalAReceber) {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Receitas', totalReceitas, Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _buildSummaryCard('Despesas', totalDespesas, Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _buildSummaryCard('A Receber', totalAReceber, Colors.orange)),
      ],
    );
  }

  Widget _buildLimiteRFCard(bool isDark, double restante, double proporcao) {
    final estourou = _totalReceitasAno >= _limiteRF;
    return Card(
      elevation: 2,
      color: estourou
          ? (isDark ? Colors.orange.shade900 : Colors.orange.shade50)
          : (isDark ? Colors.teal.shade900 : Colors.teal.shade50),
      child: InkWell(
        onTap: () => setState(() => _expandirRF = !_expandirRF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance, size: 18,
                      color: estourou ? Colors.orange : (isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Limite Receita Federal',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: estourou ? Colors.orange : (isDark ? Colors.grey[300] : Colors.grey[700])),
                    ),
                  ),
                  Text(
                    'R\$ ${formatBRL(_limiteRF)}',
                    style: TextStyle(fontSize: 12,
                        color: estourou ? Colors.orange : (isDark ? Colors.grey[400] : Colors.grey[600])),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expandirRF ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: estourou ? Colors.orange : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
              if (_expandirRF) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: proporcao,
                    backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    color: estourou ? Colors.orange : (proporcao > 0.8 ? Colors.amber : Colors.green),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rendimentos: R\$ ${formatBRL(_totalReceitasAno)}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    if (estourou)
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('ATENÇÃO!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      )
                    else
                      Text(
                        'Falta R\$ ${formatBRL(restante)}',
                        style: TextStyle(fontSize: 12,
                            color: proporcao > 0.8 ? Colors.amber : (isDark ? Colors.grey[400] : Colors.grey[600])),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnoSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _ano--),
        ),
        Text(_ano.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() => _ano++),
        ),
      ],
    );
  }

  Widget _buildFiltroData() {
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
                  _usarFiltroData ? Icons.date_range : Icons.date_range_outlined,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Filtrar por período',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                Icon(
                  _usarFiltroData ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.grey[600],
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
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _dataInicio != null
                          ? DateFormat('dd/MM/yyyy').format(_dataInicio!)
                          : '01/01/$_ano',
                      style: const TextStyle(fontSize: 13),
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
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _dataFim != null
                          ? DateFormat('dd/MM/yyyy').format(_dataFim!)
                          : '31/12/$_ano',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() {
                    _dataInicio = null;
                    _dataFim = null;
                  }),
                  child: Icon(Icons.clear, size: 16, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFiltroGrupos() {
    if (_storage.grupos.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: _abrirSeletorGrupos,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.category_outlined, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _gruposFiltro.isEmpty
                    ? 'Todos os grupos'
                    : '${_gruposFiltro.length} grupo(s) selecionado(s)',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirSeletorGrupos() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _SeletorGruposDialog(
        grupos: _storage.grupos,
        selecionados: Set<String>.from(_gruposFiltro),
      ),
    );
    if (result != null) {
      setState(() => _gruposFiltro
        ..clear()
        ..addAll(result));
    }
  }

  Widget _buildSummaryCard(String label, double valor, Color cor) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              'R\$ ${formatBRL(valor)}',
              style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegenda(Color cor, String label) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  double _calcularMaxY(Map<int, double> receitas, Map<int, double> despesas, Map<int, double> aReceber) {
    double max = 0;
    for (int i = 1; i <= 12; i++) {
      final total = (receitas[i] ?? 0) + (despesas[i] ?? 0) + (aReceber[i] ?? 0);
      if (total > max) max = total;
    }
    return max > 0 ? max * 1.25 : 100;
  }
}

class _SeletorGruposDialog extends StatefulWidget {
  final List<Grupo> grupos;
  final Set<String> selecionados;

  const _SeletorGruposDialog({required this.grupos, required this.selecionados});

  @override
  State<_SeletorGruposDialog> createState() => _SeletorGruposDialogState();
}

class _SeletorGruposDialogState extends State<_SeletorGruposDialog> {
  late Set<String> _selecionados;

  @override
  void initState() {
    super.initState();
    _selecionados = Set<String>.from(widget.selecionados);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar Grupos'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.grupos.map((g) => CheckboxListTile(
            value: _selecionados.contains(g.id),
            onChanged: (v) => setState(() {
              if (v == true) {
                _selecionados.add(g.id);
              } else {
                _selecionados.remove(g.id);
              }
            }),
            title: Row(
              children: [
                Icon(g.icone, size: 20, color: g.isReceita ? Colors.green : Colors.red),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            _selecionados.clear();
            Navigator.pop(context, _selecionados);
          },
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
