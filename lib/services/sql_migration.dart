const String sqlMigration = '''
-- =============================================
-- SQL para criar as tabelas no Supabase
-- =============================================
-- Como usar:
-- 1. Acesse https://supabase.com e crie um projeto
-- 2. Vá em "SQL Editor" no menu lateral
-- 3. Cole este script e execute
-- =============================================

-- Remover tabelas antigas para aplicar a nova estrutura sem conflitos
DROP TABLE IF EXISTS transacoes CASCADE;
DROP TABLE IF EXISTS grupos CASCADE;
DROP TABLE IF EXISTS recebiveis CASCADE;
DROP TABLE IF EXISTS contas_pagar CASCADE;

-- Tabela de Grupos (Criada primeiro porque transacoes e recebiveis dependem dela)
CREATE TABLE IF NOT EXISTS grupos (
  id TEXT PRIMARY KEY,
  nome TEXT NOT NULL,
  "isReceita" BOOLEAN NOT NULL,
  "isRecebivel" BOOLEAN DEFAULT FALSE,
  "iconCodePoint" INTEGER NOT NULL,
  limite DOUBLE PRECISION
);

-- Tabela de Transações
CREATE TABLE IF NOT EXISTS transacoes (
  id TEXT PRIMARY KEY,
  descricao TEXT NOT NULL,
  valor DOUBLE PRECISION NOT NULL,
  "isReceita" BOOLEAN NOT NULL,
  data TIMESTAMP NOT NULL,
  "grupoId" TEXT,
  "recebivelId" TEXT,
  "isDigital" BOOLEAN DEFAULT FALSE
);

-- Tabela de Recebíveis
CREATE TABLE IF NOT EXISTS recebiveis (
  id TEXT PRIMARY KEY,
  descricao TEXT NOT NULL,
  valor DOUBLE PRECISION NOT NULL,
  mes INTEGER NOT NULL,
  ano INTEGER NOT NULL,
  data TIMESTAMP,
  "grupoId" TEXT,
  recebido BOOLEAN DEFAULT FALSE,
  recorrente BOOLEAN DEFAULT FALSE,
  "mesFim" INTEGER,
  "anoFim" INTEGER,
  "isDigital" BOOLEAN DEFAULT FALSE
);

-- Tabela de Contas a Pagar
CREATE TABLE IF NOT EXISTS contas_pagar (
  id TEXT PRIMARY KEY,
  descricao TEXT NOT NULL,
  valor DOUBLE PRECISION NOT NULL,
  mes INTEGER NOT NULL,
  ano INTEGER NOT NULL,
  data TIMESTAMP,
  "grupoId" TEXT,
  pago BOOLEAN DEFAULT FALSE,
  recorrente BOOLEAN DEFAULT FALSE,
  "mesFim" INTEGER,
  "anoFim" INTEGER,
  "isDigital" BOOLEAN DEFAULT FALSE
);

-- Índices para consultas rápidas
CREATE INDEX IF NOT EXISTS idx_transacoes_data ON transacoes(data);
CREATE INDEX IF NOT EXISTS idx_transacoes_grupo ON transacoes("grupoId");
CREATE INDEX IF NOT EXISTS idx_recebiveis_mes_ano ON recebiveis(mes, ano);
CREATE INDEX IF NOT EXISTS idx_recebiveis_grupo ON recebiveis("grupoId");
CREATE INDEX IF NOT EXISTS idx_contas_pagar_mes_ano ON contas_pagar(mes, ano);
CREATE INDEX IF NOT EXISTS idx_contas_pagar_grupo ON contas_pagar("grupoId");

-- Desativar RLS para permitir a sincronização direta do aplicativo nos testes
ALTER TABLE transacoes DISABLE ROW LEVEL SECURITY;
ALTER TABLE grupos DISABLE ROW LEVEL SECURITY;
ALTER TABLE recebiveis DISABLE ROW LEVEL SECURITY;
ALTER TABLE contas_pagar DISABLE ROW LEVEL SECURITY;

-- Adicionar colunas novas em tabelas existentes (execução segura mesmo se já existirem)
ALTER TABLE transacoes ADD COLUMN IF NOT EXISTS "isDigital" BOOLEAN DEFAULT FALSE;
ALTER TABLE recebiveis ADD COLUMN IF NOT EXISTS "isDigital" BOOLEAN DEFAULT FALSE;

-- =============================================
-- Ativar Realtime para as tabelas
-- =============================================
-- Isso permite que o aplicativo receba atualizações em tempo real
-- quando outros dispositivos modificarem os dados
-- =============================================

-- Adiciona as tabelas à publicação de realtime
ALTER PUBLICATION supabase_realtime ADD TABLE transacoes;
ALTER PUBLICATION supabase_realtime ADD TABLE grupos;
ALTER PUBLICATION supabase_realtime ADD TABLE recebiveis;
ALTER PUBLICATION supabase_realtime ADD TABLE contas_pagar;
''';
