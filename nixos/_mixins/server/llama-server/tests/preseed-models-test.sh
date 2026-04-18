#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/preseed-models.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

create_hf_mock() {
	local mock_root="$1"

	mkdir -p "${mock_root}"
	cat >"${mock_root}/hf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${HF_MOCK_LOG:-}"
revision="${HF_MOCK_REVISION:-mock-revision}"
mode="${HF_MOCK_MODE:-success}"

if [[ -n "${log_file}" ]]; then
	printf '%s\n' "$*" >>"${log_file}"
fi

if [[ "${1:-}" != "download" || "${2:-}" != "--repo-type" || "${3:-}" != "model" ]]; then
	printf 'unexpected hf invocation: %s\n' "$*" >&2
	exit 1
fi

repo="$4"
path="$5"
repo_cache_dir="${HF_HUB_CACHE}/models--${repo//\//--}"
snapshot_dir="${repo_cache_dir}/snapshots/${revision}"

mkdir -p "${repo_cache_dir}/refs" "${snapshot_dir}/$(dirname "${path}")"
printf '%s\n' "${revision}" >"${repo_cache_dir}/refs/main"

case "${mode}" in
success)
		: >"${snapshot_dir}/${path}"
		;;
missing-last-shard)
		if [[ "${path}" != *"-00002-of-00002.gguf" ]]; then
			: >"${snapshot_dir}/${path}"
		fi
		;;
	*)
		printf 'unknown HF_MOCK_MODE: %s\n' "${mode}" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${mock_root}/hf"
}

run_preseed() {
	local manifest_path="$1"
	local cache_root="$2"
	local mock_bin="$3"

	PATH="${mock_bin}:${PATH}" \
	LLAMA_PRESEED_MODELS_JSON="${manifest_path}" \
	LLAMA_PRESEED_CACHE_ROOT="${cache_root}" \
	bash "${SCRIPT_PATH}"
}

assert_contains() {
	local file_path="$1"
	local pattern="$2"

	grep -F "${pattern}" "${file_path}" >/dev/null
}

single_file_case() {
	local case_root="${TEST_ROOT}/single-file"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"

	mkdir -p "${case_root}"
	create_hf_mock "${mock_bin}"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "single:model",
    "hfRepo": "example/single",
    "primaryPath": "model.gguf",
    "downloadPaths": ["model.gguf"]
  }
]
EOF

	run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ -f "${cache_root}/hub/models--example--single/refs/main" ]]
	[[ -f "${cache_root}/hub/models--example--single/snapshots/mock-revision/model.gguf" ]]
}

sharded_case() {
	local case_root="${TEST_ROOT}/sharded"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"

	mkdir -p "${case_root}"
	create_hf_mock "${mock_bin}"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "sharded:model",
    "hfRepo": "example/sharded",
    "primaryPath": "Q4/model-00001-of-00002.gguf",
    "downloadPaths": [
      "Q4/model-00001-of-00002.gguf",
      "Q4/model-00002-of-00002.gguf"
    ]
  }
]
EOF

	run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ -f "${cache_root}/hub/models--example--sharded/snapshots/mock-revision/Q4/model-00001-of-00002.gguf" ]]
	[[ -f "${cache_root}/hub/models--example--sharded/snapshots/mock-revision/Q4/model-00002-of-00002.gguf" ]]
}

invalid_path_case() {
	local case_root="${TEST_ROOT}/invalid-path"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"
	local stderr_path="${case_root}/stderr.txt"

	mkdir -p "${case_root}"
	create_hf_mock "${mock_bin}"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "invalid:model",
    "hfRepo": "example/invalid",
    "primaryPath": "../model.gguf",
    "downloadPaths": ["../model.gguf"]
  }
]
EOF

	if run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}" 2>"${stderr_path}"; then
		printf 'invalid_path_case should have failed\n' >&2
		exit 1
	fi

	assert_contains "${stderr_path}" "primaryPath must be repo-relative for model: invalid:model"
}

idempotence_case() {
	local case_root="${TEST_ROOT}/idempotence"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"
	local log_path="${case_root}/hf.log"

	mkdir -p "${case_root}"
	create_hf_mock "${mock_bin}"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "idempotent:model",
    "hfRepo": "example/idempotent",
    "primaryPath": "model.gguf",
    "downloadPaths": ["model.gguf"]
  }
]
EOF

	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ -s "${log_path}" ]]
	: >"${log_path}"
	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ ! -s "${log_path}" ]]
}

refs_main_fixture_case() {
	local case_root="${TEST_ROOT}/refs-main"
	local mock_bin="${TEST_ROOT}/refs-main-bin"
	local log_path="${TEST_ROOT}/refs-main.log"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"

	create_hf_mock "${mock_bin}"
	mkdir -p "${cache_root}/hub/models--example--fixture-refs-main/refs"
	mkdir -p "${cache_root}/hub/models--example--fixture-refs-main/snapshots/fixture-main-revision"
	printf 'fixture-main-revision\n' >"${cache_root}/hub/models--example--fixture-refs-main/refs/main"
	: >"${cache_root}/hub/models--example--fixture-refs-main/snapshots/fixture-main-revision/model.gguf"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "fixture:refs-main",
    "hfRepo": "example/fixture-refs-main",
    "primaryPath": "model.gguf",
    "downloadPaths": ["model.gguf"]
  }
]
EOF

	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ ! -e "${log_path}" ]]
}

snapshot_fallback_fixture_case() {
	local case_root="${TEST_ROOT}/snapshot-fallback"
	local mock_bin="${TEST_ROOT}/snapshot-fallback-bin"
	local log_path="${TEST_ROOT}/snapshot-fallback.log"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"

	create_hf_mock "${mock_bin}"
	mkdir -p "${cache_root}/hub/models--example--fixture-snapshot-fallback/snapshots/fallback-revision/nested"
	: >"${cache_root}/hub/models--example--fixture-snapshot-fallback/snapshots/fallback-revision/nested/model.gguf"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "fixture:snapshot-fallback",
    "hfRepo": "example/fixture-snapshot-fallback",
    "primaryPath": "nested/model.gguf",
    "downloadPaths": ["nested/model.gguf"]
  }
]
EOF

	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ ! -e "${log_path}" ]]
}

warm_cache_fixture_case() {
	local case_root="${TEST_ROOT}/warm-cache"
	local mock_bin="${TEST_ROOT}/warm-cache-bin"
	local log_path="${TEST_ROOT}/warm-cache.log"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"

	create_hf_mock "${mock_bin}"
	mkdir -p "${cache_root}/hub/models--example--fixture-warm-sharded/refs"
	mkdir -p "${cache_root}/hub/models--example--fixture-warm-sharded/snapshots/warm-sharded-revision/Q4"
	printf 'warm-sharded-revision\n' >"${cache_root}/hub/models--example--fixture-warm-sharded/refs/main"
	: >"${cache_root}/hub/models--example--fixture-warm-sharded/snapshots/warm-sharded-revision/Q4/model-00001-of-00002.gguf"
	: >"${cache_root}/hub/models--example--fixture-warm-sharded/snapshots/warm-sharded-revision/Q4/model-00002-of-00002.gguf"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "fixture:warm-sharded",
    "hfRepo": "example/fixture-warm-sharded",
    "primaryPath": "Q4/model-00001-of-00002.gguf",
    "downloadPaths": [
      "Q4/model-00001-of-00002.gguf",
      "Q4/model-00002-of-00002.gguf"
    ]
  }
]
EOF

	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ ! -e "${log_path}" ]]
	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ ! -e "${log_path}" ]]
}

missing_shard_case() {
	local case_root="${TEST_ROOT}/missing-shard"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"
	local stderr_path="${case_root}/stderr.txt"

	mkdir -p "${case_root}"
	create_hf_mock "${mock_bin}"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "missing:shard",
    "hfRepo": "example/missing",
    "primaryPath": "Q4/model-00001-of-00002.gguf",
    "downloadPaths": [
      "Q4/model-00001-of-00002.gguf",
      "Q4/model-00002-of-00002.gguf"
    ]
  }
]
EOF

	if HF_MOCK_MODE="missing-last-shard" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}" 2>"${stderr_path}"; then
		printf 'missing_shard_case should have failed\n' >&2
		exit 1
	fi

	assert_contains "${stderr_path}" "failed to resolve downloaded GGUF path Q4/model-00002-of-00002.gguf for model: missing:shard"
}

invalid_download_path_case() {
	local case_root="${TEST_ROOT}/invalid-download-path"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"
	local stderr_path="${case_root}/stderr.txt"

	mkdir -p "${case_root}"
	create_hf_mock "${mock_bin}"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "invalid:download-path",
    "hfRepo": "example/invalid-download-path",
    "primaryPath": "model.gguf",
    "downloadPaths": ["bad/model.bin"]
  }
]
EOF

	if run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}" 2>"${stderr_path}"; then
		printf 'invalid_download_path_case should have failed\n' >&2
		exit 1
	fi

	assert_contains "${stderr_path}" "downloadPath must end with .gguf for model: invalid:download-path"
}

single_file_case
sharded_case
invalid_path_case
idempotence_case
refs_main_fixture_case
snapshot_fallback_fixture_case
warm_cache_fixture_case
missing_shard_case
invalid_download_path_case

printf 'preseed-models tests passed\n'
