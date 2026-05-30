# Gestão Financeira

Aplicativo mobile para controle de finanças pessoais desenvolvido em Flutter.
- Download: https://github.com/I-BDS/Controle-Financeiro-APK/releases/tag/v1.0.0

## Funcionalidades

- **Carteira**: Registro de receitas e despesas com filtro por mês/ano
- **Recebíveis**: Controle de valores a receber, com suporte a recebimentos recorrentes
- **Análise**: Gráfico mensal comparando receitas, despesas e valores a receber
- **Grupos**: Categorias personalizáveis para organizar lançamentos
- **Sincronização na nuvem**: Conecte com Supabase para manter os dados sincronizados em tempo real entre dispositivos
- **Modo noturno**: Alterna entre tema claro e escuro

## Tecnologias

- Flutter
- SharedPreferences (armazenamento local)
- Supabase (sincronização na nuvem)
- fl_chart (gráficos)

## Como usar

1. Crie um projeto gratuito em [supabase.com](https://supabase.com)
2. Em **Project Settings → API**, copie a **Project URL** e a **Anon Key**
3. No app, vá em **Configurações → Supabase** e cole as credenciais
4. Em **Configurações → Banco de Dados**, copie o script SQL e execute no SQL Editor do Supabase para criar as tabelas
5. Pronto! Os dados serão sincronizados automaticamente
