{
  lib,
  writeShellApplication,
  wrangler,
  accountIdPath,
  apiTokenPath,
}:
writeShellApplication {
  name = "wrangler";
  text =
    builtins.replaceStrings
      [
        "@accountIdPath@"
        "@apiTokenPath@"
        "@wrangler@"
      ]
      (map lib.escapeShellArg [
        accountIdPath
        apiTokenPath
        (lib.getExe wrangler)
      ])
      (builtins.readFile ./wrangler.sh);
}
