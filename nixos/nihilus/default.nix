_: {
  nixpkgs.overlays = [
    (_final: super: {
      # Prevent mbrola-voices (~650MB) from being on the live media
      espeak = super.espeak.override { mbrolaSupport = false; };
    })
  ];
}
