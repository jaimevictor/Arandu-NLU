# Revisões locais da correção 0.4.5

Data: 2026-10-14. Duas revisões de escopo realizadas pelo executor; não são
revisões independentes. As duas examinam o mesmo código validado por
`./tools/mlp-check`, fingerprint
`9d396df1df1f535d6b97b63d7eaca7f9c5c7738b36ee4063293cd0592528ad5d`.

## Produto e comportamento seguro

Sem achados materiais. Rust e Python concordam sobre o conjunto disponível;
estado ausente, desconhecido ou indisponível desde o snapshot não bloqueia os
demais alvos coletivos. Conjunto vazio e alvo offline pedido diretamente não
executam. Mudanças de disponibilidade, permissões, exposição e origem abortam
antes dos efeitos. Limite de 32, exclusões e rejeição de planos contraditórios
permanecem cobertos por testes. Alvo nomeado ausente recebe seu nome entendido,
sem execução nem continuação automática; capacidade ausente permanece distinta.

## Segurança, privacidade, licenças e pacotes

Sem achados materiais. A interpretação permanece passiva no add-on; somente
a integração valida permissões e chama serviços tipados. O nome na resposta
vem do pedido local, sem consultar ou revelar entidades não expostas. Logs e
diagnósticos continuam contendo apenas estágio/código/motivo desse erro.
Não foram acrescentadas dependências, credenciais ou dados residenciais.
Os pacotes preservam versões, allowlists, licenças, CRC e SHA-256 verificados.

Limitações: serviços, usuários e registries HA foram simulados nos testes HTTP
com motor Rust real. Não houve execução residencial nem revisão independente.
