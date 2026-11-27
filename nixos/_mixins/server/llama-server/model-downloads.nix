let
  modelFiles =
    {
      hfRepo,
      path,
      projectorPath ? null,
      publicName,
      revision ? null,
      supportsMtp ? false,
    }:
    {
      inherit
        hfRepo
        projectorPath
        publicName
        revision
        supportsMtp
        ;
      primaryPath = path;
      downloadPaths = [ path ] ++ (if projectorPath == null then [ ] else [ projectorPath ]);
    };

  inkling = modelFiles {
    hfRepo = "unsloth/Inkling-2-Mini-GGUF";
    path = "Mainline_Support/Inkling-2-Mini-UD-Q4_K_XL.gguf_file";
    projectorPath = "mmproj-BF16.gguf";
    publicName = "inkling-2-mini";
    revision = "45fd08764f2b0bf16b03a5483a80e5c7aaec8772";
  };

  qwen = modelFiles {
    hfRepo = "unsloth/Qwen3.8-27B-GGUF";
    path = "Qwen3.8-27B-UD-Q4_K_XL.gguf";
    projectorPath = "mmproj-BF16.gguf";
    publicName = "qwen3.8-27b";
    revision = "4af51b3542f775b0a8e4b310bfb3f17e01c306c9";
    supportsMtp = true;
  };
in
{
  "unsloth/Inkling-2-Mini-GGUF:UD-Q4_K_XL" = inkling;
  "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL" = qwen;
  "unsloth/Qwen3.5-9B-MTP-GGUF:UD-Q4_K_XL" = modelFiles {
    hfRepo = "unsloth/Qwen3.5-9B-MTP-GGUF";
    path = "Qwen3.5-9B-UD-Q4_K_XL.gguf";
    projectorPath = "mmproj-BF16.gguf";
    publicName = "qwen3.5-9b";
    supportsMtp = true;
  };

  "Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0" = modelFiles {
    hfRepo = "Qwen/Qwen3-Embedding-0.6B-GGUF";
    path = "Qwen3-Embedding-0.6B-Q8_0.gguf";
    publicName = "qwen3-embedding-0.6b";
  };
}
