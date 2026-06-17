#!/usr/bin/env bash
# Search Mac for audio matching Chang / Chang Man (etc.) and move to iCloud Main DL.
#
# Usage:
#   ./scripts/relocate-chang-audio.sh              # dry-run (default)
#   ./scripts/relocate-chang-audio.sh --apply      # move files
#   ./scripts/relocate-chang-audio.sh --apply --subdir "Chang Man"
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

APPLY=0
SUBDIR="${AUDIO_RELOCATE_SUBDIR:-Chang}"
TERMS="${AUDIO_RELOCATE_TERMS:-chang changman chang-man chang_man}"
DEST="${ICLOUD_MAIN_DL:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads/Main Music DL Library}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --dry-run) APPLY=0; shift ;;
    --subdir) SUBDIR="${2:?}"; shift 2 ;;
    --dest) DEST="${2:?}"; shift 2 ;;
    --terms) TERMS="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *) red "Unknown option: $1"; exit 1 ;;
  esac
done

DEST="${DEST%/}/${SUBDIR}"
mkdir -p "${ROOT}/output/relocate"
MANIFEST="${ROOT}/output/relocate/$(date_slug)-chang-audio.txt"

AUDIO_EXTS="mp3 m4a m4p flac wav aiff aif ogg opus wma"

should_skip_path() {
  local p="$1"
  [[ "$p" == "$DEST"* ]] && return 0
  [[ "$p" == *"/node_modules/"* ]] && return 0
  [[ "$p" == *"/.git/"* ]] && return 0
  [[ "$p" == *"/Library/Application Support/Cursor/"* ]] && return 0
  [[ "$p" == *"/Library/Caches/"* ]] && return 0
  [[ "$p" == *"/.Trash/"* ]] && return 0
  return 1
}

is_audio_file() {
  local f="$1"
  local ext="${f##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  [[ " ${AUDIO_EXTS} " == *" ${ext} "* ]]
}

normalize_for_match() {
  tr '[:upper:]' '[:lower:]' | tr '_-' '  ' | tr -s ' '
}

matches_terms() {
  local hay="$1"
  local norm
  norm="$(printf '%s' "$hay" | normalize_for_match)"
  for term in $TERMS; do
    local t
    t="$(printf '%s' "$term" | normalize_for_match)"
    [[ -n "$t" && "$norm" == *"$t"* ]] && return 0
  done
  return 1
}

unique_dest() {
  local base="$1"
  local name="$2"
  local target="${base}/${name}"
  if [[ ! -e "$target" ]]; then
    printf '%s\n' "$target"
    return
  fi
  local stem ext n=1
  if [[ "$name" == *.* ]]; then
    stem="${name%.*}"
    ext=".${name##*.}"
  else
    stem="$name"
    ext=""
  fi
  while [[ -e "${base}/${stem} (${n})${ext}" ]]; do
    n=$((n + 1))
  done
  printf '%s\n' "${base}/${stem} (${n})${ext}"
}

declare -a FOUND=()

add_candidate() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  should_skip_path "$f" && return 0
  is_audio_file "$f" || return 0
  matches_terms "$(basename "$f")" || matches_terms "$(dirname "$f")" || return 0
  local existing
  for existing in "${FOUND[@]}"; do
    [[ "$existing" == "$f" ]] && return 0
  done
  FOUND+=("$f")
}

# Spotlight (fast, whole home)
if command -v mdfind &>/dev/null; then
  while IFS= read -r term; do
    [[ -z "$term" ]] && continue
    while IFS= read -r hit; do
      add_candidate "$hit"
    done < <(mdfind -onlyin "$HOME" "kMDItemFSName == '*${term}*'cd" 2>/dev/null || true)
  done <<< "$(printf '%s\n' $TERMS)"
fi

# Explicit folders (catches unindexed files)
SEARCH_ROOTS=(
  "$HOME/Downloads"
  "$HOME/Desktop"
  "$HOME/Documents"
  "$HOME/Music"
  "$HOME/Movies"
  "$HOME/Pulse Loop"
  "$HOME/Pulse-Sync"
  "$HOME/DJ_Set_App"
)

find_args=()
for ext in $AUDIO_EXTS; do
  find_args+=( -iname "*.${ext}" -o )
done
unset 'find_args[${#find_args[@]}-1]'

for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r f; do
    add_candidate "$f"
  done < <(find "$root" -type f \( "${find_args[@]}" \) 2>/dev/null || true)
done

echo "=== Relocate Chang audio → iCloud Main DL ==="
echo "Destination: ${DEST}"
echo "Search terms: ${TERMS}"
[[ "$APPLY" -eq 0 ]] && yellow "DRY RUN — pass --apply to move files"
echo ""

if [[ ${#FOUND[@]} -eq 0 ]]; then
  yellow "No matching audio files found."
  exit 0
fi

{
  echo "# relocate-chang-audio $(timestamp)"
  echo "# dest=${DEST} apply=${APPLY}"
} > "$MANIFEST"

moved=0
skipped=0

for src in "${FOUND[@]}"; do
  name="$(basename "$src")"
  target="$(unique_dest "$DEST" "$name")"
  rel_target="${target#"$HOME"/}"
  echo "${src} → ${target}" | tee -a "$MANIFEST"
  if [[ "$APPLY" -eq 1 ]]; then
    mkdir -p "$DEST"
    if mv "$src" "$target"; then
      green "  moved"
      moved=$((moved + 1))
    else
      red "  FAILED"
      skipped=$((skipped + 1))
    fi
  fi
done

echo ""
echo "Found: ${#FOUND[@]} file(s)"
[[ "$APPLY" -eq 1 ]] && echo "Moved: ${moved}  Failed: ${skipped}"
echo "Manifest: ${MANIFEST}"
[[ "$APPLY" -eq 0 ]] && yellow "Re-run with --apply to move."
echo "=== done ==="
