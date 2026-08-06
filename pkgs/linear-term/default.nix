{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "linear-term";
  version = "0.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tjburch";
    repo = "linear-term";
    tag = "v${finalAttrs.version}";
    hash = "sha256-RWB6bCe8k2dKvPF1vl6sVYr+HQtaFg/tUxs4hdPx0Ng=";
  };

  build-system = with python3Packages; [ hatchling ];

  dependencies = with python3Packages; [
    gql
    httpx
    platformdirs
    pyyaml
    rich
    textual
  ];

  nativeCheckInputs = with python3Packages; [
    pytest-asyncio
    pytestCheckHook
  ];

  preCheck = ''
    export HOME="$TMPDIR"
  '';

  pythonImportsCheck = [ "linear_term" ];

  meta = {
    description = "Terminal user interface for Linear project management";
    homepage = "https://github.com/tjburch/linear-term";
    changelog = "https://github.com/tjburch/linear-term/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "linear-term";
    platforms = lib.platforms.unix;
  };
})
