#!/usr/bin/env bash
# Source-only packaging. Never overwrites an existing delivery archive.
set -euo pipefail
cd "$(dirname "$0")"
source_zip="${1:-$(pwd)/../ASHWAKE_v0.6.0_Godot_Source.zip}"
if [[ "$source_zip" != /* || -e "$source_zip" ]]; then
  printf 'Choose a new absolute archive path; existing outputs are preserved.\n' >&2
  exit 1
fi
mapfile -d '' source_files < <(rg --files --hidden --no-ignore -g '!.godot/**' -g '!.git/**' -g '!tools/action_bake/review/**' -g '!SOURCE_MANIFEST.sha256' -0 | sort -z)
for file in "${source_files[@]}"; do
  case "$file" in
    *.apk|*.aab|*.jks|*.keystore|*.pem|*.key|*export_credentials.cfg|*.zip)
      printf 'Refusing unexpected build/private artifact: %s\n' "$file" >&2
      exit 1
      ;;
  esac
done
sha256sum "${source_files[@]}" > SOURCE_MANIFEST.sha256
zip -q -X -9 "$source_zip" "${source_files[@]}" SOURCE_MANIFEST.sha256
unzip -t "$source_zip"
sha256sum "$source_zip"
