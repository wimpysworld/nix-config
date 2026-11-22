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

shift 3
pinned=false
if [[ "${1:-}" == "--revision" ]]; then
	revision="$2"
	pinned=true
	shift 2
fi

repo="$1"
path="$2"
repo_cache_dir="${HF_HUB_CACHE}/models--${repo//\//--}"
snapshot_dir="${repo_cache_dir}/snapshots/${revision}"

mkdir -p "${repo_cache_dir}/refs" "${snapshot_dir}/$(dirname "${path}")"
if [[ "${pinned}" == 'false' ]]; then
	printf '%s\n' "${revision}" >"${repo_cache_dir}/refs/main"
fi

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
	HF_HOME="${cache_root}" \
	HF_HUB_CACHE="${cache_root}/hub" \
	HUGGINGFACE_HUB_CACHE="${cache_root}/hub" \
	LLAMA_PRESEED_MODELS_JSON="${manifest_path}" \
	LLAMA_PRESEED_CACHE_ROOT="${cache_root}" \
	LLAMA_PRESEED_PRUNE="${LLAMA_PRESEED_PRUNE:-0}" \
	TMPDIR="${cache_root}/tmp" \
	TRANSFORMERS_CACHE="${cache_root}/transformers" \
	XDG_CACHE_HOME="${cache_root}/xdg/cache" \
	XDG_CONFIG_HOME="${cache_root}/xdg/config" \
	XDG_DATA_HOME="${cache_root}/xdg/data" \
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
	local hub_cache="${cache_root}/hub"
	local retired_repo="${hub_cache}/models--example--retired"
	local ancillary_cache="${hub_cache}/datasets--example--dataset"
	local symlink_target="${case_root}/other-cache"
	local old_snapshot="${hub_cache}/models--example--single/snapshots/old-revision"
	local extra_repo="${hub_cache}/models--other--model/snapshots/mock-revision"

	mkdir -p "${retired_repo}/blobs" "${ancillary_cache}" "${symlink_target}" "${old_snapshot}" "${extra_repo}"
	: >"${old_snapshot}/old-quant.gguf"
	: >"${extra_repo}/model.gguf"
	: >"${hub_cache}/models--example--file"
	ln -s "${symlink_target}" "${hub_cache}/models--example--link"
	create_hf_mock "${mock_bin}"
	cat >"${manifest_path}" <<'EOF'
[
  {
    "modelRef": "single:model",
    "hfRepo": "example/single",
    "primaryPath": "model.gguf",
    "downloadPaths": ["model.gguf"]
  },
  {
    "modelRef": "other:model",
    "hfRepo": "other/model",
    "primaryPath": "model.gguf",
    "downloadPaths": ["model.gguf"]
  }
]
EOF

	LLAMA_PRESEED_PRUNE=0 run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ -d "${retired_repo}" ]]
	LLAMA_PRESEED_PRUNE=1 run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ ! -e "${retired_repo}" ]]
	[[ -d "${ancillary_cache}" && -d "${symlink_target}" ]]
	[[ -L "${hub_cache}/models--example--link" && -f "${hub_cache}/models--example--file" ]]
	[[ -f "${old_snapshot}/old-quant.gguf" && -f "${extra_repo}/model.gguf" ]]
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

pinned_revision_case() {
	local case_root="${TEST_ROOT}/pinned"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"
	local log_path="${case_root}/hf.log"
	local revision="0123456789abcdef0123456789abcdef01234567"
	local model_path="Mainline_Support/model.gguf_file"
	local repo_cache_dir="${cache_root}/hub/models--example--pinned"
	local old_snapshot="${repo_cache_dir}/snapshots/unpinned-revision"
	local pinned_snapshot="${repo_cache_dir}/snapshots/${revision}"

	create_hf_mock "${mock_bin}"
	mkdir -p "${old_snapshot}/Mainline_Support" "${repo_cache_dir}/refs"
	printf 'unpinned-revision\n' >"${repo_cache_dir}/refs/main"
	: >"${old_snapshot}/${model_path}"
	jq -n --arg revision "${revision}" --arg path "${model_path}" '[
		{
			modelRef: "pinned:model",
			hfRepo: "example/pinned",
			revision: $revision,
			primaryPath: $path,
			downloadPaths: [$path]
		}
	]' >"${manifest_path}"

	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	assert_contains "${log_path}" "download --repo-type model --revision ${revision} example/pinned ${model_path}"
	[[ -f "${pinned_snapshot}/${model_path}" ]]
	: >"${log_path}"
	HF_MOCK_LOG="${log_path}" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}"
	[[ ! -s "${log_path}" ]]
}

invalid_path_case() {
	local case_root="${TEST_ROOT}/invalid-path"
	local mock_bin="${case_root}/bin"
	local cache_root="${case_root}/cache"
	local manifest_path="${case_root}/manifest.json"
	local stderr_path="${case_root}/stderr.txt"
	local retired_repo="${cache_root}/hub/models--example--retired"

	mkdir -p "${retired_repo}"
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

	if LLAMA_PRESEED_PRUNE=1 run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}" 2>"${stderr_path}"; then
		printf 'invalid_path_case should have failed\n' >&2
		exit 1
	fi

	assert_contains "${stderr_path}" "primaryPath must be repo-relative for model: invalid:model"
	[[ -d "${retired_repo}" ]]

	printf '[]\n' >"${manifest_path}"
	if LLAMA_PRESEED_PRUNE=1 run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}" 2>"${stderr_path}"; then
		printf 'empty manifest should have failed\n' >&2
		exit 1
	fi
	[[ -d "${retired_repo}" ]]
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
	local old_snapshot="${cache_root}/hub/models--example--missing/snapshots/old-revision/Q4"
	local retired_repo="${cache_root}/hub/models--example--retired"

	mkdir -p "${case_root}"
	create_hf_mock "${mock_bin}"
	mkdir -p "${old_snapshot}" "${retired_repo}"
	: >"${old_snapshot}/model-00002-of-00002.gguf"
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

	if LLAMA_PRESEED_PRUNE=1 HF_MOCK_MODE="missing-last-shard" run_preseed "${manifest_path}" "${cache_root}" "${mock_bin}" 2>"${stderr_path}"; then
		printf 'missing_shard_case should have failed\n' >&2
		exit 1
	fi

	assert_contains "${stderr_path}" "failed to resolve downloaded GGUF path Q4/model-00002-of-00002.gguf for model: missing:shard"
	[[ -d "${retired_repo}" ]]
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

	assert_contains "${stderr_path}" "downloadPath must end with .gguf or .gguf_file for model: invalid:download-path"
}

single_file_case
sharded_case
pinned_revision_case
invalid_path_case
idempotence_case
refs_main_fixture_case
snapshot_fallback_fixture_case
warm_cache_fixture_case
missing_shard_case
invalid_download_path_case

printf 'preseed-models tests passed\n'
