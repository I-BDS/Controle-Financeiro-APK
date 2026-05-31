# Gestão Financeira

Aplicativo mobile para controle de finanças pessoais desenvolvido em Flutter.
- Download: https://github.com/I-BDS/Controle-Financeiro-APK/releases/tag/v1.0.0

## Funcionalidades

- **Carteira**: Registro de receitas e despesas com filtro por mês/ano, tipo Digital/Dinheiro, filtro por data customizado e alertas de limites excedidos por grupo
- **Recebíveis**: Controle de valores a receber com suporte a recebimentos recorrentes, filtro por período e lançamento direto como receita na carteira
- **Análise**: Gráfico mensal comparando receitas, despesas e valores a receber, com indicador de progresso do limite da Receita Federal (apenas lançamentos digitais)
- **Grupos**: Categorias personalizáveis com ícones e limites de gasto para organizar lançamentos
- **Armazenamento Local**: Modo offline sem necessidade de conexão com banco externo, dados salvos no próprio dispositivo
- **Supabase**: Modo nuvem com sincronização em tempo real entre dispositivos; migração seletiva por período ao ativar
- **Modo noturno**: Alterna entre tema claro e escuro

## Tecnologias

- Flutter (Material 3)
- Supabase (banco de dados + realtime)
- SharedPreferences (preferências + armazenamento local de dados)
- fl_chart (gráficos)

## Como usar

### Modo Local (offline)
1. Abra o app e vá em **Configurações → Modo de Armazenamento**
2. Selecione **Local** — os dados ficam salvos apenas no dispositivo

### Modo Supabase (nuvem)
1. Crie um projeto gratuito em [supabase.com](https://supabase.com)
2. Em **Project Settings → API**, copie a **Project URL** e a **Anon Key**
3. No app, vá em **Configurações → Supabase** e cole as credenciais
4. Em **Configurações → Banco de Dados**, copie o script SQL e execute no SQL Editor do Supabase para criar as tabelas
5. Em **Configurações → Modo de Armazenamento**, selecione **Supabase**
6. Se houver dados locais, eles serão sincronizados com o banco. Caso contrário, escolha entre baixar do banco ou sobrescrever o banco com dados vazios

> ⚠️ Os modos Local e Supabase são exclusivos. Ao ativar um, o outro é desativado.
