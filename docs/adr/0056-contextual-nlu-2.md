# ADR 0056 — Motor contextual aditivo NLU 2.0

Status: implementado.

A missão explícita do usuário amplia o escopo MLP e autoriza examinar o repositório STT adjacente. As exclusões antigas de climate, consultas amplas e corpus STT não limitam essa missão. As fronteiras de segurança, licenças e execução continuam válidas.

Adicionamos contrato v4 contextual e adaptadores fechados no executor Python. Conservamos os contratos e testes v1/v2/v3 e os arquivos já modificados pelo usuário. Semântica não é igual ao rótulo STT: 165 intenções têm disposição explícita; operações universais usam serviço real, operações sem serviço universal dependem de adaptador configurado ou abstêm.

Templates MIT do STT são incorporados com licença e proveniência verificadas. Métricas do mesmo corpus são conformidade interna; não são acurácia independente. Testes adicionais congelados, contraprovas de segurança, executor integrado e benchmarks medidos complementam essa referência.

Consequências: contexto temporário fica no Python, snapshots compilados ficam no Rust, valores atuais são lidos no HA. Nenhum ID residencial, token, cloud API ou comando arbitrário é inserido no executável. Configurações avançadas são explícitas e o rollback é uma opção sem migração persistente.
