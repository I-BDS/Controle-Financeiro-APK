import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recebivel.dart';
import '../models/grupo.dart';
import '../services/storage_service.dart';

class AddRecebivelScreen extends StatefulWidget {
  final Recebivel? recebivel;

  const AddRecebivelScreen({super.key, this.recebivel});

  @override
  State<AddRecebivelScreen> createState() => _AddRecebivelScreenState();
}

class _AddRecebivelScreenState extends State<AddRecebivelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  late int _mes;
  late int _ano;
  DateTime? _data;
  String? _grupoId;
  bool _recebido = false;
  bool _recorrente = false;
  bool _isDigital = true;
  late int _mesFim;
  late int _anoFim;
  final _storage = StorageService.instance;
  List<Grupo> _grupos = [];

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    _mes = widget.recebivel?.mes ?? DateTime.now().month;
    _ano = widget.recebivel?.ano ?? DateTime.now().year;
    _data = widget.recebivel?.data;
    _grupoId = widget.recebivel?.grupoId;
    _recebido = widget.recebivel?.recebido ?? false;
    _recorrente = widget.recebivel?.recorrente ?? false;
    _isDigital = widget.recebivel?.isDigital ?? true;
    _mesFim = widget.recebivel?.mesFim ?? _mes;
    _anoFim = widget.recebivel?.anoFim ?? _ano;
    if (widget.recebivel != null) {
      _descricaoController.text = widget.recebivel!.descricao;
      _valorController.text = widget.recebivel!.valor.toStringAsFixed(2);
    }
    _carregarGrupos();
  }

  void _carregarGrupos() {
    _grupos = _storage.grupos.where((gr) => gr.isRecebivel).toList();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final recebivel = Recebivel(
      id: widget.recebivel?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: _descricaoController.text,
      valor: double.parse(_valorController.text.replaceAll(',', '.')),
      mes: _mes,
      ano: _ano,
      data: _data,
      grupoId: _grupoId,
      recebido: _recebido,
      recorrente: _recorrente,
      mesFim: _recorrente ? _mesFim : null,
      anoFim: _recorrente ? _anoFim : null,
      isDigital: _isDigital,
    );

    String? erro;
    if (widget.recebivel != null) {
      erro = await _storage.atualizarRecebivel(recebivel);
    } else {
      erro = await _storage.adicionarRecebivel(recebivel);
    }
    if (erro != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(erro),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _selecionarMesAno(bool isInicio) async {
    final tempMes = isInicio ? _mes : _mesFim;
    final tempAno = isInicio ? _ano : _anoFim;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        int m = tempMes;
        int a = tempAno;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, DateTime(a, m)),
                child: const Text('Selecionar'),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isInicio) { _mes = picked.month; _ano = picked.year; }
        else { _mesFim = picked.month; _anoFim = picked.year; }
      });
    }
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data ?? DateTime(_ano, _mes.clamp(1, 12), 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _data = picked);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.recebivel != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar Recebível' : 'Novo Recebível'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Informe a descrição' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valorController,
              decoration: const InputDecoration(
                labelText: 'Valor a receber',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                final valor = double.tryParse(v.replaceAll(',', '.'));
                if (valor == null || valor <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text('Mês: ${_meses[_mes - 1]} $_ano'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () => _selecionarMesAno(true),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Recorrente (vários meses)'),
              subtitle: _recorrente
                  ? Text('${_meses[_mes - 1]} $_ano — ${_meses[_mesFim - 1]} $_anoFim',
                      style: const TextStyle(fontSize: 12))
                  : null,
              value: _recorrente,
              onChanged: (v) => setState(() {
                _recorrente = v;
                if (v) { _mesFim = _mes; _anoFim = _ano; }
              }),
            ),
            if (_recorrente) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text('Até: ${_meses[_mesFim - 1]} $_anoFim'),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () => _selecionarMesAno(false),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Definir data específica'),
              value: _data != null,
              onChanged: (v) => setState(() => _data = v ? DateTime(_ano, _mes.clamp(1, 12), 1) : null),
            ),
            if (_data != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('Data: ${DateFormat('dd/MM/yyyy').format(_data!)}'),
                onTap: _selecionarData,
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Já recebido'),
              value: _recebido,
              onChanged: (v) => setState(() => _recebido = v),
            ),
            if (_grupos.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _grupoId,
                decoration: const InputDecoration(
                  labelText: 'Grupo',
                  border: OutlineInputBorder(),
                ),
                items: _grupos.map((g) => DropdownMenuItem(
                  value: g.id,
                  child: Row(
                    children: [
                      Icon(g.icone, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(g.nome),
                    ],
                  ),
                )).toList(),
                onChanged: (v) => setState(() => _grupoId = v),
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Digital'), icon: Icon(Icons.phone_android)),
                ButtonSegment(value: false, label: Text('Dinheiro'), icon: Icon(Icons.receipt)),
              ],
              selected: {_isDigital},
              onSelectionChanged: (v) => setState(() => _isDigital = v.first),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _salvar,
              child: Text(editing ? 'Atualizar' : 'Salvar', style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
