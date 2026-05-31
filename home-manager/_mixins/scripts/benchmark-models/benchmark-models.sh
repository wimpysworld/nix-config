#!/usr/bin/env bash
# benchmark-models.sh

set -euo pipefail

GENERATION_PROMPT="Write a concise Python function named summarise_log(lines) that counts INFO, WARNING, and ERROR entries, ignores malformed lines, and returns a dict. Include a short example."
GENERATION_MAX_TOKENS="512"
PROMPT_BENCH_TOKENS="512"
EMBEDDING_BENCH_TEXT="Optical fibre uses pulses of light to carry data through thin strands of glass or plastic. Modern systems rely on wavelength multiplexing, amplification, and low-loss transmission to move large volumes of traffic over long distances."
EMBEDDING_BENCH_BATCH="16"
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
	qwen3.6:27b|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q4_K_XL.gguf|Qwen3.6-27B-UD-Q4_K_XL.gguf
	qwen3.6-mtp:27b|unsloth/Qwen3.6-27B-MTP-GGUF|Qwen3.6-27B-UD-Q4_K_XL.gguf|Qwen3.6-27B-UD-Q4_K_XL.gguf
	qwen3.6:35b|unsloth/Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf|Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
	qwen3.6-mtp:35b|unsloth/Qwen3.6-35B-A3B-MTP-GGUF|Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf|Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
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
LLAMA_SERVER_BIND="127.0.0.1:18080"
LLAMA_SERVER_URL="http://${LLAMA_SERVER_BIND}"
TMPFILE=""
OLLAMA_PID=""
OLLAMA_COMMAND=""
LLAMA_SERVER_PID=""
HF_REPO=""
HF_PRIMARY_PATH=""
HF_MODEL_PATH=""
MODEL=""
MODEL_KIND="generation"
MTP_MODEL='false'
MTP_DRAFT_N_MAX="${BENCHMARK_MODELS_MTP_DRAFT_N_MAX:-2}"
RUNS="5"
PURGE_REQUESTED='false'
HOST_COMPUTE_VENDOR="${BENCHMARK_MODELS_HOST_GPU_COMPUTE_VENDOR:-}"
BACKEND_MATRIX_REASON=""
PRIMARY_METRIC_LABEL=""
SECONDARY_METRIC_LABEL=""
BOLD="$(printf '\033[1m')"
RESET="$(printf '\033[0m')"
declare -a RUNNER_LABELS=()
declare -a RUNNER_TYPES=()
declare -a RUNNER_COMMANDS=()
declare -a RUNNER_MEAN=()
declare -a RUNNER_MIN=()
declare -a RUNNER_MAX=()
declare -a RUNNER_SPREAD=()
declare -a RUNNER_SECONDARY_MEAN=()
declare -a RUNNER_SECONDARY_MIN=()
declare -a RUNNER_SECONDARY_MAX=()
declare -a RUNNER_SECONDARY_SPREAD=()
declare -a RUNNER_SKIPPED=()
declare -a HF_DOWNLOAD_PATHS=()

usage() {
	cat <<'EOF'
Usage: benchmark-models [--purge] [model] [runs]

Benchmarks one model across supported Ollama and host-specific llama.cpp backends.

Arguments:
  model   Benchmark model alias, example: qwen3.6:35b
  runs    Number of measured runs, default: 5

Options:
  --purge  Remove the benchmark-models volatile root, then exit
  -h, --help
           Show this help text

Backend matrix:
  AMD      rocm-ollama, vulkan-ollama, rocm-llama-bench or rocm-llama-server
  NVIDIA   cuda-ollama, vulkan-ollama, cuda-llama-bench or cuda-llama-server

Environment:
  BENCHMARK_MODELS_ROOT        Root directory for caches under ~/Volatile
  BENCHMARK_MODELS_OLLAMA_HOST Host:port for the temporary Ollama server
  BENCHMARK_MODELS_MTP_DRAFT_N_MAX
                               MTP draft tokens for llama.cpp generation, 1-6, default: 2
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

configure_benchmark_mode() {
	case "${HF_REPO}" in
	*Embedding* | *embedding*)
		MODEL_KIND='embedding'
		PRIMARY_METRIC_LABEL='Chars/s'
		SECONDARY_METRIC_LABEL='Docs/s'
		;;
	*)
		MODEL_KIND='generation'
		PRIMARY_METRIC_LABEL='Decode tok/s'
		SECONDARY_METRIC_LABEL='Prompt tok/s'
		;;
	esac
}

configure_mtp_mode() {
	case "${MODEL}" in
	qwen3.6-mtp:*)
		MTP_MODEL='true'
		;;
	*)
		MTP_MODEL='false'
		;;
	esac

	if [[ "${MTP_MODEL}" != 'true' ]]; then
		return 0
	fi

	MTP_DRAFT_N_MAX="$(trim_whitespace "${MTP_DRAFT_N_MAX}")"
	if ! [[ "${MTP_DRAFT_N_MAX}" =~ ^[1-6]$ ]]; then
		printf 'Error: BENCHMARK_MODELS_MTP_DRAFT_N_MAX must be an integer from 1 to 6.\n' >&2
		exit 1
	fi
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
configure_benchmark_mode
configure_mtp_mode

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
	stop_llama_server
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

stop_llama_server() {
	local llama_server_pid="${LLAMA_SERVER_PID}"
	local attempt

	if [[ -z "${llama_server_pid}" ]]; then
		return 0
	fi

	if ! kill -0 "${llama_server_pid}" 2>/dev/null; then
		LLAMA_SERVER_PID=''
		return 0
	fi

	kill "${llama_server_pid}" 2>/dev/null || true
	for ((attempt = 1; attempt <= 20; attempt += 1)); do
		if ! kill -0 "${llama_server_pid}" 2>/dev/null; then
			wait "${llama_server_pid}" 2>/dev/null || true
			LLAMA_SERVER_PID=''
			return 0
		fi
		sleep 0.5
	done

	kill -9 "${llama_server_pid}" 2>/dev/null || true
	wait "${llama_server_pid}" 2>/dev/null || true
	LLAMA_SERVER_PID=''
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

generate_embedding_inputs_json() {
	jq -cn \
		--arg text "${EMBEDDING_BENCH_TEXT}" \
		--argjson count "${EMBEDDING_BENCH_BATCH}" \
		'[range(0; $count) | $text]'
}

embedding_total_chars() {
	printf '%s' "${EMBEDDING_BENCH_TEXT}" | awk -v count="${EMBEDDING_BENCH_BATCH}" '{ printf "%d", length($0) * count }'
}

add_runner() {
	RUNNER_LABELS+=("$1")
	RUNNER_TYPES+=("$2")
	RUNNER_COMMANDS+=("$3")
	RUNNER_MEAN+=("")
	RUNNER_MIN+=("")
	RUNNER_MAX+=("")
	RUNNER_SPREAD+=("")
	RUNNER_SECONDARY_MEAN+=("")
	RUNNER_SECONDARY_MIN+=("")
	RUNNER_SECONDARY_MAX+=("")
	RUNNER_SECONDARY_SPREAD+=("")
	RUNNER_SKIPPED+=("")
}

prepare_backend_matrix() {
	case "${HOST_COMPUTE_VENDOR}" in
	amd)
		if [[ "${MTP_MODEL}" != 'true' ]]; then
			add_runner 'rocm-ollama' 'ollama' 'rocm-ollama'
			add_runner 'vulkan-ollama' 'ollama' 'vulkan-ollama'
		fi
		if [[ "${MODEL_KIND}" == 'embedding' || "${MTP_MODEL}" == 'true' ]]; then
			add_runner 'rocm-llama-server' 'llama-server' 'rocm-llama-server'
			add_runner 'vulkan-llama-server' 'llama-server' 'vulkan-llama-server'
		else
			add_runner 'rocm-llama-bench' 'llama.cpp' 'rocm-llama-bench'
			add_runner 'vulkan-llama-bench' 'llama.cpp' 'vulkan-llama-bench'
		fi
		;;
	nvidia)
		if [[ "${MTP_MODEL}" != 'true' ]]; then
			add_runner 'cuda-ollama' 'ollama' 'cuda-ollama'
			add_runner 'vulkan-ollama' 'ollama' 'vulkan-ollama'
		fi
		if [[ "${MODEL_KIND}" == 'embedding' || "${MTP_MODEL}" == 'true' ]]; then
			add_runner 'cuda-llama-server' 'llama-server' 'cuda-llama-server'
			add_runner 'vulkan-llama-server' 'llama-server' 'vulkan-llama-server'
		else
			add_runner 'cuda-llama-bench' 'llama.cpp' 'cuda-llama-bench'
			add_runner 'vulkan-llama-bench' 'llama.cpp' 'vulkan-llama-bench'
		fi
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
	local max_tokens="${1:-${GENERATION_MAX_TOKENS}}"
	local payload
	local metrics

	payload=$(jq -cn \
		--arg model "${MODEL}" \
		--arg prompt "${GENERATION_PROMPT}" \
		--argjson max_tokens "${max_tokens}" \
		'{
		  model: $model,
		  prompt: $prompt,
		  stream: false,
		  options: { num_predict: $max_tokens, temperature: 0.0 },
		  think: false
		}')

	metrics=$(curl --silent --show-error "${OLLAMA_URL}/api/generate" \
		-d "${payload}" |
		jq -er '[
			(if (.eval_duration // 0) > 0 then (.eval_count / (.eval_duration / 1000000000)) else 0 end),
			(if (.prompt_eval_duration // 0) > 0 then (.prompt_eval_count / (.prompt_eval_duration / 1000000000)) else 0 end)
		] | @tsv')

	printf '%s\n' "${metrics}"
}

run_llama_bench_warmup() {
	local command_name="$1"
	local model_path="$2"
	local log_path="$3"

	run_llama_backend \
		"${command_name}" \
		-m "${model_path}" \
		-ngl 99 \
		-fa 1 \
		--mmap 0 \
		-p "${PROMPT_BENCH_TOKENS}" \
		-n 1 \
		-r 1 \
		-o jsonl \
		>"${log_path}" \
		2>&1
}

llama_bench_jsonl() {
	awk '/^[[:space:]]*\{/ { print }'
}

print_warmup_log() {
	local log_path="$1"
	local line_count='12'

	printf '    log: %s\n' "${log_path}"
	if [[ ! -s "${log_path}" ]]; then
		return 0
	fi

	printf '    last log lines:\n'
	awk -v count="${line_count}" '
	{
		lines[NR % count] = $0
	}
	END {
		start = NR > count ? NR - count + 1 : 1
		for (line = start; line <= NR; line += 1) {
			printf "      %s\n", lines[line % count]
		}
	}' "${log_path}"
}

run_llama_bench_once() {
	local command_name="$1"
	local model_path="$2"
	local decode_output
	local prompt_output
	local decode_tps
	local prompt_tps

	decode_output=$(run_llama_backend \
		"${command_name}" \
		-m "${model_path}" \
		-ngl 99 \
		-fa 1 \
		--mmap 0 \
		-p 0 \
		-n "${GENERATION_MAX_TOKENS}" \
		-r 1 \
		-o jsonl \
		2>/dev/null)

	decode_tps=$(printf '%s' "${decode_output}" | llama_bench_jsonl | jq -ser '[.[] | select(.n_gen > 0)] | .[0].avg_ts // empty')
	if [[ -z "${decode_tps}" ]]; then
		return 1
	fi

	prompt_output=$(run_llama_backend \
		"${command_name}" \
		-m "${model_path}" \
		-ngl 99 \
		-fa 1 \
		--mmap 0 \
		-p "${PROMPT_BENCH_TOKENS}" \
		-n 0 \
		-r 1 \
		-o jsonl \
		2>/dev/null)

	prompt_tps=$(printf '%s' "${prompt_output}" | llama_bench_jsonl | jq -ser '[.[] | select(.n_prompt > 0 and .n_gen == 0)] | .[0].avg_ts // empty')
	if [[ -z "${prompt_tps}" ]]; then
		return 1
	fi

	printf '%s\t%s\n' "${decode_tps}" "${prompt_tps}"
}

llama_server_mode() {
	if [[ "${MODEL_KIND}" == 'embedding' ]]; then
		printf 'embedding\n'
	elif [[ "${MTP_MODEL}" == 'true' ]]; then
		printf 'mtp-generation\n'
	else
		printf 'generation\n'
	fi
}

start_llama_server() {
	local command_name="$1"
	local mode="${2:-embedding}"
	local log_path="${3:-${TMPFILE}.llama-server.log}"
	local -a server_args=(
		--model "${HF_MODEL_PATH}"
		--host 127.0.0.1
		--port 18080
		-fa on
		--no-mmap
	)

	case "${mode}" in
	embedding)
		server_args+=(--embeddings --pooling last)
		;;
	mtp-generation)
		server_args+=(
			-ngl 99
			-c 8192
			-np 1
			--no-mmproj
			--spec-type draft-mtp
			--spec-draft-n-max "${MTP_DRAFT_N_MAX}"
		)
		;;
	generation)
		server_args+=(
			-ngl 99
			-c 8192
			-np 1
		)
		;;
	*)
		printf 'Error: unsupported llama-server mode: %s\n' "${mode}" >&2
		return 1
		;;
	esac

	rm -f "${log_path}"
	run_llama_backend \
		"${command_name}" \
		"${server_args[@]}" >"${log_path}" 2>&1 &
	LLAMA_SERVER_PID="$!"

	for _ in $(seq 1 60); do
		if curl --silent --fail "${LLAMA_SERVER_URL}/health" >/dev/null 2>&1; then
			return 0
		fi

		if ! kill -0 "${LLAMA_SERVER_PID}" 2>/dev/null; then
			printf 'Error: temporary llama-server exited early.\n' >&2
			printf 'Log: %s\n' "${log_path}" >&2
			return 1
		fi

		sleep 1
	done

	printf 'Error: timed out waiting for temporary llama-server at %s.\n' "${LLAMA_SERVER_URL}" >&2
	printf 'Log: %s\n' "${log_path}" >&2
	return 1
}

restart_llama_server_for_runner() {
	local command_name="$1"
	local mode="${2:-embedding}"
	local log_path="${3:-${TMPFILE}.llama-server.log}"

	stop_llama_server
	start_llama_server "${command_name}" "${mode}" "${log_path}"
}

run_ollama_embedding_once() {
	local payload
	local embedding_inputs_json
	local response
	local start_ns
	local end_ns
	local elapsed_ns
	local total_chars
	local chars_per_second
	local docs_per_second

	embedding_inputs_json="$(generate_embedding_inputs_json)"
	payload=$(jq -cn \
		--arg model "${MODEL}" \
		--argjson input "${embedding_inputs_json}" \
		'{
		  model: $model,
		  input: $input
		}')

	start_ns=$(date +%s%N)
	response=$(curl --silent --show-error "${OLLAMA_URL}/api/embed" -d "${payload}")
	end_ns=$(date +%s%N)

	jq -e '.embeddings | length > 0' >/dev/null <<<"${response}"

	elapsed_ns=$((end_ns - start_ns))
	total_chars="$(embedding_total_chars)"
	chars_per_second=$(awk "BEGIN { printf \"%.6f\", ${total_chars} / (${elapsed_ns} / 1000000000) }")
	docs_per_second=$(awk "BEGIN { printf \"%.6f\", ${EMBEDDING_BENCH_BATCH} / (${elapsed_ns} / 1000000000) }")

	printf '%s\t%s\n' "${chars_per_second}" "${docs_per_second}"
}

run_llama_server_embedding_once() {
	local payload
	local embedding_inputs_json
	local response
	local start_ns
	local end_ns
	local elapsed_ns
	local total_chars
	local chars_per_second
	local docs_per_second

	embedding_inputs_json="$(generate_embedding_inputs_json)"
	payload=$(jq -cn \
		--argjson input "${embedding_inputs_json}" \
		'{
		  input: $input,
		  model: "embedding-benchmark"
		}')

	start_ns=$(date +%s%N)
	response=$(curl --silent --show-error "${LLAMA_SERVER_URL}/v1/embeddings" \
		-H 'Content-Type: application/json' \
		-H 'Authorization: Bearer no-key' \
		-d "${payload}")
	end_ns=$(date +%s%N)

	jq -e '.data | length > 0' >/dev/null <<<"${response}"

	elapsed_ns=$((end_ns - start_ns))
	total_chars="$(embedding_total_chars)"
	chars_per_second=$(awk "BEGIN { printf \"%.6f\", ${total_chars} / (${elapsed_ns} / 1000000000) }")
	docs_per_second=$(awk "BEGIN { printf \"%.6f\", ${EMBEDDING_BENCH_BATCH} / (${elapsed_ns} / 1000000000) }")

	printf '%s\t%s\n' "${chars_per_second}" "${docs_per_second}"
}

run_llama_server_generation_once() {
	local max_tokens="${1:-${GENERATION_MAX_TOKENS}}"
	local payload
	local response
	local metrics

	payload=$(jq -cn \
		--arg prompt "${GENERATION_PROMPT}" \
		--argjson max_tokens "${max_tokens}" \
		'{
		  prompt: $prompt,
		  n_predict: $max_tokens,
		  stream: false,
		  timings_per_token: true,
		  cache_prompt: false,
		  temperature: 0.0,
		  seed: 0
		}')

	if ! response=$(curl --silent --show-error --fail "${LLAMA_SERVER_URL}/completion" \
		-H 'Content-Type: application/json' \
		-d "${payload}"); then
		printf 'Error: llama-server /completion request failed.\n' >&2
		return 1
	fi

	if ! metrics=$(jq -er '
		def rate($direct; $tokens; $ms):
			if ($direct // 0) > 0 then
				$direct
			elif (($tokens // 0) > 0 and ($ms // 0) > 0) then
				($tokens / ($ms / 1000))
			else
				empty
			end;
		rate(.timings.predicted_per_second; .timings.predicted_n; .timings.predicted_ms) as $decode |
		rate(.timings.prompt_per_second; .timings.prompt_n; .timings.prompt_ms) as $prompt |
		[$decode, $prompt] | @tsv
	' <<<"${response}"); then
		printf 'Error: failed to parse llama-server /completion timings.\n' >&2
		printf 'Response: %s\n' "${response}" >&2
		return 1
	fi

	printf '%s\n' "${metrics}"
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
	printf -- '- %-10s %s\n' 'Mode:' "${MODEL_KIND}"
	if [[ "${MTP_MODEL}" == 'true' ]]; then
		printf -- '- %-10s skipped, MTP requires llama-server MTP flags\n' 'Ollama:'
		printf -- '- %-10s --spec-type draft-mtp --spec-draft-n-max %s\n' 'MTP:' "${MTP_DRAFT_N_MAX}"
	else
		printf -- '- %-10s %s\n' 'Ollama:' "${MODEL}"
	fi
	printf -- '- %-10s %s\n' 'Llama.cpp:' "${HF_PRIMARY_PATH}"

	if [[ "${MODEL_KIND}" == 'generation' ]]; then
		printf -- '- %-10s %s\n' 'Prompt:' "${GENERATION_PROMPT}"
		if [[ "${MTP_MODEL}" == 'true' ]]; then
			printf -- '- %-10s %s output tokens, prompt timing from request prompt\n\n' 'Metrics:' "${GENERATION_MAX_TOKENS}"
		else
			printf -- '- %-10s %s output tokens, %s-token synthetic pp test\n\n' 'Metrics:' "${GENERATION_MAX_TOKENS}" "${PROMPT_BENCH_TOKENS}"
		fi
	else
		printf -- '- %-10s %s documents x %s characters\n\n' 'Batch:' "${EMBEDDING_BENCH_BATCH}" "${#EMBEDDING_BENCH_TEXT}"
	fi
}

prepare_downloads() {
	local download_path
	local hf_step='2'
	local total_steps='2'
	local missing_download='false'

	printf 'Preparation\n'

	if [[ "${MTP_MODEL}" == 'true' ]]; then
		hf_step='1'
		total_steps='1'
		printf '  [skip] Ollama model: skipped, MTP requires llama-server MTP flags\n'
	elif [[ -z "${OLLAMA_COMMAND}" ]]; then
		printf 'Error: no Ollama runner is available for preparation.\n' >&2
		exit 1
	elif ollama_model_cached; then
		printf '  [1/2] Ollama model: ready\n'
	else
		printf '  [1/2] Ollama model: pulling\n'
		run_ollama "${OLLAMA_COMMAND}" pull "${MODEL}"
	fi

	for download_path in "${HF_DOWNLOAD_PATHS[@]}"; do
		if ! resolve_cached_hf_path "${download_path}" >/dev/null; then
			missing_download='true'
			break
		fi
	done

	if [[ "${missing_download}" == 'false' ]] && HF_MODEL_PATH="$(resolve_cached_hf_path "${HF_PRIMARY_PATH}")"; then
		printf '  [%s/%s] Hugging Face GGUF: ready\n' "${hf_step}" "${total_steps}"
	else
		printf '  [%s/%s] Hugging Face GGUF: downloading\n' "${hf_step}" "${total_steps}"
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
	local secondary_tmpfile
	local warmup_log
	local metrics
	local primary_metric
	local secondary_metric
	local server_log
	local server_mode

	printf '  Runner %s/%s: %s\n' "${runner_number}" "${total_runners}" "${runner_label}"
	printf '    measured runs: %s\n' "${RUNS}"

	if ! command -v "${command_name}" >/dev/null 2>&1; then
		RUNNER_SKIPPED[index]='not found'
		printf '    skipped - %s\n\n' "${RUNNER_SKIPPED[index]}"
		return 0
	fi

	backend_tmpfile=$(mktemp "${TMPDIR}/benchmark-backend.XXXXXX")
	secondary_tmpfile=$(mktemp "${TMPDIR}/benchmark-backend-secondary.XXXXXX")

	if [[ "${runner_type}" == 'ollama' ]]; then
		if ! restart_ollama_server_for_runner "${command_name}"; then
			skipped_reason="server failed, see ${OLLAMA_LOG}"
			RUNNER_SKIPPED[index]="${skipped_reason}"
			rm -f "${backend_tmpfile}" "${secondary_tmpfile}"
			printf '    skipped - %s\n\n' "${skipped_reason}"
			return 0
		fi

		if [[ "${MODEL_KIND}" == 'embedding' ]]; then
			warmup_log=$(mktemp "${TMPDIR}/benchmark-${runner_label}-warmup.XXXXXX")
			if ! run_ollama_embedding_once >"${warmup_log}" 2>&1; then
				skipped_reason="warm-up failed, see ${warmup_log}"
				RUNNER_SKIPPED[index]="${skipped_reason}"
				print_warmup_log "${warmup_log}"
				rm -f "${backend_tmpfile}" "${secondary_tmpfile}"
				printf '    skipped - %s\n\n' "${skipped_reason}"
				return 0
			fi
			rm -f "${warmup_log}"
		else
			printf '    warm-up... '
			warmup_log=$(mktemp "${TMPDIR}/benchmark-${runner_label}-warmup.XXXXXX")
			if ! run_ollama_once 1 >"${warmup_log}" 2>&1; then
				skipped_reason="warm-up failed, see ${warmup_log}"
				RUNNER_SKIPPED[index]="${skipped_reason}"
				printf 'failed\n'
				print_warmup_log "${warmup_log}"
				rm -f "${backend_tmpfile}" "${secondary_tmpfile}"
				printf '    skipped - %s\n\n' "${skipped_reason}"
				return 0
			fi
			rm -f "${warmup_log}"
			printf 'done\n'
		fi
	elif [[ "${runner_type}" == 'llama-server' ]]; then
		server_mode="$(llama_server_mode)"
		server_log="${TMPFILE}.${runner_label}.llama-server.log"
		if ! restart_llama_server_for_runner "${command_name}" "${server_mode}" "${server_log}"; then
			skipped_reason="server failed, see ${server_log}"
			RUNNER_SKIPPED[index]="${skipped_reason}"
			rm -f "${backend_tmpfile}" "${secondary_tmpfile}"
			printf '    skipped - %s\n\n' "${skipped_reason}"
			return 0
		fi

		warmup_log=$(mktemp "${TMPDIR}/benchmark-${runner_label}-warmup.XXXXXX")
		if [[ "${server_mode}" == 'embedding' ]]; then
			if ! run_llama_server_embedding_once >"${warmup_log}" 2>&1; then
				skipped_reason="warm-up failed, see ${warmup_log}"
				RUNNER_SKIPPED[index]="${skipped_reason}"
				print_warmup_log "${warmup_log}"
				rm -f "${backend_tmpfile}" "${secondary_tmpfile}"
				printf '    skipped - %s\n\n' "${skipped_reason}"
				return 0
			fi
		else
			printf '    warm-up... '
			if ! run_llama_server_generation_once 1 >"${warmup_log}" 2>&1; then
				skipped_reason="warm-up failed, see ${warmup_log}"
				RUNNER_SKIPPED[index]="${skipped_reason}"
				printf 'failed\n'
				print_warmup_log "${warmup_log}"
				rm -f "${backend_tmpfile}" "${secondary_tmpfile}"
				printf '    skipped - %s\n\n' "${skipped_reason}"
				return 0
			fi
			printf 'done\n'
		fi
		rm -f "${warmup_log}"
	elif [[ "${runner_type}" == 'llama.cpp' ]]; then
		printf '    warm-up... '
		warmup_log=$(mktemp "${TMPDIR}/benchmark-${runner_label}-warmup.XXXXXX")
		if ! run_llama_bench_warmup "${command_name}" "${HF_MODEL_PATH}" "${warmup_log}"; then
			skipped_reason="warm-up failed, see ${warmup_log}"
			RUNNER_SKIPPED[index]="${skipped_reason}"
			printf 'failed\n'
			print_warmup_log "${warmup_log}"
			rm -f "${backend_tmpfile}" "${secondary_tmpfile}"
			printf '    skipped - %s\n\n' "${skipped_reason}"
			return 0
		fi
		rm -f "${warmup_log}"
		printf 'done\n'
	fi

	for run_number in $(seq 1 "${RUNS}"); do
		printf '    run %s/%s... ' "${run_number}" "${RUNS}"
		if [[ "${MODEL_KIND}" == 'embedding' ]]; then
			if [[ "${runner_type}" == 'ollama' ]]; then
				if ! metrics=$(run_ollama_embedding_once); then
					metrics=''
				fi
			else
				if ! metrics=$(run_llama_server_embedding_once); then
					metrics=''
				fi
			fi
		else
			if [[ "${runner_type}" == 'ollama' ]]; then
				if ! metrics=$(run_ollama_once); then
					metrics=''
				fi
			elif [[ "${runner_type}" == 'llama-server' ]]; then
				if ! metrics=$(run_llama_server_generation_once); then
					metrics=''
				fi
			else
				if ! metrics=$(run_llama_bench_once "${command_name}" "${HF_MODEL_PATH}"); then
					metrics=''
				fi
			fi
		fi

		if [[ -n "${metrics:-}" ]]; then
			IFS=$'\t' read -r primary_metric secondary_metric <<<"${metrics}"
			printf '%.3f %s, %.3f %s\n' "${primary_metric}" "${PRIMARY_METRIC_LABEL}" "${secondary_metric}" "${SECONDARY_METRIC_LABEL}"
			printf '%s\n' "${primary_metric}" >>"${backend_tmpfile}"
			printf '%s\n' "${secondary_metric}" >>"${secondary_tmpfile}"
		else
			printf 'failed\n'
		fi
	done

	if [[ ! -s "${backend_tmpfile}" ]] || [[ ! -s "${secondary_tmpfile}" ]]; then
		skipped_reason="no usable ${PRIMARY_METRIC_LABEL} results"
	else
		IFS='|' read -r stats_mean stats_min stats_max stats_spread <<<"$(calculate_stats "${backend_tmpfile}")"
		RUNNER_MEAN[index]="${stats_mean}"
		RUNNER_MIN[index]="${stats_min}"
		RUNNER_MAX[index]="${stats_max}"
		RUNNER_SPREAD[index]="${stats_spread}"
		IFS='|' read -r stats_mean stats_min stats_max stats_spread <<<"$(calculate_stats "${secondary_tmpfile}")"
		RUNNER_SECONDARY_MEAN[index]="${stats_mean}"
		RUNNER_SECONDARY_MIN[index]="${stats_min}"
		RUNNER_SECONDARY_MAX[index]="${stats_max}"
		RUNNER_SECONDARY_SPREAD[index]="${stats_spread}"
	fi

	rm -f "${backend_tmpfile}"
	rm -f "${secondary_tmpfile}"

	RUNNER_SKIPPED[index]="${skipped_reason}"
	if [[ -n "${skipped_reason}" ]]; then
		printf '    skipped - %s\n' "${skipped_reason}"
	else
		printf '%s    mean %13.3f %s, %.3f %s%s\n' \
			"${BOLD}" \
			"${RUNNER_MEAN[index]}" \
			"${PRIMARY_METRIC_LABEL}" \
			"${RUNNER_SECONDARY_MEAN[index]}" \
			"${SECONDARY_METRIC_LABEL}" \
			"${RESET}"
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
	local last_index

	printf 'Results\n'
	last_index=$((${#RUNNER_COMMANDS[@]} - 1))

	if [[ ${#RUNNER_COMMANDS[@]} -eq 0 ]]; then
		printf '  Host backends: skipped\n'
		printf '    Reason: %s\n' "${BACKEND_MATRIX_REASON}"
	else
		for index in "${!RUNNER_COMMANDS[@]}"; do
			if [[ -n "${RUNNER_SKIPPED[index]}" ]]; then
				printf '  %s: skipped\n' "${RUNNER_LABELS[index]}"
				printf '    Reason: %s\n' "${RUNNER_SKIPPED[index]}"
			else
				printf '  %s\n' "${RUNNER_LABELS[index]}"
				printf '    %-16s %8s %10.3f %8s %10.3f %8s %10.3f\n' \
					"${PRIMARY_METRIC_LABEL}" \
					'min' \
					"${RUNNER_MIN[index]}" \
					'max' \
					"${RUNNER_MAX[index]}" \
					'spread' \
					"${RUNNER_SPREAD[index]}"
				printf '    %-16s %8s %10.3f %8s %10.3f %8s %10.3f\n' \
					"${SECONDARY_METRIC_LABEL}" \
					'min' \
					"${RUNNER_SECONDARY_MIN[index]}" \
					'max' \
					"${RUNNER_SECONDARY_MAX[index]}" \
					'spread' \
					"${RUNNER_SECONDARY_SPREAD[index]}"
			fi

			if [[ "${index}" -lt "${last_index}" ]]; then
				printf '\n'
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

		printf '  %-34s %10.3f %-12s (%s)\n' "${line_label}" "${delta_backend}" "${PRIMARY_METRIC_LABEL}" "${direction}"
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
			"${pair_backend}-llama-bench" | "${pair_backend}-llama-server")
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

if OLLAMA_COMMAND="$(first_ollama_command)"; then
	start_ollama_server
else
	OLLAMA_COMMAND=''
fi
prepare_downloads

printf 'Benchmark\n'
if [[ ${#RUNNER_COMMANDS[@]} -gt 0 ]]; then
	if [[ "${MTP_MODEL}" == 'true' ]]; then
		printf '  Ollama runners: skipped - MTP requires llama-server MTP flags\n'
	fi
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
