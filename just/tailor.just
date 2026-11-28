# Managed by Tailor: just/tailor.just

# Run explicitly requested setup for enabled components
setup:
    @echo "No setup recipes are enabled."

# Build all enabled ecosystems
build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "No build recipes are enabled."
    project_script='just/project/build.sh'
    for parent in just just/project; do
        if [[ -L "${parent}" || ( -e "${parent}" && ! -d "${parent}" ) ]]; then
            echo "Error: project script parent ${parent} must be a directory, not a symlink" >&2
            exit 1
        fi
    done
    if [[ -L "${project_script}" || ( -e "${project_script}" && ! -f "${project_script}" ) ]]; then
        echo "Error: project script ${project_script} must be a regular file, not a symlink" >&2
        exit 1
    fi
    if [[ -f "${project_script}" ]]; then
        bash "${project_script}"
    fi

# Run full vet and tests with console coverage
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "No test recipes are enabled."
    project_script='just/project/test.sh'
    for parent in just just/project; do
        if [[ -L "${parent}" || ( -e "${parent}" && ! -d "${parent}" ) ]]; then
            echo "Error: project script parent ${parent} must be a directory, not a symlink" >&2
            exit 1
        fi
    done
    if [[ -L "${project_script}" || ( -e "${project_script}" && ! -f "${project_script}" ) ]]; then
        echo "Error: project script ${project_script} must be a regular file, not a symlink" >&2
        exit 1
    fi
    if [[ -f "${project_script}" ]]; then
        bash "${project_script}"
    fi

# Check source without changes, or tidy and format with correct
lint $mode="check":
    #!/usr/bin/env bash
    set -euo pipefail
    case "${mode}" in
        check|correct) ;;
        *) echo "Error: lint mode must be check or correct" >&2; exit 1 ;;
    esac
    check_workflows() {
        for workflow in .github/workflows/* .github/workflows/.*; do
            case "${workflow}" in *.yml|*.yaml)
                if [[ -f "${workflow}" ]]; then
                    actionlint
                    return
                fi ;;
            esac
        done
        echo "No GitHub Actions workflows found. Skipping actionlint."
    }
    check_workflows
    project_script='just/project/lint.sh'
    for parent in just just/project; do
        if [[ -L "${parent}" || ( -e "${parent}" && ! -d "${parent}" ) ]]; then
            echo "Error: project script parent ${parent} must be a directory, not a symlink" >&2
            exit 1
        fi
    done
    if [[ -L "${project_script}" || ( -e "${project_script}" && ! -f "${project_script}" ) ]]; then
        echo "Error: project script ${project_script} must be a regular file, not a symlink" >&2
        exit 1
    fi
    if [[ -f "${project_script}" ]]; then
        bash "${project_script}" "${mode}"
    fi

# Create a local release tag with just release x.y.z
release $VERSION:
    #!/usr/bin/env bash
    set -e

    if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: VERSION must be in format x.y.z (e.g., 0.1.0)"
        exit 1
    fi

    # Require a clean checkout so that the tag matches the local source files.
    if [ -n "$(git status --porcelain)" ]; then
        echo "Error: Working directory is not clean"
        exit 1
    fi

    if git show-ref --tags --verify --quiet "refs/tags/v${VERSION}"; then
        echo "Error: Tag v${VERSION} already exists"
        exit 1
    fi

    echo "Creating release v${VERSION}..."
    git tag -a "v${VERSION}" -m "v${VERSION}"
    echo "Tag v${VERSION} created"
    echo ""
    echo "To publish the release:"
    echo "  git push origin v${VERSION}"
    echo ""
