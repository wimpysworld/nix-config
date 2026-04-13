#!/usr/bin/env bash

set -euo pipefail

manifest_path="${1:-${LLAMA_PRESEED_MODELS_JSON:-}}"
cache_root="${LLAMA_PRESEED_CACHE_ROOT:-/var/lib/llama-models/huggingface}"

die() {
	printf 'Error: %s\n' "$1" >&2
	exit 1
}

validate_repo_relative_path() {
	local path_value="$1"
	local path_component
	local -a path_components=()

	if [[ -z "${path_value}" || "${path_value}" == /* ]]; then
		return 1
	fi

	IFS='/' read -r -a path_components <<<"${path_value}"
	for path_component in "${path_components[@]}"; do
		if [[ -z "${path_component}" || "${path_component}" == '.' || "${path_component}" == '..' ]]; then
			return 1
		fi
	done

	return 0
}

validate_gguf_path() {
	local model_ref="$1"
	local field_name="$2"
	local path_value="$3"

	if [[ "${path_value}" != *.gguf ]]; then
		die "${field_name} must end with .gguf for model: ${model_ref}"
	fi

	if ! validate_repo_relative_path "${path_value}"; then
		die "${field_name} must be repo-relative for model: ${model_ref}"
	fi
}

resolve_cached_hf_path() {
	local hf_repo="$1"
	local repo_relative_path="$2"
	local repo_cache_dir
	local revision
	local candidate
	local -a candidates=()

	repo_cache_dir="${HF_HUB_CACHE}/models--${hf_repo//\//--}"

	if [[ -f "${repo_cache_dir}/refs/main" ]]; then
		revision="$(<"${repo_cache_dir}/refs/main")"
		candidate="${repo_cache_dir}/snapshots/${revision}/${repo_relative_path}"
		if [[ -e "${candidate}" ]]; then
			printf '%s\n' "${candidate}"
			return 0
		fi
	fi

	shopt -s nullglob
	candidates=("${repo_cache_dir}"/snapshots/*/"${repo_relative_path}")
	shopt -u nullglob

	if [[ ${#candidates[@]} -gt 0 ]]; then
		printf '%s\n' "${candidates[0]}"
		return 0
	fi

	return 1
}

run_hf() {
	hf "$@"
}

prepare_model() {
	local spec_json="$1"
	local model_ref
	local hf_repo
	local primary_path
	local download_path
	local hf_model_path=""
	local primary_in_downloads='false'
	local missing_download='false'
	local -a download_paths=()

	model_ref="$(jq -er '.modelRef' <<<"${spec_json}")" || die "manifest entry is missing modelRef"
	hf_repo="$(jq -er '.hfRepo' <<<"${spec_json}")" || die "manifest entry is missing hfRepo for model: ${model_ref}"
	primary_path="$(jq -er '.primaryPath' <<<"${spec_json}")" || die "manifest entry is missing primaryPath for model: ${model_ref}"

	jq -e '.downloadPaths | type == "array" and length > 0' <<<"${spec_json}" >/dev/null || die "downloadPaths must be a non-empty array for model: ${model_ref}"
	while IFS= read -r download_path; do
		download_paths+=("${download_path}")
	done < <(jq -r '.downloadPaths[]' <<<"${spec_json}")

	if [[ -z "${hf_repo}" ]]; then
		die "hfRepo must not be empty for model: ${model_ref}"
	fi

	validate_gguf_path "${model_ref}" "primaryPath" "${primary_path}"

	for download_path in "${download_paths[@]}"; do
		validate_gguf_path "${model_ref}" "downloadPath" "${download_path}"
		if [[ "${download_path}" == "${primary_path}" ]]; then
			primary_in_downloads='true'
		fi
	done

	if [[ "${primary_in_downloads}" != 'true' ]]; then
		die "primaryPath must be present in downloadPaths for model: ${model_ref}"
	fi

	printf 'Pre-seed %s\n' "${model_ref}"

	for download_path in "${download_paths[@]}"; do
		if ! resolve_cached_hf_path "${hf_repo}" "${download_path}" >/dev/null; then
			missing_download='true'
			break
		fi
	done

	if [[ "${missing_download}" == 'false' ]] && hf_model_path="$(resolve_cached_hf_path "${hf_repo}" "${primary_path}")"; then
		printf '  Hugging Face GGUF: ready\n'
	else
		printf '  Hugging Face GGUF: downloading\n'
		for download_path in "${download_paths[@]}"; do
			run_hf download --repo-type model "${hf_repo}" "${download_path}"
		done
		hf_model_path="$(resolve_cached_hf_path "${hf_repo}" "${primary_path}")" || true
	fi

	if [[ -z "${hf_model_path}" ]]; then
		die "failed to resolve downloaded GGUF path for model: ${model_ref}"
	fi

	for download_path in "${download_paths[@]}"; do
		if ! resolve_cached_hf_path "${hf_repo}" "${download_path}" >/dev/null; then
			die "failed to resolve downloaded GGUF path ${download_path} for model: ${model_ref}"
		fi
	done

	printf '  Hugging Face GGUF: verified\n'
}

[[ -n "${manifest_path}" ]] || die "no manifest path supplied"
[[ -f "${manifest_path}" ]] || die "manifest file does not exist: ${manifest_path}"
[[ -n "${cache_root}" ]] || die "cache root must not be empty"

export HF_HOME="${HF_HOME:-${cache_root}}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-${cache_root}/hub}"
export HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-${HF_HUB_CACHE}}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-${cache_root}/transformers}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${cache_root}/xdg/cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${cache_root}/xdg/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${cache_root}/xdg/data}"
export TMPDIR="${TMPDIR:-${cache_root}/tmp}"

mkdir -p \
	"${HF_HUB_CACHE}" \
	"${TMPDIR}" \
	"${TRANSFORMERS_CACHE}" \
	"${XDG_CACHE_HOME}" \
	"${XDG_CONFIG_HOME}" \
	"${XDG_DATA_HOME}"

jq -e 'type == "array" and length > 0' "${manifest_path}" >/dev/null || die "manifest must be a non-empty JSON array"

while IFS= read -r spec_json; do
	prepare_model "${spec_json}"
done < <(jq -c '.[]' "${manifest_path}")
