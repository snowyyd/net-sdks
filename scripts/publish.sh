#!/bin/bash
set -euo pipefail

# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
echo -e "${CYAN}Script directory: ${GREEN}${SCRIPT_DIR}${RESET}"

# Arg check
if [ "${#}" -lt 2 ]; then
  # Example usage: rm -rf src/build/bin/Release && bash scripts/publish.sh src/ src/build/bin/Release -- --version-suffix "dev.1"
  echo -e "${YELLOW}Usage: ${GREEN}$0 ${CYAN}<source dir> <out dir> [-- <additional dotnet pack args>]${RESET}" >&2
  exit 1
fi

# Paths
ENV_FILE="$(realpath "$SCRIPT_DIR/../.env")"
SOURCE_DIR="$1"
OUT_DIR="$2"

# Shift the positional parameters to remove the first two arguments ($1 and $2)
shift 2

# Capture remaining arguments after the '--' token
EXTRA_ARGS=()
if [ "${#}" -gt 0 ] && [ "$1" == "--" ]; then
  shift # Remove the '--' token from the argument list
  EXTRA_ARGS=("${@}") # Store all remaining arguments into an array
fi

# Env loading
if [[ ! -f "$ENV_FILE" ]]; then
  echo -e "${YELLOW}.env file not found in ${GREEN}${ENV_FILE}${RESET}"
  exit 2
fi

echo -e "${GREEN}Loading ${YELLOW}${ENV_FILE}${RESET}"
set -a
source "$ENV_FILE"
set +a

# Pack
if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "${YELLOW}ERROR: ${GREEN}$SOURCE_DIR ${YELLOW}is not a directory.${RESET}\n"
  exit 3
fi

while IFS= read -r -d '' csproj; do
  DEFAULT_ARGS=(-c Release)
  echo -e "${CYAN}Packing: ${GREEN}$csproj${RESET}"
  echo -e "${YELLOW}Running: ${CYAN}dotnet pack \"$csproj\" ${DEFAULT_ARGS[@]} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
  dotnet pack "$csproj" "${DEFAULT_ARGS[@]}" "${EXTRA_ARGS[@]}"

done < <(find "$SOURCE_DIR" -type f -name '*.csproj' -print0)

# Publish
if [ ! -d "$OUT_DIR" ]; then
  echo -e "${YELLOW}ERROR: ${GREEN}$OUT_DIR ${YELLOW}is not a directory.${RESET}\n"
  exit 3
fi

while IFS= read -r -d '' nupkg; do
  echo -e "${GREEN}Pushing NuGet package to GitLab: ${YELLOW}${nupkg}${RESET}"
  dotnet nuget push "$nupkg" --source gitlab
done < <(find "$OUT_DIR" -type f -name '*.nupkg' -print0)

echo -e "${YELLOW}Done!${RESET}"
