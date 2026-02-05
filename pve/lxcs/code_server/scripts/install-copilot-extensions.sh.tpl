#!/bin/bash
set -e

echo "Installing GitHub Copilot Extensions..."

# 设置代理（如果提供）
%{ if has_proxy ~}
export http_proxy="${http_proxy}"
export https_proxy="${https_proxy}"
echo "Using HTTP proxy: ${http_proxy}"
echo "Using HTTPS proxy: ${https_proxy}"
%{ else ~}
echo "No proxy configured."
%{ endif ~}

# User data directory from code-server config
USER_DATA_DIR="${user_data_dir}"

# Extract VS Code version from code-server
get_vscode_version() {
    code-server --version 2>/dev/null | head -n 1
}

# Check if extension is already installed
is_extension_installed() {
    local extension_id="$1"
    # List installed extensions and check if the extension is present
    if code-server --user-data-dir="$USER_DATA_DIR" --list-extensions 2>/dev/null | grep -qi "^$extension_id$"; then
        return 0
    fi
    return 1
}

# Find compatible extension version
find_compatible_version() {
    local extension_id="$1"
    local vscode_version="$2"

    local response
    response=$(curl -s -X POST "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json;api-version=3.0-preview.1" \
        -d "{
            \"filters\": [{
                \"criteria\": [
                    {\"filterType\": 7, \"value\": \"$extension_id\"},
                    {\"filterType\": 12, \"value\": \"4096\"}
                ],
                \"pageSize\": 50
            }],
            \"flags\": 4112
        }")

    echo "$response" | jq -r --arg vscode_version "$vscode_version" '
        .results[0].extensions[0].versions[] |
        # Match semantic versioning format (major.minor.patch)
        select(.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) |
        # Filter out pre-release versions with long identifiers (e.g., 1.234.5678)
        select(.version | length < 12) |
        {
            version: .version,
            engine: (.properties[] | select(.key == "Microsoft.VisualStudio.Code.Engine") | .value)
        } |
        select(.engine | ltrimstr("^") | split(".") |
            map(split("-")[0] | tonumber?) as $engine_parts |
            ($vscode_version | split(".") | map(tonumber)) as $vscode_parts |
            (
                ($engine_parts[0] // 0) < $vscode_parts[0] or
                (($engine_parts[0] // 0) == $vscode_parts[0] and ($engine_parts[1] // 0) < $vscode_parts[1]) or
                (($engine_parts[0] // 0) == $vscode_parts[0] and ($engine_parts[1] // 0) == $vscode_parts[1] and ($engine_parts[2] // 0) <= $vscode_parts[2])
            )
        ) |
        .version' | head -n 1
}

# Install extension
install_extension() {
    local extension_id="$1"
    local version="$2"
    local extension_name
    extension_name=$(echo "$extension_id" | cut -d'.' -f2)
    local temp_dir="/tmp/code-extensions"

    echo "Installing $extension_id v$version..."

    # Create temp directory
    mkdir -p "$temp_dir"

    # Download
    echo "  Downloading..."
    curl -L "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/$extension_name/$version/vspackage" \
        -o "$temp_dir/$extension_name.vsix.gz"

    if [ ! -f "$temp_dir/$extension_name.vsix.gz" ]; then
        echo "  ✗ Download failed for $extension_id"
        return 1
    fi

    # Decompress (handle both gunzip and gzip -d)
    if command -v gunzip >/dev/null 2>&1; then
        gunzip -f "$temp_dir/$extension_name.vsix.gz"
    else
        gzip -df "$temp_dir/$extension_name.vsix.gz"
    fi

    # Install with user-data-dir
    code-server --user-data-dir="$USER_DATA_DIR" --force --install-extension "$temp_dir/$extension_name.vsix"

    # Clean up
    rm -f "$temp_dir/$extension_name.vsix"

    echo "  ✓ $extension_id installed successfully!"
    return 0
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=""

    # Check for required commands
    for cmd in curl jq code-server; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done

    # Check for either gunzip or gzip
    if ! command -v gunzip >/dev/null 2>&1 && ! command -v gzip >/dev/null 2>&1; then
        missing_deps="$missing_deps gunzip/gzip"
    fi

    if [ -n "$missing_deps" ]; then
        echo "Error: Missing required dependencies:$missing_deps"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Main script
echo "GitHub Copilot Extensions Installer"
echo "===================================="
echo ""

# Check dependencies
check_dependencies

# Get VS Code version
VSCODE_VERSION="$(get_vscode_version)"

if [ -z "$VSCODE_VERSION" ]; then
    echo "Error: Could not extract VS Code version from code-server"
    exit 1
fi

echo "Detected VS Code version: $VSCODE_VERSION"
echo "User data directory: $USER_DATA_DIR"
echo ""

# Ensure user-data-dir exists
mkdir -p "$USER_DATA_DIR"

# Extensions to install
EXTENSIONS="GitHub.copilot GitHub.copilot-chat"
FAILED_COUNT=0

# Iterate through space-separated list for portability
for ext in $EXTENSIONS; do
    echo "Processing $ext..."

    # Check if extension is already installed (idempotency)
    if is_extension_installed "$ext"; then
        echo "  ✓ $ext is already installed, skipping."
        echo ""
        continue
    fi

    # Find compatible version
    version="$(find_compatible_version "$ext" "$VSCODE_VERSION")"

    if [ -z "$version" ]; then
        echo "  ✗ No compatible version found for $ext"
        FAILED_COUNT="$((FAILED_COUNT + 1))"
    else
        echo "  Found compatible version: $version"
        if ! install_extension "$ext" "$version"; then
            FAILED_COUNT="$((FAILED_COUNT + 1))"
        fi
    fi
    echo ""
done

# Summary
echo "===================================="
if [ "$FAILED_COUNT" -eq 0 ]; then
    echo "✓ All extensions installed successfully!"
    # Clean up temp directory on success
    rm -rf /tmp/code-extensions
else
    echo "⚠ Completed with $FAILED_COUNT error(s)"
    exit 1
fi
