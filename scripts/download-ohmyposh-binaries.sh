#!/bin/bash
# Download Oh My Posh binaries for all platforms
# Usage: ./scripts/download-ohmyposh-binaries.sh [VERSION]
# Example: ./scripts/download-ohmyposh-binaries.sh v24.19.2

set -e

VERSION="${1:-}"

# Validate version argument
if [[ -z "$VERSION" ]]; then
    echo "Error: VERSION argument required"
    echo ""
    echo "Usage: $0 vX.Y.Z"
    echo "Example: $0 v24.19.2"
    echo ""
    echo "Find versions at: https://github.com/JanDeDobbeleer/oh-my-posh/releases"
    exit 1
fi

# Validate version format (vX.Y.Z)
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format: $VERSION"
    echo "Expected format: vX.Y.Z (e.g., v24.19.2)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/../.nvm-isolated/npm-global/bin"
mkdir -p "$TARGET_DIR"

echo "Downloading Oh My Posh binaries (version: $VERSION)..."
echo ""

PLATFORMS=("linux-amd64" "linux-arm64" "darwin-amd64" "darwin-arm64")

for platform in "${PLATFORMS[@]}"; do
    url="https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${VERSION}/posh-${platform}"
    target="$TARGET_DIR/oh-my-posh-${platform}"

    echo "Downloading $platform..."
    if curl -fsSL "$url" -o "$target"; then
        chmod +x "$target"
        size=$(du -h "$target" | cut -f1)
        echo "  ✓ Downloaded: $target ($size)"
    else
        echo "  ✗ Failed to download: $platform"
        exit 1
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All binaries downloaded successfully!"
echo ""
echo "Next steps:"
echo "  1. Verify binaries work:"
echo "     $TARGET_DIR/oh-my-posh-linux-amd64 --version"
echo "  2. Commit to git:"
echo "     git add .nvm-isolated/npm-global/bin/oh-my-posh-*"
echo "     git commit -m 'feat: add Oh My Posh binaries ($VERSION)'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
