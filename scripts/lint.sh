#!/usr/bin/env bash
set -e

# Usage: ./scripts/lint.sh
echo "Linting..."

# GIT_FILES=$(git ls-files)
CHECK_FILES=$(git ls-files | grep -v -E ".jpg|.svg|3rdparty" | cat)

WHITESPACE_FILES=$(printf '%s' "${CHECK_FILES[@]}" | xargs egrep -l " +$" | grep -v -E ".md" | cat)

if [[ -n "${WHITESPACE_FILES}" ]]; then
    echo "The following files have trailing whitespace:"
    printf '%s\n' "${WHITESPACE_FILES[@]}"
fi

NEWLINE_FILES=$(printf '%s' "${CHECK_FILES[@]}" | \
                xargs -r -I {} bash -c 'test "$(tail -c 1 "{}" | wc -l)" -eq 0 && echo {}' | cat)

if [[ -n "${NEWLINE_FILES}" ]] ; then
    echo "The following files need an EOF newline:"
    printf '%s\n' "${NEWLINE_FILES[@]}"
fi

if [[ -n "${WHITESPACE_FILES}" ]] || [[ -n "${NEWLINE_FILES}" ]] ; then
    exit 1
fi

# enable parallelization for clang-format and clang-tidy
NUM_CORES=1
if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    NUM_CORES=$(grep -c ^processor /proc/cpuinfo)
elif [[ "${OSTYPE}" == "darwin"* ]]; then
    NUM_CORES=$(sysctl -n hw.ncpu)
fi

CHECK_FORMAT_FILES=$(git ls-files \
                    | grep -E "tools|tests|src|cmake-tests" \
                    | grep -E "\..*pp")
echo "${CHECK_FORMAT_FILES}" | \
    xargs -n1 -P"${NUM_CORES}" -I{} clang-format --style=file --Werror --dry-run {}

if ! command -v clang-tidy &>/dev/null; then
    echo "clang-tidy does not appear to be installed"
    echo "Please run ./scripts/setup-dependencies.sh to install dependencies or install manually."
    exit 1
fi

if [[ -z "${BUILD_DIR+x}" ]]; then
    echo "BUILD_DIR environment variable not found. Assuming default: build"
    export BUILD_DIR=build
    if [[ ! -d "${BUILD_DIR}" ]]; then
        echo "${BUILD_DIR} directory not found. Please set BUILD_DIR or run \`export BUILD_DIR=${BUILD_DIR}; build.sh\` before linting."
        exit 1
    fi
fi

# use python from the virtual environment for clang-tidy
if source "./scripts/activate-venv.sh"; then
    python /usr/local/bin/run-clang-tidy.py -j "${NUM_CORES}" -p "${BUILD_DIR}" "tests/.*/.*\.cpp|src/.*/.*\.cpp|tools/.*/.*\.cpp"
    deactivate
fi
