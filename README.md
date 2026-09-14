# dotfiles

Cross-platform dotfiles for macOS and Linux, built to be consumed by
[Coder](https://coder.com) dev boxes via `coder dotfiles`.

## Coder

Set this repo in your Coder user settings (**Account → Dotfiles**), or run:

```bash
coder dotfiles git@github.com:billyvg/dotfiles.git
```

Coder clones to `~/.config/coderv2/dotfiles`, finds `install.sh`, and runs it.

## Manual install

```bash
git clone git@github.com:billyvg/dotfiles.git ~/.dotfiles-src
~/.dotfiles-src/install.sh
```

```
./install.sh                 # full install: packages + links + post-install
./install.sh --no-packages   # links + post-install, skip apt/brew
./install.sh --links-only    # just re-link configs (fast)
```

`install.sh` is idempotent. Anything it would overwrite is moved to
`<file>.bak` first, so re-running is safe.

**Package failures never block config linking.** If apt or Homebrew fails — no
network, a proxy, no sudo, an unsupported arch — you get a warning and the run
continues, so you always end up with your shell config even on a box where the
package install couldn't complete. Re-run `install.sh` once the cause is fixed.

## Layout

```
install.sh            # entrypoint (Coder runs this)
lib/os.sh             # OS detection, logging, symlink helper
lib/packages.sh       # apt + homebrew installation
apt-packages.txt      # Linux base packages
Brewfile              # shared CLI tools (both platforms)
Brewfile.darwin       # macOS-only: casks, mas, formulae
Brewfile.linux        # Linux-only formulae
home/                 # symlinked into $HOME
config/               # symlinked into $XDG_CONFIG_HOME (~/.config)
macos/defaults.sh     # macOS system preferences (run manually)
```

## How the OS split works

Shared configs are one file. Anything platform-specific lives in a `.darwin` /
`.linux` sibling, which `install.sh` symlinks to a stable `.os` name:

| Shared | Fragment | Linked as |
|---|---|---|
| `home/.zshrc` | `.zshrc.darwin` / `.zshrc.linux` | `~/.zshrc.os` |
| `home/.gitconfig` | `.gitconfig.darwin` / `.gitconfig.linux` | `~/.gitconfig.os` |

`.tmux.conf` does its own detection with `if-shell "uname | grep -q Darwin"`
and sources `~/.tmux-macos.conf` or `~/.tmux-linux.conf`.

Load order for zsh is: **shared → `.os` → `.local`**. Later wins.

## Machine-specific config and secrets

Two untracked files, created empty by `install.sh`:

- `~/.zshrc.local` — per-machine env, PATH entries, secrets
- `~/.gitconfig.local` — work email, signing keys

Never commit these. On a Coder workspace, prefer injecting secrets as
environment variables from the template and reading them here.

## Homebrew

Installed on both platforms. On Linux the shared `Brewfile` is deliberately
**small**: linuxbrew often misses bottles and falls back to compiling from
source, which can cost 10–30 minutes on a cold workspace. Anything apt ships at
an acceptable version belongs in `apt-packages.txt` instead.

If `install.sh` can't `sudo`, it installs Homebrew into `~/.linuxbrew` rather
than failing.

To skip the brew install entirely on a workspace, bake it into the Coder
template image — `install.sh` detects an existing `brew` and just runs
`brew bundle`.

## Neovim

Requires **neovim ≥ 0.12** (the config uses `vim.pack`). `install.sh` checks the
version and skips the plugin sync with a warning if it's too old — this is why
neovim comes from brew rather than apt.

First sync compiles tree-sitter parsers and builds `blink.cmp` with cargo, so
it is slow once and fast after.

## Adding a new config

- Goes in `$HOME`? Drop it in `home/`.
- Goes in `~/.config/foo`? Drop the directory in `config/foo`.

Either way it gets picked up automatically on the next `install.sh` — there is
no manifest to update.
