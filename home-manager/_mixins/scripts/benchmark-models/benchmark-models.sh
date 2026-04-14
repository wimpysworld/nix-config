#!/usr/bin/env bash
# benchmark-models.sh

set -euo pipefail

PROMPT="Write a detailed 500-word essay about the history of optical fibre telecommunications."
MODEL_SPECS=$(
	cat <<'EOF'
	gemma4:26b|unsloth/gemma-4-26B-A4B-it-GGUF|gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf|gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf
	gemma4:31b|unsloth/gemma-4-31B-it-GGUF|gemma-4-31B-it-UD-Q4_K_XL.gguf|gemma-4-31B-it-UD-Q4_K_XL.gguf
	gemma4:e2b|unsloth/gemma-4-E2B-it-GGUF|gemma-4-E2B-it-UD-Q6_K_XL.gguf|gemma-4-E2B-it-UD-Q6_K_XL.gguf
	gemma4:e4b|unsloth/gemma-4-E4B-it-GGUF|gemma-4-E4B-it-UD-Q6_K_XL.gguf|gemma-4-E4B-it-UD-Q6_K_XL.gguf
	gpt-oss:20b|unsloth/gpt-oss-20b-GGUF|gpt-oss-20b-UD-Q4_K_XL.gguf|gpt-oss-20b-UD-Q4_K_XL.gguf
	gpt-oss:120b|unsloth/gpt-oss-120b-GGUF|UD-Q4_K_XL/gpt-oss-120b-UD-Q4_K_XL-00001-of-00002.gguf|UD-Q4_K_XL/gpt-oss-120b-UD-Q4_K_XL-00001-of-00002.gguf,UD-Q4_K_XL/gpt-oss-120b-UD-Q4_K_XL-00002-of-00002.gguf
	qwen3:1.7b|unsloth/Qwen3-1.7B-GGUF|Qwen3-1.7B-UD-Q4_K_XL.gguf|Qwen3-1.7B-UD-Q4_K_XL.gguf
	qwen3-coder:30b|unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF|Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf|Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf
	qwen3.5:9b|unsloth/Qwen3.5-9B-GGUF|Qwen3.5-9B-UD-Q4_K_XL.gguf|Qwen3.5-9B-UD-Q4_K_XL.gguf
	qwen3.5:27b|unsloth/Qwen3.5-27B-GGUF|Qwen3.5-27B-UD-Q4_K_XL.gguf|Qwen3.5-27B-UD-Q4_K_XL.gguf
	qwen3.5:35b|unsloth/Qwen3.5-35B-A3B-GGUF|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf
	qwen2.5-coder:14b|unsloth/Qwen2.5-Coder-14B-Instruct-128K-GGUF|Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf|Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf
	qwen2.5-coder:7b|unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF|Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf|Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf
	qwen3-coder-next|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-UD-Q4_K_XL.gguf|Qwen3-Coder-Next-UD-Q4_K_XL.gguf
	qwen3-embedding:0.6b|Qwen/Qwen3-Embedding-0.6B-GGUF|Qwen3-Embedding-0.6B-Q8_0.gguf|Qwen3-Embedding-0.6B-Q8_0.gguf
	qwen3-embedding:4b|Qwen/Qwen3-Embedding-4B-GGUF|Qwen3-Embedding-4B-Q8_0.gguf|Qwen3-Embedding-4B-Q8_0.gguf
	rnj-1:8b|unsloth/rnj-1-instruct-GGUF|rnj-1-instruct-UD-Q4_K_XL.gguf|rnj-1-instruct-UD-Q4_K_XL.gguf
EOF
)
VOLATILE_ROOT="${BENCHMARK_MODELS_ROOT:-${HOME}/Volatile/benchmark-models}"
XDG_ROOT="${VOLATILE_ROOT}/xdg"
HF_ROOT="${VOLATILE_ROOT}/huggingface"
LLAMA_ROOT="${VOLATILE_ROOT}/llama.cpp"
OLLAMA_ROOT="${VOLATILE_ROOT}/ollama"
OLLAMA_RUNTIME_HOME="${OLLAMA_ROOT}/home"
OLLAMA_MODELS_DIR="${OLLAMA_ROOT}/models"
TMP_ROOT="${VOLATILE_ROOT}/tmp"
OLLAMA_LOG="${VOLATILE_ROOT}/ollama-server.log"
OLLAMA_BIND="${BENCHMARK_MODELS_OLLAMA_HOST:-127.0.0.1:11435}"
OLLAMA_URL="http://${OLLAMA_BIND}"
TMPFILE=""
OLLAMA_PID=""
OLLAMA_COMMAND=""
HF_REPO=""
HF_PRIMARY_PATH=""
HF_MODEL_PATH=""
MODEL=""
RUNS="5"
PURGE_REQUESTED='false'
HOST_COMPUTE_VENDOR="${BENCHMARK_MODELS_HOST_GPU_COMPUTE_VENDOR:-}"
BACKEND_MATRIX_REASON=""
declare -a RUNNER_LABELS=()
declare -a RUNNER_TYPES=()
declare -a RUNNER_COMMANDS=()
declare -a RUNNER_MEAN=()
declare -a RUNNER_MIN=()
declare -a RUNNER_MAX=()
declare -a RUNNER_SPREAD=()
declare -a RUNNER_SKIPPED=()
declare -a HF_DOWNLOAD_PATHS=()

usage() {
	cat <<'EOF'
Usage: benchmark-models [--purge] [model] [runs]

Benchmarks one model across the user-scoped Ollama backend and host-specific llama.cpp backends.

Arguments:
  model   Ollama model name to benchmark, default: qwen3.5:35b-a3b
  runs    Number of measured runs, default: 5

Options:
  --purge  Remove the benchmark-models volatile root, then exit
  -h, --help
           Show this help text

Backend matrix:
  AMD      rocm-ollama, vulkan-ollama, rocm-llama-bench, vulkan-llama-bench
  NVIDIA   cuda-ollama, vulkan-ollama, cuda-llama-bench, vulkan-llama-bench

Environment:
  BENCHMARK_MODELS_ROOT        Root directory for caches under ~/Volatile
  BENCHMARK_MODELS_OLLAMA_HOST Host:port for the temporary Ollama server
EOF
}

trim_whitespace() {
	local value="$1"

	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "${value}"
}

list_supported_models() {
	local model

	printf 'Supported models:\n'
	while IFS='|' read -r model _; do
		model="$(trim_whitespace "${model}")"
		printf '  - %s\n' "${model}"
	done <<<"${MODEL_SPECS}"
}

parse_args() {
	local positional=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--purge)
			PURGE_REQUESTED='true'
			;;
		-h | --help)
			usage
			exit 0
			;;
		--)
			shift
			while [[ $# -gt 0 ]]; do
				positional+=("$1")
				shift
			done
			break
			;;
		-*)
			printf 'Error: unknown option: %s\n' "$1" >&2
			exit 1
			;;
		*)
			positional+=("$1")
			;;
		esac
		shift
	done

	if [[ ${#positional[@]} -gt 2 ]]; then
		printf 'Error: expected at most two positional arguments: model and runs.\n' >&2
		exit 1
	fi

	MODEL="${positional[0]:-}"
	RUNS="${positional[1]:-5}"
	MODEL="$(trim_whitespace "${MODEL}")"
	RUNS="$(trim_whitespace "${RUNS}")"
}

parse_args "$@"

purge_benchmark_root() {
	local home_volatile_root
	local benchmark_prefix
	local resolved_root

	home_volatile_root="$(realpath -m -- "${HOME}/Volatile")"
	benchmark_prefix="${home_volatile_root}/benchmark-models"
	resolved_root="$(realpath -m -- "${VOLATILE_ROOT}")"

	if [[ -z "${resolved_root}" || "${resolved_root}" == '/' || "${resolved_root}" == "${home_volatile_root}" || "${resolved_root}" == "$(realpath -m -- "${HOME}")" ]]; then
		printf 'Error: refusing to purge unsafe root: %s\n' "${resolved_root}" >&2
		exit 1
	fi

	if [[ "${resolved_root}" != "${benchmark_prefix}" && "${resolved_root}" != "${benchmark_prefix}/"* ]]; then
		printf 'Error: purge root must stay within %s, got %s\n' "${benchmark_prefix}" "${resolved_root}" >&2
		exit 1
	fi

	printf 'Purging benchmark root: %s\n' "${resolved_root}"
	if [[ -e "${resolved_root}" ]]; then
		rm -rf -- "${resolved_root}"
		printf 'Removed cached models and caches.\n'
	else
		printf 'Nothing to purge, root does not exist.\n'
	fi
}

if [[ "${PURGE_REQUESTED}" == 'true' ]]; then
	if [[ -n "${MODEL}" ]]; then
		printf 'Error: --purge does not accept model or runs arguments.\n' >&2
		exit 1
	fi
	purge_benchmark_root
	exit 0
fi

if [[ -z "${MODEL}" ]]; then
	usage
	printf '\n'
	list_supported_models
	exit 0
fi

if ! [[ "${RUNS}" =~ ^[0-9]+$ ]] || [[ "${RUNS}" -lt 1 ]]; then
	printf 'Error: runs must be a positive integer.\n' >&2
	exit 1
fi

model_spec_field() {
	local requested_model="$1"
	local field_name="$2"
	local model
	local hf_repo
	local hf_primary_path
	local hf_download_paths

	while IFS='|' read -r model hf_repo hf_primary_path hf_download_paths; do
		model="$(trim_whitespace "${model}")"
		hf_repo="$(trim_whitespace "${hf_repo}")"
		hf_primary_path="$(trim_whitespace "${hf_primary_path}")"
		hf_download_paths="$(trim_whitespace "${hf_download_paths}")"
		if [[ "${model}" == "${requested_model}" ]]; then
			case "${field_name}" in
			repo)
				printf '%s\n' "${hf_repo}"
				return 0
				;;
			primary)
				printf '%s\n' "${hf_primary_path}"
				return 0
				;;
			downloads)
				printf '%s\n' "${hf_download_paths}"
				return 0
				;;
			*)
				printf 'Error: unknown model spec field requested: %s\n' "${field_name}" >&2
				return 1
				;;
			esac
		fi
	done <<<"${MODEL_SPECS}"

	return 1
}

hf_repo_for_model() {
	model_spec_field "$1" repo
}

hf_primary_path_for_model() {
	model_spec_field "$1" primary
}

hf_download_paths_for_model() {
	model_spec_field "$1" downloads
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

validate_model() {
	local hf_download_paths_raw
	local download_path
	local primary_in_downloads='false'
	local -a validated_download_paths=()

	if ! HF_REPO="$(hf_repo_for_model "${MODEL}")"; then
		printf 'Error: unsupported model: %s\n' "${MODEL}" >&2
		printf '\n' >&2
		list_supported_models >&2
		exit 1
	fi

	if [[ -z "${HF_REPO}" ]]; then
		printf 'Error: no Hugging Face mapping defined for supported model: %s\n' "${MODEL}" >&2
		printf '\n' >&2
		list_supported_models >&2
		exit 1
	fi

	if ! HF_PRIMARY_PATH="$(hf_primary_path_for_model "${MODEL}")"; then
		printf 'Error: no GGUF primary path mapping defined for supported model: %s\n' "${MODEL}" >&2
		printf '\n' >&2
		list_supported_models >&2
		exit 1
	fi

	if [[ -z "${HF_PRIMARY_PATH}" ]]; then
		printf 'Error: empty GGUF primary path mapping for supported model: %s\n' "${MODEL}" >&2
		exit 1
	fi

	if [[ "${HF_PRIMARY_PATH}" != *.gguf ]]; then
		printf 'Error: GGUF primary path mapping must end with .gguf for model: %s\n' "${MODEL}" >&2
		exit 1
	fi

	if ! validate_repo_relative_path "${HF_PRIMARY_PATH}"; then
		printf 'Error: GGUF primary path mapping must be repo-relative for model: %s\n' "${MODEL}" >&2
		exit 1
	fi

	if ! hf_download_paths_raw="$(hf_download_paths_for_model "${MODEL}")"; then
		printf 'Error: no GGUF download paths mapping defined for supported model: %s\n' "${MODEL}" >&2
		printf '\n' >&2
		list_supported_models >&2
		exit 1
	fi

	if [[ -z "${hf_download_paths_raw}" ]]; then
		printf 'Error: empty GGUF download paths mapping for supported model: %s\n' "${MODEL}" >&2
		exit 1
	fi

	IFS=',' read -r -a HF_DOWNLOAD_PATHS <<<"${hf_download_paths_raw}"
	if [[ ${#HF_DOWNLOAD_PATHS[@]} -eq 0 ]]; then
		printf 'Error: GGUF download paths mapping must contain at least one path for model: %s\n' "${MODEL}" >&2
		exit 1
	fi

	for download_path in "${HF_DOWNLOAD_PATHS[@]}"; do
		download_path="$(trim_whitespace "${download_path}")"
		if [[ -z "${download_path}" ]]; then
			printf 'Error: GGUF download paths mapping contains an empty path for model: %s\n' "${MODEL}" >&2
			exit 1
		fi
		if [[ "${download_path}" != *.gguf ]]; then
			printf 'Error: GGUF download path must end with .gguf for model: %s\n' "${MODEL}" >&2
			exit 1
		fi
		if ! validate_repo_relative_path "${download_path}"; then
			printf 'Error: GGUF download path must be repo-relative for model: %s\n' "${MODEL}" >&2
			exit 1
		fi
		if [[ "${download_path}" == "${HF_PRIMARY_PATH}" ]]; then
			primary_in_downloads='true'
		fi
		validated_download_paths+=("${download_path}")
	done

	if [[ "${primary_in_downloads}" != 'true' ]]; then
		printf 'Error: GGUF primary path must be included in download paths for model: %s\n' "${MODEL}" >&2
		exit 1
	fi

	HF_DOWNLOAD_PATHS=("${validated_download_paths[@]}")
}

validate_model

mkdir -p \
	"${XDG_ROOT}/cache" \
	"${XDG_ROOT}/config" \
	"${XDG_ROOT}/data" \
	"${HF_ROOT}/hub" \
	"${HF_ROOT}/transformers" \
	"${LLAMA_ROOT}/cache" \
	"${OLLAMA_MODELS_DIR}" \
	"${OLLAMA_RUNTIME_HOME}" \
	"${TMP_ROOT}"

export XDG_CACHE_HOME="${XDG_ROOT}/cache"
export XDG_CONFIG_HOME="${XDG_ROOT}/config"
export XDG_DATA_HOME="${XDG_ROOT}/data"
export HF_HOME="${HF_ROOT}"
export HF_HUB_CACHE="${HF_ROOT}/hub"
export HUGGINGFACE_HUB_CACHE="${HF_HUB_CACHE}"
export TRANSFORMERS_CACHE="${HF_ROOT}/transformers"
export LLAMA_CACHE="${LLAMA_ROOT}/cache"
export TMPDIR="${TMP_ROOT}"

TMPFILE=$(mktemp "${TMPDIR}/benchmark-models.XXXXXX")

cleanup() {
	stop_ollama_server
	rm -f "${TMPFILE}"
}
trap cleanup EXIT

stop_ollama_server() {
	local ollama_pid="${OLLAMA_PID}"
	local attempt

	if [[ -z "${ollama_pid}" ]]; then
		return 0
	fi

	if ! kill -0 "${ollama_pid}" 2>/dev/null; then
		OLLAMA_PID=''
		return 0
	fi

	kill "${ollama_pid}" 2>/dev/null || true
	for ((attempt = 1; attempt <= 20; attempt += 1)); do
		if ! kill -0 "${ollama_pid}" 2>/dev/null; then
			wait "${ollama_pid}" 2>/dev/null || true
			OLLAMA_PID=''
			return 0
		fi
		sleep 0.5
	done

	kill -9 "${ollama_pid}" 2>/dev/null || true
	wait "${ollama_pid}" 2>/dev/null || true
	OLLAMA_PID=''
}

run_ollama() {
	local command_name="$1"
	shift

	env \
		HOME="${OLLAMA_RUNTIME_HOME}" \
		OLLAMA_HOST="${OLLAMA_BIND}" \
		OLLAMA_MODELS="${OLLAMA_MODELS_DIR}" \
		OLLAMA_FLASH_ATTENTION=1 \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		TMPDIR="${TMPDIR}" \
		"${command_name}" "$@"
}

run_hf() {
	env \
		HF_HOME="${HF_HOME}" \
		HF_HUB_CACHE="${HF_HUB_CACHE}" \
		HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE}" \
		TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		TMPDIR="${TMPDIR}" \
		hf "$@"
}

run_llama_backend() {
	env \
		HF_HOME="${HF_HOME}" \
		HF_HUB_CACHE="${HF_HUB_CACHE}" \
		HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE}" \
		TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE}" \
		LLAMA_CACHE="${LLAMA_CACHE}" \
		TMPDIR="${TMPDIR}" \
		"$@"
}

add_runner() {
	RUNNER_LABELS+=("$1")
	RUNNER_TYPES+=("$2")
	RUNNER_COMMANDS+=("$3")
	RUNNER_MEAN+=("")
	RUNNER_MIN+=("")
	RUNNER_MAX+=("")
	RUNNER_SPREAD+=("")
	RUNNER_SKIPPED+=("")
}

prepare_backend_matrix() {
	case "${HOST_COMPUTE_VENDOR}" in
	amd)
		add_runner 'rocm-ollama' 'ollama' 'rocm-ollama'
		add_runner 'vulkan-ollama' 'ollama' 'vulkan-ollama'
		add_runner 'rocm-llama-bench' 'llama.cpp' 'rocm-llama-bench'
		add_runner 'vulkan-llama-bench' 'llama.cpp' 'vulkan-llama-bench'
		;;
	nvidia)
		add_runner 'cuda-ollama' 'ollama' 'cuda-ollama'
		add_runner 'vulkan-ollama' 'ollama' 'vulkan-ollama'
		add_runner 'cuda-llama-bench' 'llama.cpp' 'cuda-llama-bench'
		add_runner 'vulkan-llama-bench' 'llama.cpp' 'vulkan-llama-bench'
		;;
	'')
		BACKEND_MATRIX_REASON='Host compute vendor metadata is unavailable, backend comparison skipped.'
		;;
	*)
		BACKEND_MATRIX_REASON="Host compute vendor '${HOST_COMPUTE_VENDOR}' is not supported for dedicated backend comparison."
		;;
	esac
}

backend_matrix_label() {
	local runner_label
	local label=''

	for runner_label in "${RUNNER_LABELS[@]}"; do
		if [[ -n "${label}" ]]; then
			label+=', '
		fi
		label+="${runner_label}"
	done

	printf '%s' "${label}"
}

first_ollama_command() {
	local index

	for index in "${!RUNNER_COMMANDS[@]}"; do
		if [[ "${RUNNER_TYPES[index]}" == 'ollama' ]]; then
			printf '%s\n' "${RUNNER_COMMANDS[index]}"
			return 0
		fi
	done

	return 1
}

start_ollama_server() {
	rm -f "${OLLAMA_LOG}"
	run_ollama "${OLLAMA_COMMAND}" serve >"${OLLAMA_LOG}" 2>&1 &
	OLLAMA_PID="$!"

	for _ in $(seq 1 30); do
		if curl --silent --fail "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
			return 0
		fi

		if ! kill -0 "${OLLAMA_PID}" 2>/dev/null; then
			printf 'Error: temporary Ollama server exited early.\n' >&2
			printf 'Log: %s\n' "${OLLAMA_LOG}" >&2
			return 1
		fi

		sleep 1
	done

	printf 'Error: timed out waiting for temporary Ollama server at %s.\n' "${OLLAMA_URL}" >&2
	printf 'Log: %s\n' "${OLLAMA_LOG}" >&2
	return 1
}

run_ollama_once() {
	local payload
	local tps

	payload=$(jq -cn \
		--arg model "${MODEL}" \
		--arg prompt "${PROMPT}" \
		'{
		  model: $model,
		  prompt: $prompt,
		  stream: false,
		  options: { num_predict: 512, temperature: 0.0 },
		  think: false
		}')

	tps=$(curl --silent --show-error "${OLLAMA_URL}/api/generate" \
		-d "${payload}" |
		jq -er '(.eval_count / (.eval_duration / 1000000000))')

	printf '%s\n' "${tps}"
}

run_llama_bench_once() {
	local command_name="$1"
	local model_path="$2"
	local output
	local tps

	output=$(run_llama_backend \
		"${command_name}" \
			-m "${model_path}" \
			-ngl 99 \
			-fa 1 \
			--mmap 0 \
			-p 0 \
			-n 512 \
			-r 1 \
			-o jsonl \
		2>/dev/null)

	tps=$(printf '%s' "${output}" | jq -ser '[.[] | select(.n_gen > 0)] | .[0].avg_ts // empty')

	if [[ -z "${tps}" ]]; then
		return 1
	fi

	printf '%s\n' "${tps}"
}

ollama_model_cached() {
	local cached_model

	while read -r cached_model; do
		if [[ "${cached_model}" == "${MODEL}" ]]; then
			return 0
		fi
	done < <(run_ollama "${OLLAMA_COMMAND}" list 2>/dev/null | awk 'NR > 1 { print $1 }')

	return 1
}

resolve_cached_hf_path() {
	local repo_relative_path="$1"
	local repo_cache_dir
	local revision
	local candidate
	local -a candidates=()

	repo_cache_dir="${HF_HUB_CACHE}/models--${HF_REPO//\//--}"

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

calculate_stats() {
	local stats_file="$1"

	awk '{
	  sum += $1
	  if (NR == 1 || $1 < min) min = $1
	  if (NR == 1 || $1 > max) max = $1
	}
	END {
	  mean = sum / NR
	  printf "%.3f|%.3f|%.3f|%.3f\n", mean, min, max, max - min
	}' "${stats_file}"
}

print_intro() {
	printf 'Model benchmark: %s runs\n' "${RUNS}"
	printf -- '- %-10s %s\n' 'Ollama:' "${MODEL}"
	printf -- '- %-10s %s\n\n' 'Llama.cpp:' "${HF_PRIMARY_PATH}"
}

prepare_downloads() {
	local download_path
	local missing_download='false'

	printf 'Preparation\n'

	if [[ -z "${OLLAMA_COMMAND}" ]]; then
		printf 'Error: no Ollama runner is available for preparation.\n' >&2
		exit 1
	fi

	if ollama_model_cached; then
		printf '  [1/2] Ollama model: ready\n'
	else
		printf '  [1/2] Ollama model: pulling\n'
		run_ollama "${OLLAMA_COMMAND}" pull "${MODEL}"
	fi
	printf '\n'

	for download_path in "${HF_DOWNLOAD_PATHS[@]}"; do
		if ! resolve_cached_hf_path "${download_path}" >/dev/null; then
			missing_download='true'
			break
		fi
	done

	if [[ "${missing_download}" == 'false' ]] && HF_MODEL_PATH="$(resolve_cached_hf_path "${HF_PRIMARY_PATH}")"; then
		printf '  [2/2] Hugging Face GGUF: ready\n'
	else
		printf '  [2/2] Hugging Face GGUF: downloading\n'
		for download_path in "${HF_DOWNLOAD_PATHS[@]}"; do
			run_hf download --repo-type model "${HF_REPO}" "${download_path}"
		done
		HF_MODEL_PATH="$(resolve_cached_hf_path "${HF_PRIMARY_PATH}")"
	fi

	if [[ -z "${HF_MODEL_PATH}" ]]; then
		printf 'Error: failed to resolve downloaded GGUF path for %s\n' "${MODEL}" >&2
		exit 1
	fi

	for download_path in "${HF_DOWNLOAD_PATHS[@]}"; do
		if ! resolve_cached_hf_path "${download_path}" >/dev/null; then
			printf 'Error: failed to resolve downloaded GGUF path %s for %s\n' "${download_path}" "${MODEL}" >&2
			exit 1
		fi
	done
	printf '\n'
}

run_backend_benchmark() {
	local index="$1"
	local total_runners="$2"
	local runner_label="${RUNNER_LABELS[index]}"
	local runner_type="${RUNNER_TYPES[index]}"
	local command_name="${RUNNER_COMMANDS[index]}"
	local skipped_reason=""
	local runner_number=$((index + 1))
	local backend_tmpfile
	local tps

	printf '  Runner %s/%s: %s\n' "${runner_number}" "${total_runners}" "${runner_label}"
	printf '    measured runs: %s\n' "${RUNS}"

	if ! command -v "${command_name}" >/dev/null 2>&1; then
		RUNNER_SKIPPED[index]='not found'
		printf '    skipped - %s\n\n' "${RUNNER_SKIPPED[index]}"
		return 0
	fi

	backend_tmpfile=$(mktemp "${TMPDIR}/benchmark-backend.XXXXXX")

	if [[ "${runner_type}" == 'ollama' ]]; then
		restart_ollama_server_for_runner "${command_name}"
	fi

	for run_number in $(seq 1 "${RUNS}"); do
		printf '    run %s/%s... ' "${run_number}" "${RUNS}"
		if [[ "${runner_type}" == 'ollama' ]]; then
			tps=$(run_ollama_once)
		else
			tps=$(run_llama_bench_once "${command_name}" "${HF_MODEL_PATH}")
		fi

		if [[ -n "${tps:-}" ]]; then
			printf '%.3f tok/s\n' "${tps}"
			printf '%s\n' "${tps}" >>"${backend_tmpfile}"
		else
			printf 'failed\n'
		fi
	done

	if [[ ! -s "${backend_tmpfile}" ]]; then
		skipped_reason='no usable tg results'
	else
		IFS='|' read -r stats_mean stats_min stats_max stats_spread <<<"$(calculate_stats "${backend_tmpfile}")"
		RUNNER_MEAN[index]="${stats_mean}"
		RUNNER_MIN[index]="${stats_min}"
		RUNNER_MAX[index]="${stats_max}"
		RUNNER_SPREAD[index]="${stats_spread}"
	fi

	rm -f "${backend_tmpfile}"

	RUNNER_SKIPPED[index]="${skipped_reason}"
	if [[ -n "${skipped_reason}" ]]; then
		printf '    skipped - %s\n' "${skipped_reason}"
	fi
	printf '\n'
}

restart_ollama_server_for_runner() {
	local command_name="$1"

	if [[ "${OLLAMA_COMMAND}" == "${command_name}" ]] && [[ -n "${OLLAMA_PID}" ]] && kill -0 "${OLLAMA_PID}" 2>/dev/null; then
		return 0
	fi

	stop_ollama_server
	OLLAMA_COMMAND="${command_name}"
	start_ollama_server
}

run_all_benchmarks() {
	local index
	local total_runners="$1"
	local ollama_stopped='false'

	for index in "${!RUNNER_COMMANDS[@]}"; do
		if [[ "${RUNNER_TYPES[index]}" != 'ollama' ]] && [[ "${ollama_stopped}" == 'false' ]]; then
			stop_ollama_server
			ollama_stopped='true'
		fi

		run_backend_benchmark "${index}" "${total_runners}"
	done
}

print_results() {
	local index

	printf 'Results\n'
	printf '  %-20s %12s  %s\n' 'Runner' 'Mean tok/s' 'Notes'

	if [[ ${#RUNNER_COMMANDS[@]} -eq 0 ]]; then
		printf '  %-20s %12s  %s\n' 'Host backends' 'skipped' "${BACKEND_MATRIX_REASON}"
	else
		for index in "${!RUNNER_COMMANDS[@]}"; do
			if [[ -n "${RUNNER_SKIPPED[index]}" ]]; then
				printf '  %-20s %12s  %s\n' "${RUNNER_LABELS[index]}" 'skipped' "${RUNNER_SKIPPED[index]}"
			else
				printf '  %-20s %12.3f  min %.3f, max %.3f, spread %.3f\n' "${RUNNER_LABELS[index]}" "${RUNNER_MEAN[index]}" "${RUNNER_MIN[index]}" "${RUNNER_MAX[index]}" "${RUNNER_SPREAD[index]}"
			fi
		done
	fi

	printf '\n'
}

print_deltas() {
	local index
	local pair_backend
	local ollama_index
	local llama_index
	local fastest_index=''
	local slowest_index=''
	local printed='false'
	local delta_backend
	local direction

	print_delta_line() {
		local line_label="$1"
		local left_label="$2"
		local right_label="$3"
		local left_mean="$4"
		local right_mean="$5"

		delta_backend=$(awk "BEGIN { printf \"%.3f\", ${left_mean} - ${right_mean} }")
		if awk "BEGIN { exit (${left_mean} >= ${right_mean}) ? 1 : 0 }"; then
			direction="${right_label} faster"
		else
			direction="${left_label} faster"
		fi

		printf '  %-34s %+9.3f tok/s  (%s)\n' "${line_label}" "${delta_backend}" "${direction}"
	}

	for index in "${!RUNNER_COMMANDS[@]}"; do
		if [[ -z "${RUNNER_MEAN[index]}" ]]; then
			continue
		fi

		if [[ -z "${fastest_index}" ]] || awk "BEGIN { exit (${RUNNER_MEAN[index]} > ${RUNNER_MEAN[fastest_index]}) ? 0 : 1 }"; then
			fastest_index="${index}"
		fi

		if [[ -z "${slowest_index}" ]] || awk "BEGIN { exit (${RUNNER_MEAN[index]} < ${RUNNER_MEAN[slowest_index]}) ? 0 : 1 }"; then
			slowest_index="${index}"
		fi
	done

	for pair_backend in rocm cuda vulkan; do
		ollama_index=''
		llama_index=''

		for index in "${!RUNNER_COMMANDS[@]}"; do
			if [[ -z "${RUNNER_MEAN[index]}" ]]; then
				continue
			fi

			case "${RUNNER_LABELS[index]}" in
			"${pair_backend}-ollama")
				ollama_index="${index}"
				;;
			"${pair_backend}-llama-bench")
				llama_index="${index}"
				;;
			esac
		done

		if [[ -n "${ollama_index}" && -n "${llama_index}" ]]; then
			if [[ "${printed}" == 'false' ]]; then
				printf 'Deltas\n'
				printed='true'
			fi

			print_delta_line \
				"${RUNNER_LABELS[llama_index]} vs ${RUNNER_LABELS[ollama_index]}" \
				"${RUNNER_LABELS[llama_index]}" \
				"${RUNNER_LABELS[ollama_index]}" \
				"${RUNNER_MEAN[llama_index]}" \
				"${RUNNER_MEAN[ollama_index]}"
		fi
	done

	if [[ -n "${fastest_index}" && -n "${slowest_index}" ]]; then
		if [[ "${printed}" == 'false' ]]; then
			printf 'Deltas\n'
			printed='true'
		fi

		print_delta_line \
			'fastest vs slowest' \
			"${RUNNER_LABELS[fastest_index]}" \
			"${RUNNER_LABELS[slowest_index]}" \
			"${RUNNER_MEAN[fastest_index]}" \
			"${RUNNER_MEAN[slowest_index]}"
	fi

	if [[ "${printed}" == 'true' ]]; then
		printf '\n'
	fi
}

prepare_backend_matrix

print_intro

if [[ ${#RUNNER_COMMANDS[@]} -eq 0 ]]; then
	printf 'Benchmark\n'
	printf '  Runners: skipped\n'
	printf '  Host backends: skipped - %s\n\n' "${BACKEND_MATRIX_REASON}"
	print_results
	exit 0
fi

OLLAMA_COMMAND="$(first_ollama_command)"
start_ollama_server
prepare_downloads

printf 'Benchmark\n'
if [[ ${#RUNNER_COMMANDS[@]} -gt 0 ]]; then
	printf '  Runners: %s\n' "$(backend_matrix_label)"
else
	printf '  Runners: skipped\n'
	printf '  Host backends: skipped - %s\n' "${BACKEND_MATRIX_REASON}"
fi
printf '\n'

if [[ ${#RUNNER_COMMANDS[@]} -eq 0 ]]; then
	:
else
	run_all_benchmarks "${#RUNNER_COMMANDS[@]}"
fi

print_results
print_deltas
