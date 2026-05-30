import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transacao.dart';
import '../models/grupo.dart';
import '../services/storage_service.dart';

class AddTransacaoScreen extends StatefulWidget {
  final bool isReceita;
  final Transacao? transacao;

  const AddTransacaoScreen({super.key, this.isReceita = true, this.transacao});

  @override
  State<AddTransacaoScreen> createState() => _AddTransacaoScreenState();
}

class _AddTransacaoScreenState extends State<AddTransacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  late bool _isReceita;
  late DateTime _data;
  String? _grupoId;
  bool _isDigital = true;
  final _storage = StorageService.instance;
  List<Grupo> _grupos = [];

  @override
  void initState() {
    super.initState();
    _isReceita = widget.transacao?.isReceita ?? widget.isReceita;
    _data = widget.transacao?.data ?? DateTime.now();
    if (widget.transacao != null) {
      _descricaoController.text = widget.transacao!.descricao;
      _valorController.text = widget.transacao!.valor.toStringAsFixed(2);
      _grupoId = widget.transacao!.grupoId;
      _isDigital = widget.transacao!.isDigital ?? true;
    }
    _carregarGrupos();
  }

  void _carregarGrupos() {
    _grupos = _storage.grupos.where((gr) => gr.isReceita == _isReceita).toList();
    if (_grupoId == null && _grupos.isNotEmpty) {
      _grupoId = _grupos.first.id;
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final transacao = Transacao(
      id: widget.transacao?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: _descricaoController.text,
      valor: double.parse(_valorController.text.replaceAll(',', '.')),
      isReceita: _isReceita,
      data: _data,
      grupoId: _grupoId,
      isDigital: _isDigital,
    );

    String? erro;
    if (widget.transacao != null) {
      erro = await _storage.atualizarTransacao(transacao);
    } else {
      erro = await _storage.adicionarTransacao(transacao);
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

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _data = picked);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.transacao != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing
            ? 'Editar ${_isReceita ? 'Receita' : 'Despesa'}'
            : (_isReceita ? 'Nova Receita' : 'Nova Despesa')),
        backgroundColor: _isReceita ? Colors.green : Colors.red,
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
                labelText: 'Valor',
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
                    Icon(g.icone, size: 20, color: _isReceita ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(g.nome),
                  ],
                ),
              )).toList(),
              onChanged: (v) => setState(() => _grupoId = v),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Data: ${DateFormat('dd/MM/yyyy').format(_data)}'),
              onTap: _selecionarData,
            ),
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
                backgroundColor: _isReceita ? Colors.green : Colors.red,
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
