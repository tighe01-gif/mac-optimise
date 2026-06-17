#!/usr/bin/env bash
# Search Mac for Mr Chang / Chang Man audio and move to iCloud Main DL.
#
# Default: artist exports only (Mr Chang, MDA AKA Mr Chang) — NOT "Changes", MANTRA, Same Man.
# Chang_Times playlist is opt-in (classic house folder, not the artist).
#
# Usage:
#   ./scripts/relocate-chang-audio.sh                    # dry-run, artist only
#   ./scripts/relocate-chang-audio.sh --apply            # move files
#   ./scripts/relocate-chang-audio.sh --include-chang-times   # + ~/Downloads/Chang_Times
#   ./scripts/relocate-chang-audio.sh --apply --subdir "Mr Chang"
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

APPLY=0
INCLUDE_CHANG_TIMES=0
SUBDIR="${AUDIO_RELOCATE_SUBDIR:-Chang}"
ICLOUD="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
LIBRARY="${ICLOUD}/Downloads/Main Music DL Library"
DEST="${ICLOUD_MAIN_DL:-$LIBRARY}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --dry-run) APPLY=0; shift ;;
    --include-chang-times) INCLUDE_CHANG_TIMES=1; shift ;;
    --subdir) SUBDIR="${2:?}"; shift 2 ;;
    --dest) DEST="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      echo "  --include-chang-times   also move ~/Downloads/Chang_Times playlist"
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
  [[ "$p" == "${LIBRARY}/"* ]] && return 0
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

# Mr Chang / MDA AKA Mr Chang — filename or exact parent folder only.
matches_mr_chang_artist() {
  local base="$1"
  local parent="$2"
  local norm_base norm_parent
  norm_base="$(printf '%s' "$base" | normalize_for_match)"
  norm_parent="$(printf '%s' "$parent" | normalize_for_match)"

  if [[ "$norm_parent" == "mr chang" || "$norm_parent" == "chang man" ]]; then
    return 0
  fi

  [[ "$norm_base" == *"mr chang"* ]] && return 0
  [[ "$norm_base" == *"aka mr chang"* ]] && return 0
  [[ "$norm_base" == *"mda aka mr chang"* ]] && return 0
  [[ "$norm_base" == *"chang man"* && "$norm_base" != *"same man"* ]] && return 0

  return 1
}

in_chang_times_path() {
  local p="$1"
  [[ "$p" == *"/Chang_Times/"* || "$p" == *"/Chang_Times" ]]
}

file_matches() {
  local f="$1"
  local base parent
  base="$(basename "$f")"
  parent="$(basename "$(dirname "$f")")"

  if [[ "$INCLUDE_CHANG_TIMES" -eq 1 ]] && in_chang_times_path "$f"; then
    return 0
  fi
  matches_mr_chang_artist "$base" "$parent"
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
ARTIST_N=0
TIMES_N=0

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
  if in_chang_times_path "$f"; then
    TIMES_N=$((TIMES_N + 1))
  else
    ARTIST_N=$((ARTIST_N + 1))
  fi
}

# Targeted paths only — no whole ~/Music or Main Music DL Library scan.
SEARCH_ROOTS=(
  "${ICLOUD}/DJ_LIBRARY/Exports/Mr Chang"
  "$HOME/Downloads"
  "$HOME/DJ_INBOX"
  "$HOME/Desktop"
  "$HOME/Music/Music/Media.localized"
)
[[ "$INCLUDE_CHANG_TIMES" -eq 1 ]] && SEARCH_ROOTS=("$HOME/Downloads/Chang_Times" "${SEARCH_ROOTS[@]}")

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

if command -v mdfind &>/dev/null; then
  for query in \
    'kMDItemFSName == "*Mr*Chang*"cd' \
    'kMDItemFSName == "*MDA*Mr*Chang*"cd'; do
    while IFS= read -r hit; do
      add_candidate "$hit"
    done < <(mdfind -onlyin "$HOME" "$query" 2>/dev/null || true)
  done
fi

echo "=== Relocate Chang audio → iCloud Main DL ==="
echo "Destination: ${DEST}"
echo "Mode: artist only (Mr Chang / Chang Man exports)"
[[ "$INCLUDE_CHANG_TIMES" -eq 1 ]] && echo "      + Chang_Times playlist folder"
echo "Skipping: files already under Main Music DL Library"
[[ "$APPLY" -eq 0 ]] && yellow "DRY RUN — pass --apply to move files"
echo ""

if [[ ${#FOUND[@]} -eq 0 ]]; then
  yellow "No matching audio files found."
  exit 0
fi

{
  echo "# relocate-chang-audio $(timestamp)"
  echo "# dest=${DEST} apply=${APPLY} include_chang_times=${INCLUDE_CHANG_TIMES}"
  echo "# artist=${ARTIST_N} chang_times=${TIMES_N}"
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
echo "Found: ${#FOUND[@]} file(s) — artist: ${ARTIST_N}, Chang_Times: ${TIMES_N}"
[[ "$APPLY" -eq 1 ]] && echo "Moved: ${moved}  Failed: ${skipped}"
echo "Manifest: ${MANIFEST}"
[[ "$APPLY" -eq 0 ]] && yellow "Re-run with --apply to move."
echo "=== done ==="
