# Ambiente de desenvolvimento

O add-on distribuído continua usando Rust 1.98.0 / Alpine 3.22, digest fixado em `addon/container-inputs.json`, e runtime scratch sem pacotes. O ambiente de testes adiciona ferramentas ao builder; elas não entram na imagem runtime.

| Entrada | Versão | Licença / fonte | Uso |
|---|---|---|---|
| Python | 3.12.15-r0 | PSF-2.0; https://www.python.org/downloads/release/python-31215/ | testes e ferramentas |
| tzdata | 2026e-r0 | domínio público, avisos upstream BSD; https://www.iana.org/time-zones | ZoneInfo nos testes de datas locais |
| Ruby | 3.4.4-r0 | Ruby/BSD-2-Clause; https://www.ruby-lang.org/ | corpus MLP existente |
| ruby-yaml | 0.4.0-r1 | MIT (Psych); https://github.com/ruby/psych | verificações YAML existentes |
| Git | pacote Alpine do builder | GPL-2.0; https://git-scm.com/ | proveniência e checks de árvore |

Fontes dos pacotes: https://pkgs.alpinelinux.org/packages?branch=v3.22 . Ruby, Python e timezone estão fixados no Dockerfile. Git continua seguindo o pacote do ambiente de desenvolvimento herdado; isso não torna o ambiente completo bit a bit reproduzível. Crates da distribuição permanecem com versões/checksums/licenças fixados e fontes vendorizadas, sem dependências Rust novas.

Foi necessário normalizar CRLF de scripts no staging Linux e copiar todos os catálogos de teste `data/`, inclusive Phase B. Locks e licenças equivalentes são comparados com normalização de fim de linha; conteúdos e versões continuam verificados.

## Validação HACS opcional/CI

Nenhum pacote Python novo é necessário no runtime ou no gate offline.
O probe oficial e o job HACS usam somente o ambiente oficial de desenvolvimento:

| Entrada | Referência congelada | Licença / proveniência | Uso |
| --- | --- | --- | --- |
| HACS Action container | ghcr.io/hacs/action@sha256:dc92fdad2f6ffbe74bffb7269d781ea8e064f52d9bb486cdf3925d74e7ab6ebf | MIT; hacs/integration, revisão OCI 3f3080cbf909b8f51488e227be73f62902b4ef6c | schemas oficiais, registro/consumidor com fixtures; validação GitHub no CI |
| Home Assistant no container acima | 2026.8.3 | Apache-2.0; home-assistant/core | ambiente do validador, não evidência HA residencial |
| actions/checkout | 11d5960a326750d5838078e36cf38b85af677262 (v4) | MIT; https://github.com/actions/checkout | checkout sem credenciais persistidas |
| actions/setup-python | a26af69be951a213d495a4c3e4e4022e16d87065 (v5) | MIT; https://github.com/actions/setup-python | Python 3.12 para testes/empacotamento CI |

O wrapper hacs/action consultado usa docker://ghcr.io/hacs/action:main, mutável;
o workflow utiliza diretamente seu container oficial por digest imutável.
Atualizar esse digest exige conferir novamente schemas/consumidor, licenças e
exceções de catálogo. O container não é redistribuído no add-on/pacote Python.
