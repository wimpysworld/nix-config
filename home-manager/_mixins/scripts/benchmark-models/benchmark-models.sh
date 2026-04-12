#!/usr/bin/env bash
# benchmark-models.sh

set -euo pipefail

PROMPT="Write a detailed 500-word essay about the history of optical fibre telecommunications."
MODEL_SPECS=$(
	cat <<'EOF'
	qwen3.5:35b-a3b|unsloth/Qwen3.5-35B-A3B-GGUF|Qwen3.5-35B-A3B-Q4_K_M.gguf
	qwen3-coder-next|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-Q4_K_M.gguf
	gemma4:26b|unsloth/gemma-4-26B-A4B-it-GGUF|gemma-4-26B-A4B-it-UD-Q4_K_M.gguf
	qwen3.5:9b|unsloth/Qwen3.5-9B-GGUF|Qwen3.5-9B-Q4_K_M.gguf
	gemma4:e4b|unsloth/gemma-4-E4B-it-GGUF|gemma-4-E4B-it-Q4_K_M.gguf
	gemma4:e2b|unsloth/gemma-4-E2B-it-GGUF|gemma-4-E2B-it-Q4_K_M.gguf
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
HF_REPO=""
HF_FILE=""
HF_MODEL_PATH=""
MODEL=""
RUNS="5"
PURGE_REQUESTED='false'
HOST_COMPUTE_VENDOR="${BENCHMARK_MODELS_HOST_GPU_COMPUTE_VENDOR:-}"
BACKEND_MATRIX_REASON=""
OLLAMA_MEAN=""
OLLAMA_MIN=""
OLLAMA_MAX=""
OLLAMA_SPREAD=""
declare -a BACKEND_COMMANDS=()
declare -a BACKEND_MEAN=()
declare -a BACKEND_MIN=()
declare -a BACKEND_MAX=()
declare -a BACKEND_SPREAD=()
declare -a BACKEND_SKIPPED=()

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
  AMD      rocm-llama-bench, vulkan-llama-bench
  NVIDIA   cuda-llama-bench, vulkan-llama-bench

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
	local hf_file

	while IFS='|' read -r model hf_repo hf_file; do
		model="$(trim_whitespace "${model}")"
		hf_repo="$(trim_whitespace "${hf_repo}")"
		hf_file="$(trim_whitespace "${hf_file}")"
		if [[ "${model}" == "${requested_model}" ]]; then
			case "${field_name}" in
			repo)
				printf '%s\n' "${hf_repo}"
				return 0
				;;
			file)
				printf '%s\n' "${hf_file}"
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

hf_file_for_model() {
	model_spec_field "$1" file
}

validate_model() {
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

	if ! HF_FILE="$(hf_file_for_model "${MODEL}")"; then
		printf 'Error: no GGUF filename mapping defined for supported model: %s\n' "${MODEL}" >&2
		printf '\n' >&2
		list_supported_models >&2
		exit 1
	fi

	if [[ -z "${HF_FILE}" ]]; then
		printf 'Error: empty GGUF filename mapping for supported model: %s\n' "${MODEL}" >&2
		exit 1
	fi

	if [[ "${HF_FILE}" != *.gguf ]]; then
		printf 'Error: GGUF filename mapping must end with .gguf for model: %s\n' "${MODEL}" >&2
		exit 1
	fi
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
	if [[ -n "${OLLAMA_PID}" ]] && kill -0 "${OLLAMA_PID}" 2>/dev/null; then
		kill "${OLLAMA_PID}" 2>/dev/null || true
		wait "${OLLAMA_PID}" 2>/dev/null || true
	fi
	rm -f "${TMPFILE}"
}
trap cleanup EXIT

run_ollama() {
	env \
		HOME="${OLLAMA_RUNTIME_HOME}" \
		OLLAMA_HOST="${OLLAMA_BIND}" \
		OLLAMA_MODELS="${OLLAMA_MODELS_DIR}" \
		OLLAMA_FLASH_ATTENTION=1 \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		TMPDIR="${TMPDIR}" \
		ollama "$@"
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

add_backend() {
	BACKEND_COMMANDS+=("$1")
	BACKEND_MEAN+=("")
	BACKEND_MIN+=("")
	BACKEND_MAX+=("")
	BACKEND_SPREAD+=("")
	BACKEND_SKIPPED+=("")
}

prepare_backend_matrix() {
	case "${HOST_COMPUTE_VENDOR}" in
	amd)
		add_backend 'rocm-llama-bench'
		add_backend 'vulkan-llama-bench'
		;;
	nvidia)
		add_backend 'cuda-llama-bench'
		add_backend 'vulkan-llama-bench'
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
	local IFS=', '
	printf '%s' "${BACKEND_COMMANDS[*]}"
}

start_ollama_server() {
	rm -f "${OLLAMA_LOG}"
	run_ollama serve >"${OLLAMA_LOG}" 2>&1 &
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
	done < <(run_ollama list 2>/dev/null | awk 'NR > 1 { print $1 }')

	return 1
}

resolve_cached_hf_model_path() {
	local repo_cache_dir
	local revision
	local candidate
	local -a candidates=()

	repo_cache_dir="${HF_HUB_CACHE}/models--${HF_REPO//\//--}"

	if [[ -f "${repo_cache_dir}/refs/main" ]]; then
		revision="$(<"${repo_cache_dir}/refs/main")"
		candidate="${repo_cache_dir}/snapshots/${revision}/${HF_FILE}"
		if [[ -e "${candidate}" ]]; then
			printf '%s\n' "${candidate}"
			return 0
		fi
	fi

	shopt -s nullglob
	candidates=("${repo_cache_dir}"/snapshots/*/"${HF_FILE}")
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
	printf 'Model benchmark  %s  %s runs\n' "${MODEL}" "${RUNS}"
	printf '\n'
}

prepare_downloads() {
	printf 'Preparation\n'

	if ollama_model_cached; then
		printf '  [1/2] Ollama model: ready\n'
	else
		printf '  [1/2] Ollama model: pulling\n'
		run_ollama pull "${MODEL}"
	fi
	printf '\n'

	if HF_MODEL_PATH="$(resolve_cached_hf_model_path)"; then
		printf '  [2/2] Hugging Face GGUF: ready\n'
		printf '         %s\n' "${HF_FILE}"
	else
		printf '  [2/2] Hugging Face GGUF: downloading\n'
		printf '         %s - %s\n' "${HF_REPO}" "${HF_FILE}"
		run_hf download --repo-type model "${HF_REPO}" "${HF_FILE}"
		HF_MODEL_PATH="$(resolve_cached_hf_model_path || run_hf download --quiet --repo-type model "${HF_REPO}" "${HF_FILE}")"
	fi

	if [[ -z "${HF_MODEL_PATH}" ]]; then
		printf 'Error: failed to resolve downloaded GGUF path for %s\n' "${MODEL}" >&2
		exit 1
	fi
	printf '\n'
}

run_backend_benchmark() {
	local index="$1"
	local total_runners="$2"
	local command_name="${BACKEND_COMMANDS[index]}"
	local skipped_reason=""
	local runner_number=$((index + 2))
	local backend_tmpfile
	local tps

	printf '  Runner %s/%s: %s\n' "${runner_number}" "${total_runners}" "${command_name}"
	printf '    measured runs: %s\n' "${RUNS}"

	if ! command -v "${command_name}" >/dev/null 2>&1; then
		BACKEND_SKIPPED[index]="${command_name} not found."
		printf '    skipped - %s\n\n' "${BACKEND_SKIPPED[index]}"
		return 0
	fi

	backend_tmpfile=$(mktemp "${TMPDIR}/benchmark-backend.XXXXXX")

	for run_number in $(seq 1 "${RUNS}"); do
		printf '    run %s/%s... ' "${run_number}" "${RUNS}"
		if tps=$(run_llama_bench_once "${command_name}" "${HF_MODEL_PATH}"); then
			printf '%.3f tok/s\n' "${tps}"
			printf '%s\n' "${tps}" >>"${backend_tmpfile}"
		else
			printf 'failed\n'
		fi
	done

	if [[ ! -s "${backend_tmpfile}" ]]; then
		skipped_reason="${command_name} produced no usable tg results."
	else
		IFS='|' read -r stats_mean stats_min stats_max stats_spread <<<"$(calculate_stats "${backend_tmpfile}")"
		BACKEND_MEAN[index]="${stats_mean}"
		BACKEND_MIN[index]="${stats_min}"
		BACKEND_MAX[index]="${stats_max}"
		BACKEND_SPREAD[index]="${stats_spread}"
	fi

	rm -f "${backend_tmpfile}"

	BACKEND_SKIPPED[index]="${skipped_reason}"
	if [[ -n "${skipped_reason}" ]]; then
		printf '    skipped - %s\n' "${skipped_reason}"
	fi
	printf '\n'
}

print_results() {
	local index

	printf 'Results\n'
	printf '  %-20s %12s  %s\n' 'Runner' 'Mean tok/s' 'Notes'
	printf '  %-20s %12.3f  min %.3f, max %.3f, spread %.3f\n' 'Ollama' "${OLLAMA_MEAN}" "${OLLAMA_MIN}" "${OLLAMA_MAX}" "${OLLAMA_SPREAD}"

	if [[ ${#BACKEND_COMMANDS[@]} -eq 0 ]]; then
		printf '  %-20s %12s  %s\n' 'Host backends' 'skipped' "${BACKEND_MATRIX_REASON}"
	else
		for index in "${!BACKEND_COMMANDS[@]}"; do
			if [[ -n "${BACKEND_SKIPPED[index]}" ]]; then
				printf '  %-20s %12s  %s\n' "${BACKEND_COMMANDS[index]}" 'skipped' "${BACKEND_SKIPPED[index]}"
			else
				printf '  %-20s %12.3f  min %.3f, max %.3f, spread %.3f\n' "${BACKEND_COMMANDS[index]}" "${BACKEND_MEAN[index]}" "${BACKEND_MIN[index]}" "${BACKEND_MAX[index]}" "${BACKEND_SPREAD[index]}"
			fi
		done
	fi

	printf '\n'
}

print_deltas() {
	local index
	local delta_backend
	local delta_pair
	local direction
	local pair_direction
	local printed='false'

	for index in "${!BACKEND_COMMANDS[@]}"; do
		if [[ -n "${BACKEND_MEAN[index]}" ]]; then
			if [[ "${printed}" == 'false' ]]; then
				printf 'Deltas\n'
				printed='true'
			fi

			delta_backend=$(awk "BEGIN { printf \"%.3f\", ${BACKEND_MEAN[index]} - ${OLLAMA_MEAN} }")
			if awk "BEGIN { exit (${BACKEND_MEAN[index]} >= ${OLLAMA_MEAN}) ? 1 : 0 }"; then
				direction='Ollama faster'
			else
				direction="${BACKEND_COMMANDS[index]} faster"
			fi

			printf '  %-20s %+6.3f tok/s  (%s)\n' "${BACKEND_COMMANDS[index]} vs Ollama" "${delta_backend}" "${direction}"
		fi
	done

	if [[ ${#BACKEND_COMMANDS[@]} -ge 2 && -n "${BACKEND_MEAN[0]}" && -n "${BACKEND_MEAN[1]}" ]]; then
		if [[ "${printed}" == 'false' ]]; then
			printf 'Deltas\n'
			printed='true'
		fi

		delta_pair=$(awk "BEGIN { printf \"%.3f\", ${BACKEND_MEAN[1]} - ${BACKEND_MEAN[0]} }")
		if awk "BEGIN { exit (${BACKEND_MEAN[1]} >= ${BACKEND_MEAN[0]}) ? 1 : 0 }"; then
			pair_direction="${BACKEND_COMMANDS[0]} faster"
		else
			pair_direction="${BACKEND_COMMANDS[1]} faster"
		fi

		printf '  %-20s %+6.3f tok/s  (%s)\n' "${BACKEND_COMMANDS[1]} vs ${BACKEND_COMMANDS[0]}" "${delta_pair}" "${pair_direction}"
	fi

	if [[ "${printed}" == 'true' ]]; then
		printf '\n'
	fi
}

prepare_backend_matrix

print_intro

start_ollama_server
prepare_downloads

printf 'Benchmark\n'
if [[ ${#BACKEND_COMMANDS[@]} -gt 0 ]]; then
	printf '  Runners: Ollama, %s\n' "$(backend_matrix_label)"
else
	printf '  Runners: Ollama\n'
	printf '  Host backends: skipped - %s\n' "${BACKEND_MATRIX_REASON}"
fi
printf '\n'

: >"${TMPFILE}"

printf '  Runner 1/%s: Ollama\n' "$((1 + ${#BACKEND_COMMANDS[@]}))"
printf '    measured runs: %s\n' "${RUNS}"
for run_number in $(seq 1 "${RUNS}"); do
	printf '    run %s/%s... ' "${run_number}" "${RUNS}"
	tps=$(run_ollama_once)
	printf '%.3f tok/s\n' "${tps}"
	printf '%s\n' "${tps}" >>"${TMPFILE}"
done

IFS='|' read -r OLLAMA_MEAN OLLAMA_MIN OLLAMA_MAX OLLAMA_SPREAD <<<"$(calculate_stats "${TMPFILE}")"
printf '\n'

if [[ ${#BACKEND_COMMANDS[@]} -eq 0 ]]; then
	:
else
	for index in "${!BACKEND_COMMANDS[@]}"; do
		run_backend_benchmark "${index}" "$((1 + ${#BACKEND_COMMANDS[@]}))"
	done
fi

print_results
print_deltas
