# noctalia-nix

Flake que reúne, num só nixpkgs, os pacotes da família Noctalia usados no
[nix-config-noctalia](https://github.com/lbssousa/nix-config-noctalia), com os
patches de lbssousa já incluídos. O CI compila tudo e publica no Cachix
**lbssousa-noctalia**. Assim, quem consome o flake baixa os pacotes prontos.

| Pacote | Origem | Segue o upstream por |
|---|---|---|
| `noctalia` | [lbssousa/noctalia](https://github.com/lbssousa/noctalia), branch `nix-config` | releases (`v*`) |
| `noctalia-greeter` | [lbssousa/noctalia-greeter](https://github.com/lbssousa/noctalia-greeter), branch `nix-config` | releases (`v*`) |
| `umbriel`, `xdg-desktop-portal-umbriel` | [lbssousa/umbriel](https://github.com/lbssousa/umbriel), branch `nix-config` | `main` |
| `luciole` | [noctalia-dev/luciole](https://github.com/noctalia-dev/luciole) | `main` |
| `noctalia-secret-prompts` | [lbssousa/noctalia-secret-prompts](https://github.com/lbssousa/noctalia-secret-prompts) | `main` |

Os patches são commits nos branches `nix-config` dos forks, um por patch.
Antes de cada rebase, o estado anterior fica numa tag `nix-config-<base>`.

## Uso

```nix
inputs = {
  noctalia-nix.url = "github:lbssousa/noctalia-nix";
  # O mesmo nixpkgs do CI: as derivações batem com as do Cachix.
  nixpkgs.follows = "noctalia-nix/nixpkgs";
};
# ...
nixpkgs.overlays = [ inputs.noctalia-nix.overlays.default ];
```

O cache: `https://lbssousa-noctalia.cachix.org`, chave
`lbssousa-noctalia.cachix.org-1:pzuER80zi7qmrqjkVy/2sifDJogy+QR9F9z/p4CBjF4=`
(também em `nixConfig`).

## Atualização diária (`.github/workflows/daily.yml`)

1. **sync-forks** (`scripts/sync-fork.sh`): rebaseia o `nix-config` de cada
   fork sobre a release mais nova (ou o `main`) do upstream.
   - Com sucesso: guarda o estado anterior em `nix-config-<base>` e faz o push.
   - Com conflito: não toca no branch e abre uma issue aqui.
2. **update**: roda `nix flake update`, `nix build .#all` e `nix flake check`,
   enviando ao Cachix tudo o que compila.
   - Se tudo passar: commit do `flake.lock` e um `repository_dispatch`
     (`noctalia-nix-updated`) para o nix-config-noctalia.
   - Se algo falhar: o lock anterior continua valendo e abre-se uma issue.

O nixpkgs de quem segue este flake só avança para revisões já compiladas e
publicadas.

### Quando um rebase falha

```sh
git clone git@github.com:lbssousa/<fork>.git && cd <fork>
git remote add upstream https://github.com/noctalia-dev/<repo>.git
git fetch upstream --tags
git tag -a -m "estado anterior" nix-config-<base antiga> origin/nix-config
git rebase --onto <tag nova> <base antiga> nix-config   # resolver, um commit por patch
git push origin nix-config-<base antiga> && git push --force-with-lease origin nix-config
```

Depois, rode o workflow **daily** manualmente (Actions › daily › Run workflow).

## Segredos

- `CACHIX_AUTH_TOKEN`: token de escrita do Cachix lbssousa-noctalia.
- `FORKS_TOKEN`: PAT fine-grained com *Contents: read and write* em
  `lbssousa/noctalia`, `lbssousa/noctalia-greeter` e `lbssousa/umbriel` (push
  do rebase) e em `lbssousa/nix-config-noctalia` (o `repository_dispatch`).
