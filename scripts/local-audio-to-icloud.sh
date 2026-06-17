#!/usr/bin/env bash
# Move recent local audio downloads into iCloud (thin client).
#
# Default: audio modified in the last 5 days under Downloads/Desktop/Documents/DJ_INBOX.
# DJ apps (rekordbox, DJ.Studio, MIXO, Mixed In Key) are never touched.
#
# Usage:
#   ./scripts/local-audio-to-icloud.sh              # audit recent downloads
#   ./scripts/local-audio-to-icloud.sh --apply      # move → Main DL/_local-import/YYYY-MM-DD/
#   ./scripts/local-audio-to-icloud.sh --days 7     # custom window
#   ./scripts/local-audio-to-icloud.sh --all        # full scan (slow — entire Music/CloudStorage)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

APPLY=0
FULL_SCAN=0
DAYS="${AUDIO_RECENT_DAYS:-5}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --dry-run) APPLY=0; shift ;;
    --days)
      [[ $# -ge 2 ]] || { red "--days requires a number"; exit 1; }
      DAYS="$2"
      shift 2
      ;;
    --all) FULL_SCAN=1; DAYS=0; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    \#*) shift ;; # pasted comment token (e.g. from copied instructions)
    # prose from copied multi-line instructions (zsh sometimes passes these as args)
    quick|audit|move|only|these|recent|tracks|should|finish|seconds|local|audio|downloads|days)
      shift ;;
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
LATEST="${ROOT}/output/local-audio/latest.txt"

is_audio() {
  local ext="${1##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  [[ " ${AUDIO_EXTS} " == *" ${ext} "* ]]
}

# iCloud-authoritative paths — thin client keeps audio here only.
is_authorized_path() {
  local p="$1"
  case "$p" in
    "${LIBRARY}"*) return 0 ;;
    "${DJ_LIB}"*) return 0 ;;
    *"/com~apple~CloudDocs/Downloads/Main Music DL Library"*) return 0 ;;
    *"/com~apple~CloudDocs/DJ_LIBRARY"*) return 0 ;;
  esac
  return 1
}

should_skip_path() {
  local p="$1"
  is_authorized_path "$p" && return 0
  is_dj_protected_path "$p" && return 0
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
  local dest_dir="${1-}" filename="${2-}"
  [[ -n "$dest_dir" && -n "$filename" ]] || return 1
  local target="${dest_dir}/${filename}"
  if [[ ! -e "$target" ]]; then printf '%s\n' "$target"; return 0; fi
  local stem ext n=1
  if [[ "$filename" == *.* ]]; then
    stem="${filename%.*}"
    ext=".${filename##*.}"
  else
    stem="$filename"
    ext=""
  fi
  while [[ -e "${dest_dir}/${stem} (${n})${ext}" ]]; do n=$((n + 1)); done
  printf '%s\n' "${dest_dir}/${stem} (${n})${ext}"
}

declare -a FOUND=()
TOTAL_MB=0

add_file() {
  local f="$1"
  [[ -n "$f" && -f "$f" ]] || return 0
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

if [[ "$FULL_SCAN" -eq 1 ]]; then
  SCAN_ROOTS=(
    "$HOME/Downloads"
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/DJ_INBOX"
    "$HOME/Music"
    "${HOME}/Library/CloudStorage"
  )
else
  SCAN_ROOTS=(
    "$HOME/Downloads"
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/DJ_INBOX"
  )
fi

if [[ "$FULL_SCAN" -eq 1 ]]; then
  echo "=== Full local audio audit (thin client) ==="
else
  echo "=== Recent local audio → iCloud (last ${DAYS} days) ==="
fi
echo "Authorized (untouched):"
echo "  ${LIBRARY}"
echo "  ${DJ_LIB}"
echo "DJ protected (rekordbox, DJ.Studio, MIXO, Mixed In Key): skipped"
echo "Import target: ${DEST}"
[[ "$APPLY" -eq 0 ]] && yellow "AUDIT ONLY — pass --apply to move files to iCloud"
echo ""

for root in "${SCAN_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  if [[ "$DAYS" -gt 0 ]]; then
    while IFS= read -r f; do add_file "$f"; done < <(
      find "$root" -type f -mtime "-${DAYS}" \( "${find_args[@]}" \) 2>/dev/null || true
    )
  else
    while IFS= read -r f; do add_file "$f"; done < <(
      find "$root" -type f \( "${find_args[@]}" \) 2>/dev/null || true
    )
  fi
done

{
  echo "# local-audio-to-icloud $(timestamp)"
  echo "# apply=${APPLY} days=${DAYS} full_scan=${FULL_SCAN} dest=${DEST}"
} > "$MANIFEST"

if [[ ${#FOUND[@]} -eq 0 ]]; then
  if [[ "$FULL_SCAN" -eq 1 ]]; then
    green "No local audio outside iCloud. Thin client OK."
  else
    green "No recent local audio (last ${DAYS} days). Thin client OK."
  fi
  cp "$MANIFEST" "$LATEST"
  echo "Manifest: ${MANIFEST}"
  exit 0
fi

yellow "Found ${#FOUND[@]} local audio file(s) (~${TOTAL_MB} MB)"
echo ""
echo "By location:"
for root in "${SCAN_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  n=0
  for f in "${FOUND[@]}"; do [[ "$f" == "${root}"* ]] && n=$((n + 1)); done
  [[ "$n" -gt 0 ]] && echo "  ${n}  ${root}"
done
echo ""

moved=0
failed=0
shown=0
max_show=25

for src in "${FOUND[@]}"; do
  name="$(basename "$src")"
  if [[ "$APPLY" -eq 1 ]]; then
    if ! target="$(unique_dest "$DEST" "$name")"; then
      red "  SKIP (bad destination): ${src}"
      failed=$((failed + 1))
      continue
    fi
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
    echo "${src}" >> "$MANIFEST"
    if [[ "$shown" -lt "$max_show" ]]; then
      echo "${src}"
      shown=$((shown + 1))
    fi
  fi
done

if [[ "$APPLY" -eq 0 && ${#FOUND[@]} -gt "$max_show" ]]; then
  yellow "... and $((${#FOUND[@]} - max_show)) more in manifest"
fi

echo ""
if [[ "$APPLY" -eq 0 ]]; then
  yellow "Re-run with --apply to move these to iCloud."
else
  echo "Moved: ${moved}  Failed: ${failed}"
fi
echo "Manifest: ${MANIFEST}"
cp "$MANIFEST" "$LATEST"
echo "Review list: grep -v '^#' '${LATEST}' | less"
echo "Count:       grep -cv '^#' '${LATEST}' || true"
echo "=== done ==="

if [[ "$APPLY" -eq 0 && ${#FOUND[@]} -gt 0 ]]; then
  exit 2
fi
if [[ "$APPLY" -eq 1 && "$failed" -gt 0 ]]; then
  exit 2
fi
