#!/usr/bin/env bash
set -euo pipefail

docs=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
d2_dir=${D2_DIR:-$docs/pipeline}
params_sql=${PARAMS_SQL:-$docs/params.sql}
pipeline_md=${PIPELINE_MD:-$docs/pipeline.md}
params_md=${PARAMS_MD:-$docs/params.md}
ascii_mode=${D2_ASCII_MODE:-extended}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

{
  echo "# Pipeline outline"
  echo
  echo "\`--mode <name>\` selects the workflow. Sources: \`docs/pipeline/*.d2\`."
  for src in "$d2_dir"/*.d2; do
    base=$(basename "$src" .d2)
    d2 --ascii-mode "$ascii_mode" "$src" "$tmp/$base.txt" >/dev/null 2>"$tmp/$base.log" || {
      cat "$tmp/$base.log" >&2
      exit 1
    }
    printf '\n## %s\n\n```text\n' "${base#*-}"
    sed 's/[[:space:]]*$//' "$tmp/$base.txt"
    printf '```\n'
  done
} > "$tmp/pipeline.md"

{
  echo "# Run parameters"
  echo
  echo "Source: \`docs/params.sql\`. Set any param with \`--<param> <value>\`."
  echo
  sqlite3 :memory: ".read $params_sql" '.mode markdown --wrap 0' "
    SELECT
      grp AS \"group\",
      '\`' || param || '\`' AS param,
      CASE WHEN default_value = '' THEN '\"\"' ELSE '\`' || replace(default_value, '|', '\|') || '\`' END AS \"default\",
      modes,
      replace(replace(replace(description, '|', '\|'), '<', '&lt;'), '>', '&gt;') AS description
    FROM params
    ORDER BY rowid;"
} > "$tmp/params.md"

mv "$tmp/pipeline.md" "$pipeline_md"
mv "$tmp/params.md" "$params_md"
echo "[info] wrote $pipeline_md"
echo "[info] wrote $params_md"
