#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=$here/out
builder=rnaseq/guix-builder
uid=$(id -u)
gid=$(id -g)

tools=("$@")
if [[ ${#tools[@]} -eq 0 ]]; then
  tools=(fastqc fastp multiqc star)
fi

mkdir -p "$out"
docker build -t "$builder" "$here/guix"

run() {
  docker run --rm \
    --security-opt seccomp=unconfined \
    -v rnaseq-guix-gnu:/gnu \
    -v rnaseq-guix-var:/var/guix \
    -v rnaseq-guix-cache:/root/.cache/guix \
    -v rnaseq-guix-log:/var/log/guix \
    -v "$here":/src \
    -w /src \
    "$builder" "$@"
}

guix() {
  run guix time-machine -C /src/channels.scm -- "$@"
}

export_store_file() {
  local store_path=$1 dest=$2
  run sh -c "cp --no-preserve=mode,ownership '$store_path' '/src/out/$dest' && chown $uid:$gid '/src/out/$dest'"
}

docker_cfg=$here/docker.config
singularity_cfg=$here/singularity.config

for tool in "${tools[@]}"; do
  version=$(guix package -L /src/packages --show="$tool" | awk '$1 == "version:" && !v { v = $2 } END { print v }')
  echo "[info] $tool $version"

  symlinks=(-S /bin=bin)
  if grep -q '"font-' "$here/manifests/$tool.scm"; then
    symlinks+=(-S /run/current-system/profile/share/fonts=share/fonts)
  fi

  tarball=$(guix pack -L /src/packages -f docker "${symlinks[@]}" -m "/src/manifests/$tool.scm" | tail -n 1)
  export_store_file "$tarball" "$tool-$version.docker.tar.gz"

  squashfs=$(guix pack -L /src/packages -f squashfs "${symlinks[@]}" -m "/src/manifests/$tool.scm" | tail -n 1)
  export_store_file "$squashfs" "$tool-$version.squashfs"

  loaded=$(docker load -i "$out/$tool-$version.docker.tar.gz" | awk '/Loaded image/ { print $NF }')
  docker tag "$loaded" "rnaseq/$tool:$version"
  if [[ $loaded != "rnaseq/$tool:$version" ]]; then
    docker rmi "$loaded" >/dev/null 2>&1 || true
  fi

  echo "[info] $version" > "$out/$tool.version"
done

{
  echo "process {"
  for f in "$out"/*.version; do
    tool=$(basename "$f" .version)
    version=$(<"$f")
    printf "    withName: '.*%s.*' { container = 'rnaseq/%s:%s' }\n" "${tool^^}" "$tool" "$version"
  done
  echo "}"
} > "$docker_cfg"

echo "[info] wrote $docker_cfg"

{
  echo "process {"
  for f in "$out"/*.version; do
    tool=$(basename "$f" .version)
    version=$(<"$f")
    printf "    withName: '.*%s.*' { container = \"\${projectDir}/containers/out/%s-%s.squashfs\" }\n" "${tool^^}" "$tool" "$version"
  done
  echo "}"
} > "$singularity_cfg"

echo "[info] wrote $singularity_cfg"
