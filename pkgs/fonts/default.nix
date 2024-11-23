{ callPackage }:
{
  # Local fonts
  # - https://yildiz.dev/posts/packing-custom-fonts-for-nixos/
  bebas-neue-2014-font = callPackage ./bebas-neue-2014-font { };
  bebas-neue-2018-font = callPackage ./bebas-neue-2018-font { };
  bebas-neue-pro-font = callPackage ./bebas-neue-pro-font { };
  bebas-neue-rounded-font = callPackage ./bebas-neue-rounded-font { };
  bebas-neue-semi-rounded-font = callPackage ./bebas-neue-semi-rounded-font { };
  boycott-font = callPackage ./boycott-font { };
  commodore-64-pixelized-font = callPackage ./commodore-64-pixelized-font { };
  digital-7-font = callPackage ./digital-7-font { };
  dirty-ego-font = callPackage ./dirty-ego-font { };
  fixedsys-core-font = callPackage ./fixedsys-core-font { };
  fixedsys-excelsior-font = callPackage ./fixedsys-excelsior-font { };
  impact-label-font = callPackage ./impact-label-font { };
  mocha-mattari-font = callPackage ./mocha-mattari-font { };
  poppins-font = callPackage ./poppins-font { };
  spaceport-2006-font = callPackage ./spaceport-2006-font { };
  zx-spectrum-7-font = callPackage ./zx-spectrum-7-font { };
}
