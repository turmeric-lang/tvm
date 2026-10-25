#!/bin/sh
# install.sh -- bootstrap the Turmeric Version Manager (tvm).
#
# Installs tvm into $TVM_DIR (default ~/.tvm) and wires it into your shell
# rc. After installation, open a new shell (or `source` your rc) and run
# `tvm help`.
#
# Usage:
#   sh install.sh                # install from this checkout
#   TVM_DIR=~/.turmeric-vm sh install.sh
#
# Modeled after the nvm / rustup installer scripts.

set -eu

TVM_DIR="${TVM_DIR:-$HOME/.tvm}"

# Locate the directory holding this script (so we can copy tvm.sh + libexec).
SRC_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

echo "tvm: installing into $TVM_DIR"
mkdir -p "$TVM_DIR" "$TVM_DIR/versions" "$TVM_DIR/aliases" "$TVM_DIR/cache/downloads"

cp "$SRC_DIR/tvm.sh" "$TVM_DIR/tvm.sh"
if [ -d "$SRC_DIR/libexec" ]; then
  cp -R "$SRC_DIR/libexec" "$TVM_DIR/"
fi

# Decide which rc file to wire up.
#
# bash reads different files per platform, and creating the wrong one breaks
# the user's existing setup:
#   - Linux terminals open interactive non-login shells, which read only
#     ~/.bashrc (distro login profiles source it too). Creating it if missing
#     shadows nothing.
#   - macOS Terminal opens login shells, which read the FIRST of
#     ~/.bash_profile, ~/.bash_login, ~/.profile and never ~/.bashrc. Use the
#     first that exists; creating ~/.bash_profile while ~/.profile exists would
#     stop bash reading ~/.profile at all.
detect_rc() {
  if [ -n "${ZSH_VERSION-}" ] || [ "${SHELL##*/}" = "zsh" ]; then
    echo "$HOME/.zshrc"
  elif [ -n "${BASH_VERSION-}" ] || [ "${SHELL##*/}" = "bash" ]; then
    case "$(uname -s)" in
      Darwin)
        for f in .bash_profile .bash_login .profile; do
          if [ -f "$HOME/$f" ]; then echo "$HOME/$f"; return; fi
        done
        echo "$HOME/.bash_profile"
        ;;
      *) echo "$HOME/.bashrc" ;;
    esac
  else
    echo "$HOME/.profile"
  fi
}

RC="$(detect_rc)"
RC_EXISTED=0
[ -f "$RC" ] && RC_EXISTED=1
SNIPPET_MARKER="# >>> tvm initialize >>>"

if [ -f "$RC" ] && grep -qF "$SNIPPET_MARKER" "$RC"; then
  echo "tvm: $RC already configured; leaving it untouched"
else
  {
    echo ""
    echo "$SNIPPET_MARKER"
    echo "export TVM_DIR=\"$TVM_DIR\""
    echo "[ -s \"\$TVM_DIR/tvm.sh\" ] && . \"\$TVM_DIR/tvm.sh\""
    echo "# <<< tvm initialize <<<"
  } >> "$RC"
  if [ "$RC_EXISTED" -eq 1 ]; then
    echo "tvm: added init snippet to $RC"
  else
    echo "tvm: created $RC with the init snippet"
  fi
fi

cat <<EOF

tvm installed.

  Open a new shell, or run:
      export TVM_DIR="$TVM_DIR"
      . "$TVM_DIR/tvm.sh"

  Then:
      tvm ls-remote                      # list the released versions
      tvm install --activate <version>   # install one and make it the default
      tur --version

EOF
