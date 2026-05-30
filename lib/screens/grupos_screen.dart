import 'package:flutter/material.dart';
import '../models/grupo.dart';
import '../services/storage_service.dart';
import '../helpers/format_util.dart';

class GruposScreen extends StatefulWidget {
  const GruposScreen({super.key});

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  final _storage = StorageService.instance;

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

  Future<void> _adicionar() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _GrupoDialog(),
    );
    if (result == null) return;

    final tipo = result['tipo'] as String;
    final grupo = Grupo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nome: result['nome'],
      isReceita: tipo == 'receita' || tipo == 'recebivel',
      isRecebivel: tipo == 'recebivel',
      icone: result['icone'],
      limite: result['limite'] as double?,
    );
    await _storage.adicionarGrupo(grupo);
    _carregar();
  }

  Future<void> _editar(Grupo grupo) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _GrupoDialog(grupo: grupo),
    );
    if (result == null) return;

    final tipo = result['tipo'] as String;
    final atualizado = Grupo(
      id: grupo.id,
      nome: result['nome'],
      isReceita: tipo == 'receita' || tipo == 'recebivel',
      isRecebivel: tipo == 'recebivel',
      icone: result['icone'],
      limite: result['limite'] as double?,
    );
    await _storage.atualizarGrupo(atualizado);
    _carregar();
  }

  Future<void> _remover(Grupo grupo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover grupo'),
        content: Text('Excluir "${grupo.nome}"?'),
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
      await _storage.removerGrupo(grupo.id);
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final receitaGrupos = _storage.grupos.where((g) => g.isReceita && !g.isRecebivel).toList();
    final despesaGrupos = _storage.grupos.where((g) => !g.isReceita).toList();
    final recebivelGrupos = _storage.grupos.where((g) => g.isRecebivel).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Grupos',
          style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 2.0),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF001529),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionar,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Receitas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          ...receitaGrupos.map((g) => _buildGrupoTile(g)),
          const SizedBox(height: 24),
          const Text('Despesas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          ...despesaGrupos.map((g) => _buildGrupoTile(g)),
          const SizedBox(height: 24),
          const Text('Recebíveis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          ...recebivelGrupos.map((g) => _buildGrupoTile(g)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGrupoTile(Grupo grupo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color cor;
    if (grupo.isRecebivel) {
      cor = Colors.orange;
    } else {
      cor = grupo.isReceita ? Colors.green : Colors.red;
    }

    return Card(
      child: ListTile(
        leading: Icon(grupo.icone, color: cor),
        title: Text(grupo.nome),
        subtitle: grupo.limite != null && !grupo.isReceita
            ? Text('Limite: R\$ ${formatBRL(grupo.limite!)}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.grey),
              onPressed: () => _editar(grupo),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _remover(grupo),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrupoDialog extends StatefulWidget {
  final Grupo? grupo;

  const _GrupoDialog({this.grupo});

  @override
  State<_GrupoDialog> createState() => _GrupoDialogState();
}

class _GrupoDialogState extends State<_GrupoDialog> {
  final _nomeController = TextEditingController();
  final _limiteController = TextEditingController();
  late String _tipo; // 'receita', 'despesa', 'recebivel'
  late IconData _iconeSelecionado;

  final _iconesDisponiveis = const [
    Icons.work, Icons.computer, Icons.trending_up, Icons.attach_money,
    Icons.account_balance, Icons.savings, Icons.payments, Icons.card_giftcard,
    Icons.restaurant, Icons.directions_car, Icons.home, Icons.local_hospital,
    Icons.sports_esports, Icons.school, Icons.checkroom, Icons.shopping_cart,
    Icons.fitness_center, Icons.pets, Icons.flight, Icons.phone_android,
    Icons.water_drop, Icons.bolt, Icons.wifi, Icons.celebration,
    Icons.miscellaneous_services, Icons.favorite, Icons.music_note, Icons.palette,
    Icons.auto_awesome, Icons.clean_hands,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.grupo != null) {
      if (widget.grupo!.isRecebivel) {
        _tipo = 'recebivel';
      } else {
        _tipo = widget.grupo!.isReceita ? 'receita' : 'despesa';
      }
    } else {
      _tipo = 'receita';
    }
    _iconeSelecionado = widget.grupo?.icone ?? Icons.work;
    if (widget.grupo != null) {
      _nomeController.text = widget.grupo!.nome;
      if (widget.grupo!.limite != null) {
        _limiteController.text = widget.grupo!.limite!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _limiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.grupo != null;
    final isDespesa = _tipo == 'despesa';

    return AlertDialog(
      title: Text(isEditing ? 'Editar Grupo' : 'Novo Grupo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do grupo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'receita', label: Text('Receita'), icon: Icon(Icons.add_circle)),
                ButtonSegment(value: 'despesa', label: Text('Despesa'), icon: Icon(Icons.remove_circle)),
                ButtonSegment(value: 'recebivel', label: Text('Recebível'), icon: Icon(Icons.receipt_long)),
              ],
              selected: {_tipo},
              onSelectionChanged: (v) => setState(() => _tipo = v.first),
            ),
            if (isDespesa) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _limiteController,
                decoration: const InputDecoration(
                  labelText: 'Limite de gasto (R\$)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 16),
            Text('Ícone:', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : null)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _iconesDisponiveis.map((ic) {
                final selecionado = ic == _iconeSelecionado;
                return GestureDetector(
                  onTap: () => setState(() => _iconeSelecionado = ic),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selecionado ? (isDark ? Colors.teal.shade700 : Colors.teal.shade100) : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selecionado ? Colors.teal : (isDark ? Colors.grey[600]! : Colors.grey.shade300),
                        width: 2,
                      ),
                    ),
                    child: Icon(ic, size: 24, color: selecionado ? Colors.teal : (isDark ? Colors.grey[400] : Colors.grey[600])),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_nomeController.text.trim().isEmpty) return;
            double? limite;
            if (isDespesa && _limiteController.text.trim().isNotEmpty) {
              limite = double.tryParse(_limiteController.text.replaceAll(',', '.'));
            }
            Navigator.pop(context, {
              'nome': _nomeController.text.trim(),
              'tipo': _tipo,
              'icone': _iconeSelecionado,
              'limite': limite,
            });
          },
          child: Text(isEditing ? 'Atualizar' : 'Salvar'),
        ),
      ],
    );
  }
}
