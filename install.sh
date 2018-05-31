#!/usr/bin/env bash
# derived from install script in https://github.com/sstephenson/bats
set -e

resolve_link() {
  $(type -p greadlink readlink | head -1) "$1"
}

abs_dirname() {
  local cwd="$(pwd)"
  local path="$1"

  while [ -n "$path" ]; do
    cd "${path%/*}"
    local name="${path##*/}"
    path="$(resolve_link "$name" || true)"
  done

  pwd
  cd "$cwd"
}

PREFIX="$1"
if [ -z "$1" ]; then
  { echo "usage: $0 <prefix>"
    echo "  e.g. $0 /usr/local"
  } >&2
  exit 1
fi

SEM_ROOT="$(abs_dirname "$0")"
mkdir -p "$PREFIX"/{bin,src}
cp -R "$SEM_ROOT"/bin/* "$PREFIX"/bin
cp -R "$SEM_ROOT"/lib/* "$PREFIX"/src

eval "./util/update-library-path.rb $PREFIX/bin/sem-add ${PREFIX}/src/schema-evolution-manager.rb"
eval "./util/update-library-path.rb $PREFIX/bin/sem-apply ${PREFIX}/src/schema-evolution-manager.rb"
eval "./util/update-library-path.rb $PREFIX/bin/sem-baseline ${PREFIX}/src/schema-evolution-manager.rb"
eval "./util/update-library-path.rb $PREFIX/bin/sem-dist ${PREFIX}/src/schema-evolution-manager.rb"
eval "./util/update-library-path.rb $PREFIX/bin/sem-info ${PREFIX}/src/schema-evolution-manager.rb"
eval "./util/update-library-path.rb $PREFIX/bin/sem-init ${PREFIX}/src/schema-evolution-manager.rb"

rm "$PREFIX/bin/sem-config"

echo "Installed schema-evolution-manager scripts to $PREFIX/bin"

