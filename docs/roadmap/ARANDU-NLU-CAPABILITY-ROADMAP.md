# Arandu NLU Capability Roadmap

Status: histórico de capacidades; não substitui o contrato MLP vigente.
Escopo normativo atual: `MLP`, conforme `AGENTS.md`, ADR-0050 e `docs/phases/PROJECT-STATUS.md`.
Escopo desta evidência: `UNDERSTANDING` PT-BR, por HTTP local, sem execução Home Assistant.

> ADR-0050 supersede a mecânica P00-P16 e qualquer sequência de fases antiga. Este documento registra evidências de Phase A e Phase B; não autoriza Phase C, P15 ou P16. A autoridade atual é `AGENTS.md`, seguida pelo ADR ativo mais recente e por `docs/phases/PROJECT-STATUS.md`.

## 1. Regras de governança

1. Cada fase começa com corpus independente, oracle semântico, casos positivos e negativos, casos ambíguos e testes de segurança.
2. Dataset e catálogo congelam antes de qualquer request ao produto.
3. Baseline ampliado registra resultados reais antes de alterar `addon/engine/src/`.
4. Nenhum label muda em resposta ao output do produto.
5. Implementação usa somente requisitos e evidências admitidas pelo repositório. Não usa Sophia, Aquila, outro motor, diretório irmão ou implementação anterior.
6. Falha fechada em ambiguidade, input inválido, comportamento não suportado, catálogo stale, entidade não exposta, permissão negada ou falha de transporte.
7. O núcleo NLU interpreta e produz evidência. Gestor de diálogo e política compõem proposta. Integração Home Assistant revalida e executa. O add-on não recebe credenciais nem executa services.

## 2. Capacidades candidatas

- aliases PT-BR e variações ortográficas controladas;
- áreas e localização explícita;
- plurais controlados, sem inferência livre;
- consultas de estado para entidades suportadas;
- composição de operações ordenadas e limitada;
- clarification estruturada para ambiguidade;
- contexto curto e correferência com sessão explícita;
- negação somente após requisito aprovado;
- correção sugerida, preservando texto original e evidência;
- controle absoluto e relativo de ventilador, com limites explícitos;
- permissões e revalidação na fronteira de execução.

## 3. Fora do escopo imediato

Não implementar agora execução no add-on, credenciais, rotinas, cenas, automações condicionais, resposta livre, áudio, descoberta externa, escolha silenciosa em ambiguidade ou comparação de acurácia externa.

## 4. Fases e gates

### Fase A — aliases, áreas, plurais e queries

Concluída em 2026-09-17. Corpus v2 tem 144 casos: 72 `expected-pass-now`, 48 `expected-reject-now` e 24 `known-gap-future`. Resultado: 144/144 `exact_pass`; 120/120 casos pontuados; 24 known gaps fora do score. Benchmark: 1008 medições, zero falhas steady-state e cold-start, RSS máximo de 786432 bytes via `VmRSS`, HWM máximo de 1347584 bytes via `VmHWM`. Baseline registrado em `evaluation/ptbr-independent/baselines/v2/`. Freeze v1 preservado. Ressalvas: dados sintéticos autorados pelo projeto, sem segundo anotador, labels não derivados do output do produto e sem alegação de avaliação linguística externa independente.

### Fase B — composição segura (concluída como evidência histórica)

Concluída no escopo limitado do parser atual, sem alterar protocol v1. Corpus independente: 23 casos, sendo 10 `expected-pass-now` e 13 `expected-reject-now`. Resultado real: 23/23 `exact_pass`, zero falhas. Testes: 25 Rust, 39 Python e Clippy aprovado. Benchmark: 115 requests, zero falhas; cold start, primeira requisição, latências, throughput, RSS e HWM registrados em `target/ptbr-independent-phase-b/benchmark-v1.json`. Baseline B permanece separado em relação ao baseline A.

Limitações: composição passiva de `Vec<Operation>`; sem `ComposedPlan` evidence-bound completo do ADR-0017; sem session-engine do ADR-0018; sem execução Home Assistant; corpus sintético autorado pelo projeto; sem avaliação linguística externa independente. Freeze atual: `evaluation/ptbr-independent/phase-b/freeze-v1.json`; freeze pré-expansão preservado em `freeze-v1-pre-expansion.json`.

### Próxima fase normativa

Nenhuma fase nova está autorizada. ADR-0050 define `FINAL_MLP_DELIVERED` em `docs/phases/PROJECT-STATUS.md`. A fila `AUTONOMOUS-QUEUE.yaml` e o roadmap arquitetural antigo são históricos/stale e não promovem Phase C, P15 ou P16. Nova capacidade exige requisito e decisão normativa novos.

### Capacidades futuras não ativadas

Clarification estruturada, contexto curto, correferência, negação, correção sugerida, incrementos relativos de fan, cenas e automações permanecem fora do escopo ativo. Qualquer ativação exige RFC/ADR, corpus independente, oracle, freeze, baseline, testes de rejeição insegura e aprovação explícita.

## 5. Critérios de aceite comuns

- determinismo para mesmo input e catálogo;
- Unicode e spans rastreáveis;
- catálogo snapshot imutável durante interpretação;
- candidatos limitados e ambiguidade visível;
- limites de operações, targets e valores validados;
- sem execução ou chamada Home Assistant no núcleo;
- testes de protocolo, segurança, regressão e comportamento negativo;
- hashes, proveniência, relatório e decisão de avanço registrados.

## 6. Riscos e evidências

Riscos principais: alias excessivo, pluralização insegura, resolução por ordem de catálogo, contexto stale, composição parcial e confusão entre interpretação e execução. Evidência mínima: corpus versionado, provenance, oracle independente, freeze, baseline antes/depois, relatório de divergências e teste de rejeição insegura.

Este registro histórico referencia `docs/architecture/06-roadmap.md`, `docs/clean-room/02-functional-requirements.md` e ADR-0015, ADR-0016, ADR-0017 e ADR-0018. Em caso de conflito, ADR-0050 e `docs/phases/PROJECT-STATUS.md` prevalecem. Não declara compatibilidade com Sophia nem acurácia externa.
