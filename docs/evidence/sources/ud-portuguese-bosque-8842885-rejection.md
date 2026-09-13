# UD Portuguese Bosque 8842885 Rejection

- Source ID: `ud-portuguese-bosque`
- Decision: `REJECTED`
- Decision time: `2026-08-28T01:10:38Z`
- Canonical URL:
  `https://github.com/UniversalDependencies/UD_Portuguese-Bosque`
- Commit: `884288537f7e8e02e50f125791cf279d905d1043`
- Tree: `231df45fffbfb0f721f3f32f6ff3f9fcfa3c63d5`
- Intended review use: PT-BR contextual POS and morphology evaluation
- Allowed project use after decision: `none`

## Acquisition And Identity

The admitted Apple-distributed Git executable initialized an isolated
quarantine repository, set the canonical remote, fetched the exact commit, and
checked out `FETCH_HEAD` detached. The resolved commit and tree matched the
identities above, the worktree was clean, and filtered history was fetched
only to investigate the license lineage.

The commit contains 4,014 tracked files and 33,856,537 tracked blob bytes. A
deterministic `git archive --format=tar` is 37,416,960 bytes with SHA-256
`677fa2b94198885a1bc09061ba9833f815cd31bd1889fd16835359723e4f3a6b`.
No archive or source byte entered the project repository.

## License And Rightsholder Review

The repository claims CC-BY-SA-4.0. Its 269-byte `LICENSE.txt` has SHA-256
`ab3a36080055dd29ad2b59162e43d1368c7f15643666bea982d4e103f546e025`
and is only a pointer to the license, not the complete legal text. The complete
official CC-BY-SA-4.0 legal-code text retrieved for review was 20,138 bytes
with SHA-256
`28a9529c7d0bb4dc51f4bf5c116a3d16ef247a052f7591466768ddf563fd1cf5`.

CC-BY-SA-4.0 would permit commercial reproduction, sharing, and adaptation if
the licensor had authority over the licensed material. It requires
attribution and notices, change indication, ShareAlike licensing for adapted
material, and no additional downstream restrictions.

The repository README states that Bosque includes text from CETENFolha and
CETEMPUBLICO. The official Linguateca material page confirms that these are
extracts from Folha de S. Paulo and PUBLICO newspapers. The official
CETENFolha page describes a negotiated authorization to make the corpus
available and explains that text is divided into extracts for legal reasons.
The official CETEMPUBLICO page describes a protocol with PUBLICO. None of the
inspected origin pages publishes terms granting commercial modification and
redistribution or authority for a later blanket CC-BY-SA license.

History makes the conflict concrete. Commit
`b68cab32f47fd14f3b0cd2d74ebc157d07cf252f`, authored by Dan Zeman on
2017-01-28 with subject `Prepared README and LICENSE for merging.`, changed
the license pointer from CC-BY-NC-SA-3.0 to CC-BY-SA-4.0. No corresponding
grant from Folha, PUBLICO, article authors, or another actual text
rightsholder is recorded in that commit or the inspected source materials.
A repository maintainer cannot independently expand rights held by those
rightsholders.

Exact mutable official-page responses inspected on 2026-08-28 included:

| Official page | Bytes | SHA-256 |
| --- | ---: | --- |
| Linguateca Floresta landing frame | 243 | `58675a1473e2119026a67dc5082b6ccc03ad45728b08753c6dccc437a7966cbd` |
| Floresta principal page | 5,007 | `f48411c9f21b78237a73bdf66e9ff3bab655ecb43c49e568b0f18aa92fa5cf52` |
| Floresta download page | 7,902 | `df612f767e864933d8276b26756082452f8bdc126f53509fbd415855169cd15c` |
| Floresta material page | 27,005 | `0444167243aaf4a3a1f91ef81db592df307cbd1adfa70a0a8fd4b204c555ba62` |
| CETENFolha information page | 18,934 | `23fa1478f149b40cea729768d5327797d1e019b68692ebce1f2217338f19c048` |
| CETEMPUBLICO information page | 2,490 | `8cc080913135665b413e4dc18cb83680758279b7efad0181304f5ae125a75b21` |

The current license claim therefore fails the project's underlying-content,
actual-rightsholder, complete-license, commercial-use, modification, and
redistribution evidence requirements.

## Provenance And Quality Review

The corpus predates modern generative-model workflows and the README describes
automatic PALAVRAS analysis followed by manual linguistic correction and UD
conversion. No evidence of model-generated newspaper text was found. This
does not cure the rights failure, and no claim is made about every later
annotation edit.

The three release files contain 9,357 sentences, 227,827 syntactic words,
18,085 unique lemmas, all 17 universal POS tags, and 58 feature-value
combinations. Exact sentence counts by source variant and split are:

| Split | PT-BR `CF` | PT-PT `CP` | PT-BR documents | PT-PT documents |
| --- | ---: | ---: | ---: | ---: |
| train | 3,163 | 3,855 | 745 | 730 |
| dev | 523 | 649 | 120 | 124 |
| test | 521 | 646 | 118 | 124 |

The 1,961 document groups do not cross the supplied train, development, and
test partitions. Eleven exact sentence-text comments are duplicated across the
release, so sentence identity still requires deduplication. The source is
news-domain, mixes Brazilian and European Portuguese, and supplies no Home
Assistant intent or typed-plan oracle. It could have been useful only for the
bounded POS and morphology purpose if its rights had been admissible.

## Decision And Removal

The candidate is rejected because authority to license the underlying
newspaper text for commercial modification and redistribution is unproven,
and the recorded noncommercial-to-commercial license change conflicts with
the origin evidence. Either defect is incompatible with the source policy.

No candidate byte influenced code, runtime behavior, vocabulary, rules,
training, fixtures, gold labels, or evaluation. The quarantine checkout and
all temporary official-page and license copies were deleted. A targeted
post-removal check found none of the named paths. Rejection occurred before
promotion, so no independent source-admission review is claimed.

Commands used: exact-commit Git fetch and detached checkout; bounded filtered
history fetch; `git rev-parse`, `git status`, `git log`, `git show`,
`git archive`, `find`, `grep`, `sed`, `awk`, `comm`, `wc`, SHA-256, and
bounded `curl` retrieval from the canonical official pages.
