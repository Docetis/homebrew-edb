#!/usr/bin/env bash
set -euo pipefail

### CONFIG ###########################################################

MAIN_REPO_EXPECTED="Docetis/edb"
MAIN_REPO_GITHUB="https://github.com/Docetis/edb"
TAP_REPO_URL="git@github.com:Docetis/homebrew-edb.git"

# directory where the tap repo will live (relative to this script)
TAP_DIR="../homebrew-edb"

# path of the formula inside the tap repo
FORMULA_PATH="Formula/edb.rb"

######################################################################

red()   { printf "\033[31m%s\033[0m\n" "$*" >&2; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }

usage() {
  echo "Usage: $0 vX.Y.Z"
  echo "Example: $0 v0.0.2"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

VERSION="$1"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  red "Version must be like v0.0.2, got: $VERSION"
  exit 1
fi

# ensure we run from main repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

### 1. Check we are in the correct Git repo and it's clean ############

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  red "This is not a git repository. Run this from the edb main repo."
  exit 1
fi

CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || echo "")"
if [[ -n "$CURRENT_REMOTE" ]] && [[ "$CURRENT_REMOTE" != *"$MAIN_REPO_EXPECTED"* ]]; then
  yellow "Warning: origin remote does not look like $MAIN_REPO_EXPECTED:"
  echo "  $CURRENT_REMOTE"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  red "Git working tree is not clean. Commit or stash your changes first."
  git status --short
  exit 1
fi

### 2. Create & push tag on main repo ################################

green "==> Creating tag $VERSION on main repo"

git fetch --tags origin

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  yellow "Tag $VERSION already exists locally. Skipping tag creation."
else
  git tag "$VERSION"
fi

green "==> Pushing tag $VERSION to origin"
git push origin "$VERSION"

### 3. Download tarball & compute SHA256 #############################

TARBALL_URL="$MAIN_REPO_GITHUB/archive/refs/tags/$VERSION.tar.gz"
TARBALL_FILE="/tmp/edb-$VERSION.tar.gz"

green "==> Downloading tarball: $TARBALL_URL"
curl -L -o "$TARBALL_FILE" "$TARBALL_URL"

if command -v shasum >/dev/null 2>&1; then
  SHA256=$(shasum -a 256 "$TARBALL_FILE" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  SHA256=$(sha256sum "$TARBALL_FILE" | awk '{print $1}')
else
  red "Neither shasum nor sha256sum is available. Install one of them."
  exit 1
fi

green "==> SHA256 for $VERSION:"
echo "    $SHA256"

### 4. Prepare / update tap repo #####################################

# TAP_DIR is relative to the main repo root
if [[ ! -d "$TAP_DIR/.git" ]]; then
  green "==> Cloning tap repo into $TAP_DIR"
  git clone "$TAP_REPO_URL" "$TAP_DIR"
else
  green "==> Using existing tap repo at $TAP_DIR"
fi

cd "$TAP_DIR"

green "==> Pulling latest changes in tap repo"
git pull --rebase

if [[ ! -f "$FORMULA_PATH" ]]; then
  red "Formula file not found at $FORMULA_PATH in tap repo."
  exit 1
fi

### 5. Update Formula/edb.rb (url + sha256) ##########################

green "==> Updating formula with new version and sha256"

# update url line
sed -i.bak -E \
  "s|(  url \"https://github.com/Docetis/edb/archive/refs/tags/).*(\"$)|\1$VERSION.tar.gz\2|" \
  "$FORMULA_PATH"

# update sha256 line
sed -i.bak -E \
  "s|(  sha256 \").*(\"$)|\1$SHA256\2|" \
  "$FORMULA_PATH"

rm -f "${FORMULA_PATH}.bak"

green "Updated formula snippet:"
grep -E 'url "|sha256 "' "$FORMULA_PATH" || true

### 6. Commit & push formula change ##################################

if [[ -n "$(git status --porcelain)" ]]; then
  git add "$FORMULA_PATH"
  git commit -m "Bump edb to $VERSION"
  green "==> Pushing tap repo changes"
  git push
else
  yellow "No changes detected in tap repo, nothing to commit."
fi

### 7. Final message #################################################

green "================================================"
green " Release $VERSION completed."
green " Tarball: $TARBALL_URL"
green " SHA256:  $SHA256"
green
green " To test with Homebrew:"
echo "   brew untap Docetis/edb || true"
echo "   brew tap Docetis/edb"
echo "   brew install edb"
green "================================================"
