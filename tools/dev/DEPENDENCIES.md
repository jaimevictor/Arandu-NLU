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
