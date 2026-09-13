# LibreOffice PT-BR Dictionary 32b006a Rejection

- Source ID: `libreoffice-pt-br-dictionary`
- Decision: `REJECTED`
- Decision time: `2026-08-28T01:20:01Z`
- Canonical URL: `https://github.com/LibreOffice/dictionaries`
- Commit: `32b006a2c22a4ac7e8ed3f03346f7b3d85a970a4`
- Tree: `3330d698e5c0e4864cf6db7dbd5a26e7cd507658`
- Inspected path: `pt_BR`
- Intended review use: PT-BR lexicon and morphology
- Allowed project use after decision: `none`

## Identity And Coverage

An isolated repository fetched the exact commit and checked it out detached.
The worktree was clean. A deterministic tar archive of `pt_BR` is 26,408,960
bytes with SHA-256
`562f1c7e5a4d8b5d4e1493e1f318379c53d8541dcada28dcfb3d5ec66e141641`.
The subtree contains 31 files and 26,367,777 tracked bytes.

The Hunspell dictionary declares 312,368 entries. `pt_BR/pt_BR.dic` is
4,477,695 bytes with SHA-256
`a38bfb26b68ece2834e79fe83e48d5792652970ace12db89d1b9674bf9933183`;
`pt_BR/pt_BR.aff` is 979,792 bytes with SHA-256
`21d8ad2a769a60e17e2b5ea4ef11d4d593a58b9e2a82d642ef82d6a4c5523865`.
The affix file has 25,932 prefix/suffix rule rows. The selected data is useful
for spell acceptance and inflection generation, but it supplies no lexical
POS labels, contextual sentences, semantic oracle, or documented frequency.

## License And Provenance

`pt_BR/README_pt_BR.txt` attributes the work to Raimundo Moura and his team,
claims LGPL version 3 and the Mozilla Public License, and permits
redistribution and modification. Its SHA-256 is
`9974ce691fdc1fe731717d7a2dc668244405fdc2bf9bf3367eb9b29e85177c88`.
The affix header repeats LGPLv3 plus an unversioned Mozilla Public License.

The exact subtree contains neither complete LGPLv3 nor complete MPL legal
text. It does not say whether the two licenses are alternatives or cumulative,
and it does not identify the MPL version for the dictionary. Other files in
the subtree use different, path-specific notices, so a license copied from
another directory cannot resolve the selected payload's terms.

History shows that the dictionary and affix files were changed in 2020 and
2021 after the 2006-2013 copyright notice, while the source-specific README
was last changed in 2014. The repository identifies commit authors, but the
selected payload has no complete current contributor/rightsholder inventory
or inbound grant record. The exact linguistic data therefore cannot satisfy
the complete-license, unambiguous-expression, and actual-rightsholder gates.

## Decision And Removal

The candidate is rejected because its exact license choice and complete terms
are ambiguous. Independently, it cannot provide the contextual POS,
frequency-lineage, or semantic-evaluation evidence P02 needs. No source byte
entered the project repository or influenced language behavior. The
quarantine checkout was deleted and targeted post-removal checks found no
remaining path.

Commands used: exact-commit Git fetch and detached checkout; filtered history
fetch; `git rev-parse`, `git status`, `git log`, `git archive`, `find`,
`grep`, `sed`, `wc`, and SHA-256.
