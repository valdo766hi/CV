{
  description = "Rivaldo Silalahi CV built with Nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    sops-nix,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      # Decrypt secrets at evaluation time
      # Requires: export SOPS_AGE_KEY="$(grep AGE-SECRET-KEY age-key.txt)"
      decryptSecret = secretPath: key:
        let
          # Get the AGE key from environment at eval time
          ageKey = builtins.getEnv "SOPS_AGE_KEY";
        in
          builtins.readFile (pkgs.runCommand "decrypted-${key}" {
            nativeBuildInputs = [pkgs.sops];
          } ''
            # Export the AGE key for sops to use
            export SOPS_AGE_KEY="${ageKey}"
            ${pkgs.sops}/bin/sops -d --extract '["${key}"]' ${secretPath} > $out
          '');

      texEnv = pkgs.texlive.combine {
        inherit
          (pkgs.texlive)
          scheme-small
          latexmk
          geometry
          hyperref
          mlmodern
          collection-latexrecommended
          enumitem
          titlesec
          ;
      };

      mkCvPackage = {
        pname,
        texFile,
        pdfFile,
        phoneNumber,
      }:
        pkgs.stdenvNoCC.mkDerivation {
          inherit pname;
          version = "1.0.0";
          src = ./.;

          nativeBuildInputs = [pkgs.coreutils texEnv pkgs.gnused];

          buildPhase = ''
            export TEXMFHOME=$PWD/.cache
            export TEXMFVAR=$PWD/.cache/texmf-var
            mkdir -p "$TEXMFVAR"
            export SOURCE_DATE_EPOCH=1

            # Replace placeholder with actual phone number
            sed "s/PHONE_NUMBER_PLACEHOLDER/${phoneNumber}/g" ${texFile} > ${texFile}.tmp
            mv ${texFile}.tmp ${texFile}

            latexmk -interaction=nonstopmode -pdf ${texFile}
          '';

          installPhase = ''
            mkdir -p $out
            cp ${pdfFile} $out/cv-rivaldo-silalahi.pdf
          '';
        };
    in {
      packages.default = mkCvPackage {
        pname = "cv-rivaldo-silalahi";
        texFile = "cv.tex";
        pdfFile = "cv.pdf";
        phoneNumber = decryptSecret ./secrets.yaml "phone_number";
      };

      devShells.default = pkgs.mkShell {
        packages = [
          texEnv
          pkgs.age
          pkgs.sops
        ];
      };
    });
}
