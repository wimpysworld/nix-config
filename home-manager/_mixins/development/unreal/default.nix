{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf
  (
    host.is.linux
    && noughtyLib.isHost [
      "skrye"
      "tanis"
      "zannah"
    ]
  )
  {
    home = {
      packages = with pkgs; [
        butler
        unreal-engine
      ];
      sessionVariables = {
        BEEP_UE_ROOT = lib.mkDefault "${config.home.homeDirectory}/Development/UnrealEngine/UE_5.8";
      };
    };

    # Disable Unreal Build Accelerator inside the NixOS FHS sandbox so
    # libUbaDetours.so does not crash during local compilation or packaging.
    xdg.configFile."Epic/UnrealBuildTool/BuildConfiguration.xml".text = lib.mkDefault ''
      <?xml version="1.0" encoding="utf-8" ?>
      <Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
        <BuildConfiguration>
          <bAllowUBAExecutor>false</bAllowUBAExecutor>
          <bAllowUBALocalExecutor>false</bAllowUBALocalExecutor>
        </BuildConfiguration>
      </Configuration>
    '';
  }
