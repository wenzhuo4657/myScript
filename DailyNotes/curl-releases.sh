#!/bin/bash
# Fetch GitHub releases/tags for a repo and let user select one.

# Only enable strict mode when executed directly, not when sourced
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
fi

OWNER=${1:-}
REPO=${2:-}

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Usage: $0 <owner> <repo>" >&2
  # If sourced, return; else exit
  return 1 2>/dev/null || exit 1
fi

API_BASE="https://api.github.com/repos/$OWNER/$REPO"

echo "Fetching releases for $OWNER/$REPO..."
echo "=========================================="

tmp_json=$(mktemp)

# Build curl headers; use token if provided to avoid rate limits
auth_args=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

curl_api() {
  local url="$1"
  curl -sS -w "%{http_code}" -o "$tmp_json" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${auth_args[@]}" \
    "$url"
}

parse_array_field() {
  local file="$1" field_name="$2"
  jq -r --arg fn "$field_name" '.[] | .[$fn] // empty' "$file"
}

ensure_not_sourced_exit() {
  rm -f "$tmp_json"
  return 1 2>/dev/null || exit 1
}

tagList=()
urlList=()

# Try releases first
http_code=$(curl_api "$API_BASE/releases") || http_code="000"

use_tags_fallback=false

if [[ "$http_code" != "200" ]]; then
  use_tags_fallback=true
else
  jtype=$(jq -r 'type' "$tmp_json" 2>/dev/null || echo "unknown")
  if [[ "$jtype" != "array" ]]; then
    use_tags_fallback=true
  else
    count=$(jq 'length' "$tmp_json")
    if [[ "$count" -eq 0 ]]; then
      use_tags_fallback=true
    else
      while IFS= read -r t; do tagList+=("$t"); done < <(parse_array_field "$tmp_json" tag_name)
      while IFS= read -r u; do urlList+=("$u"); done < <(parse_array_field "$tmp_json" tarball_url)
    fi
  fi
fi

if [[ "$use_tags_fallback" == true ]]; then
  echo "Releases unavailable; falling back to tags..."
  http_code=$(curl_api "$API_BASE/tags?per_page=100") || http_code="000"

  if [[ "$http_code" != "200" ]]; then
    echo "ERROR: GitHub API returned HTTP $http_code" >&2
    msg=$(jq -r '.message // empty' "$tmp_json" 2>/dev/null || true)
    if [[ -n "$msg" ]]; then echo "Message: $msg" >&2; fi
    ensure_not_sourced_exit
  fi

  jtype=$(jq -r 'type' "$tmp_json" 2>/dev/null || echo "unknown")
  if [[ "$jtype" != "array" ]]; then
    echo "ERROR: Unexpected API response (expected array)" >&2
    msg=$(jq -r '.message // empty' "$tmp_json" 2>/dev/null || true)
    if [[ -n "$msg" ]]; then echo "Message: $msg" >&2; fi
    ensure_not_sourced_exit
  fi

  count=$(jq 'length' "$tmp_json")
  if [[ "$count" -eq 0 ]]; then
    echo "ERROR: No tags found in repository $OWNER/$REPO" >&2
    ensure_not_sourced_exit
  fi

  while IFS= read -r t; do tagList+=("$t"); done < <(parse_array_field "$tmp_json" name)
  while IFS= read -r u; do urlList+=("$u"); done < <(parse_array_field "$tmp_json" tarball_url)
fi

rm -f "$tmp_json"

echo "Found versions: ${#tagList[@]}"
echo "=========================================="

if [[ ${#tagList[@]} -eq 0 ]]; then
  echo "ERROR: No versions available to select" >&2
  ensure_not_sourced_exit
fi

for (( i = 0; i < ${#tagList[@]}; i++ )); do
  printf '%3d) %s\n' "$((i+1))" "${tagList[$i]}"
done

echo "Select a tag to download:"
PS3="Enter choice (1-${#tagList[@]}): "
select tag in "${tagList[@]}"; do
  if [[ -n "$tag" ]]; then
    echo "Selected: $tag"
    break
  else
    echo "Invalid choice, please retry."
  fi
done

selected_url=""
for (( i = 0; i < ${#tagList[@]}; i++ )); do
  if [[ "${tagList[$i]}" == "$tag" ]]; then
    selected_url="${urlList[$i]}"
    break
  fi
done

export SELECTED_URL="$selected_url"
export SELECTED_TAG="$tag"

echo "selected URL: $selected_url"
