#!/usr/bin/env bash
# Find audio stored outside iCloud (thin client: no local music hoarding).
#
# Authorized (left alone): iCloud Drive — Main Music DL Library + DJ_LIBRARY.
# Everything else under ~/ that matches audio extensions is "local".
#
# Usage:
#   ./scripts/local-audio-to-icloud.sh           # audit only
#   ./scripts/local-audio-to-icloud.sh --apply   # move → Main DL/_local-import/YYYY-MM-DD/
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --dry-run) APPLY=0; shift ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *) red "Unknown option: $1"; exit 1 ;;
  esac
done

ICLOUD="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
LIBRARY="${ICLOUD_MAIN_DL:-${ICLOUD}/Downloads/Main Music DL Library}"
DJ_LIB="${ICLOUD}/DJ_LIBRARY"
IMPORT_SUBDIR="_local-import/$(date -u +%Y-%m-%d)"
DEST="${LIBRARY}/${IMPORT_SUBDIR}"

AUDIO_EXTS="mp3 m4a m4p flac wav aiff aif ogg opus wma aac"

mkdir -p "${ROOT}/output/local-audio"
MANIFEST="${ROOT}/output/local-audio/$(date_slug).txt"

is_audio() {
  local ext="${1##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  [[ " ${AUDIO_EXTS} " == *" ${ext} "* ]]
}

# iCloud-authoritative paths — thin client keeps audio here only.
is_authorized_path() {
  local p="$1"
  [[ "$p" == "${LIBRARY}"* ]] && return 0
  [[ "$p" == "${DJ_LIB}"* ]] && return 0
  return 1
}

should_skip_path() {
  local p="$1"
  is_authorized_path "$p" && return 0
  [[ "$p" == *"/node_modules/"* ]] && return 0
  [[ "$p" == *"/.git/"* ]] && return 0
  [[ "$p" == *"/.Trash/"* ]] && return 0
  [[ "$p" == *"/Library/Caches/"* ]] && return 0
  [[ "$p" == *"/Library/Application Support/"* ]] && return 0
  [[ "$p" == *"/Music/Music Library"* ]] && return 0
  [[ "$p" == *"/Applications/"* ]] && return 0
  return 1
}

unique_dest() {
  local base="$1" name="$2" target="${base}/${name}"
  if [[ ! -e "$target" ]]; then printf '%s\n' "$target"; return; fi
  local stem ext n=1
  if [[ "$name" == *.* ]]; then stem="${name%.*}"; ext=".${name##*.}"; else stem="$name"; ext=""; fi
  while [[ -e "${base}/${stem} (${n})${ext}" ]]; do n=$((n + 1)); done
  printf '%s\n' "${base}/${stem} (${n})${ext}"
}

declare -a FOUND=()
TOTAL_MB=0

add_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  should_skip_path "$f" && return 0
  is_audio "$f" || return 0
  if ((${#FOUND[@]} > 0)); then
    local existing
    for existing in "${FOUND[@]}"; do [[ "$existing" == "$f" ]] && return 0; done
  fi
  FOUND+=("$f")
  TOTAL_MB=$((TOTAL_MB + $(dir_size_mb "$f")))
}

find_args=()
for ext in $AUDIO_EXTS; do find_args+=( -iname "*.${ext}" -o ); done
unset 'find_args[${#find_args[@]}-1]'

SCAN_ROOTS=(
  "$HOME/Downloads"
  "$HOME/Desktop"
  "$HOME/Documents"
  "$HOME/DJ_INBOX"
  "$HOME/Music"
  "${HOME}/Library/CloudStorage"
)

echo "=== Local audio audit (thin client) ==="
echo "Authorized (untouched):"
echo "  ${LIBRARY}"
echo "  ${DJ_LIB}"
echo "Import target: ${DEST}"
[[ "$APPLY" -eq 0 ]] && yellow "AUDIT ONLY — pass --apply to move files to iCloud"
echo ""

for root in "${SCAN_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r f; do add_file "$f"; done < <(
    find "$root" -type f \( "${find_args[@]}" \) 2>/dev/null || true
  )
done

{
  echo "# local-audio-to-icloud $(timestamp)"
  echo "# apply=${APPLY} dest=${DEST}"
} > "$MANIFEST"

if [[ ${#FOUND[@]} -eq 0 ]]; then
  green "No local audio outside iCloud. Thin client OK."
  echo "Manifest: ${MANIFEST}"
  exit 0
fi

yellow "Found ${#FOUND[@]} local audio file(s) (~${TOTAL_MB} MB)"
echo ""

moved=0
failed=0

for src in "${FOUND[@]}"; do
  name="$(basename "$src")"
  if [[ "$APPLY" -eq 1 ]]; then
    target="$(unique_dest "$DEST" "$name")"
    mkdir -p "$DEST"
    echo "${src} → ${target}" | tee -a "$MANIFEST"
    if mv "$src" "$target"; then
      green "  moved"
      moved=$((moved + 1))
    else
      red "  FAILED"
      failed=$((failed + 1))
    fi
  else
    echo "${src}" | tee -a "$MANIFEST"
  fi
done

echo ""
if [[ "$APPLY" -eq 0 ]]; then
  yellow "Re-run with --apply to move all to iCloud."
else
  echo "Moved: ${moved}  Failed: ${failed}"
fi
echo "Manifest: ${MANIFEST}"
echo "=== done ==="

[[ "$APPLY" -eq 0 && ${#FOUND[@]} -gt 0 ]] && exit 2
