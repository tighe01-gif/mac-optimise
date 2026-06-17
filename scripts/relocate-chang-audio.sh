#!/usr/bin/env bash
# Search Mac for Mr Chang / Chang Man audio and move to iCloud Main DL.
#
# Usage:
#   ./scripts/relocate-chang-audio.sh              # dry-run (default)
#   ./scripts/relocate-chang-audio.sh --apply      # move files
#   ./scripts/relocate-chang-audio.sh --apply --subdir "Mr Chang"
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

APPLY=0
LOOSE=0
SUBDIR="${AUDIO_RELOCATE_SUBDIR:-Chang}"
DEST="${ICLOUD_MAIN_DL:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads/Main Music DL Library}"
LIBRARY_ROOT="${DEST%/*}"
LIBRARY_ROOT="${LIBRARY_ROOT%/Main Music DL Library}"
LIBRARY_ROOT="${LIBRARY_ROOT}/Downloads/Main Music DL Library"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --dry-run) APPLY=0; shift ;;
    --loose) LOOSE=1; shift ;;
    --subdir) SUBDIR="${2:?}"; shift 2 ;;
    --dest) DEST="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      echo "  --loose    also match bare 'chang'/'man' (not recommended)"
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

# Strict: Mr Chang, Chang Man, Chang_Times playlist — not "Changes", "Same Man", "MANTRA".
matches_chang_target() {
  local name="$1"
  local norm
  norm="$(printf '%s' "$name" | normalize_for_match)"

  [[ "$norm" == *"chang times"* || "$norm" == changtimes ]] && return 0
  [[ "$norm" == *"mr chang"* ]] && return 0
  [[ "$norm" == *"aka mr chang"* ]] && return 0
  [[ "$norm" == *"mda aka mr chang"* ]] && return 0
  [[ "$norm" == *"chang man"* ]] && return 0
  [[ "$norm" == *changman* ]] && return 0

  if [[ "$LOOSE" -eq 1 ]]; then
    [[ "$norm" == *chang* ]] && return 0
  fi
  return 1
}

file_matches() {
  local f="$1"
  local base parent
  base="$(basename "$f")"
  parent="$(basename "$(dirname "$f")")"
  matches_chang_target "$base" || matches_chang_target "$parent"
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
  file_matches "$f" || return 0
  if ((${#FOUND[@]} > 0)); then
    local existing
    for existing in "${FOUND[@]}"; do
      [[ "$existing" == "$f" ]] && return 0
    done
  fi
  FOUND+=("$f")
}

ICLOUD="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"

# Targeted Spotlight (not bare *chang* / *man*)
if command -v mdfind &>/dev/null; then
  for query in \
    'kMDItemFSName == "*Mr*Chang*"cd' \
    'kMDItemFSName == "*Chang_Man*"cd' \
    'kMDItemFSName == "*Chang Man*"cd' \
    'kMDItemFSName == "*Chang_Times*"cd' \
    'kMDItemFSName == "*MDA*Chang*"cd'; do
    while IFS= read -r hit; do
      add_candidate "$hit"
    done < <(mdfind -onlyin "$HOME" "$query" 2>/dev/null || true)
  done
fi

SEARCH_ROOTS=(
  "$HOME/Downloads/Chang_Times"
  "$HOME/Downloads"
  "$HOME/DJ_INBOX"
  "$HOME/Music"
  "$HOME/Desktop"
  "${ICLOUD}/DJ_LIBRARY/Exports/Mr Chang"
  "${ICLOUD}/DJ_LIBRARY/Exports"
  "${ICLOUD}/Downloads/Main Music DL Library"
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
echo "Match mode: $([[ "$LOOSE" -eq 1 ]] && echo loose || echo strict — Mr Chang / Chang Man / Chang_Times)"
[[ "$APPLY" -eq 0 ]] && yellow "DRY RUN — pass --apply to move files"
echo ""

if [[ ${#FOUND[@]} -eq 0 ]]; then
  yellow "No matching audio files found."
  exit 0
fi

{
  echo "# relocate-chang-audio $(timestamp)"
  echo "# dest=${DEST} apply=${APPLY} loose=${LOOSE}"
} > "$MANIFEST"

moved=0
skipped=0

for src in "${FOUND[@]}"; do
  name="$(basename "$src")"
  target="$(unique_dest "$DEST" "$name")"
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
