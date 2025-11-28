{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ ];
        pkgs = import nixpkgs { inherit overlays system; };

        tex = pkgs.texliveBasic.withPackages (
          ps: with ps; [
            collection-fontsrecommended
            collection-fontsextra
            collection-latexextra
            collection-latexrecommended
            collection-metapost
            collection-luatex
            acmart
            latexmk
          ]
        );

        ar5iv-bindings = builtins.fetchTarball {
          url = "https://github.com/dginev/ar5iv-bindings/archive/refs/tags/0.3.0.tar.gz";
          sha256 = "0isqy8b16py0apgjbl7bdjph9ilhmm479i2g0mlzr2rgai308gl7";
        };

        ar5iv-setup = ''
          mkdir -p out
          cp -rn ${ar5iv-bindings} out/ar5iv-bindings
        '';

        misc = with pkgs; [
          bash # For latexmk's `-usepretex`
          coreutils # For `env` and `mktemp`
          glibcLocales # For LaTeX
          gnumake
          perlPackages.LaTeXML
        ];

        buildInputs = [
          tex
          ar5iv-bindings
        ]
        ++ misc;

        nixfmt = pkgs.nixfmt-rfc-style;

        devInputs = [
          nixfmt
          pkgs.tex-fmt
        ]
        ++ buildInputs;

      in
      rec {
        packages = {
          default = pkgs.stdenvNoCC.mkDerivation rec {
            inherit buildInputs;

            name = "paper";
            src = self;
            phases = [
              "unpackPhase"
              "buildPhase"
              "installPhase"
            ];
            buildPhase = ''
              runHook preBuild
              export PATH="${pkgs.lib.makeBinPath buildInputs}";

              ${ar5iv-setup}

              env SOURCE_DATE_EPOCH=${toString self.lastModified} \
                  HOME=$(mktemp -d) make

              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out
              cp -r out/* $out
              runHook postInstall
            '';
          };
        };

        devShells = {
          default = pkgs.mkShellNoCC {
            buildInputs = devInputs;
            shellHook = ''
              # correct date in LaTeX
              export SOURCE_DATE_EPOCH=${toString self.lastModified}

              ${ar5iv-setup}
              chmod -R +w out/ar5iv-bindings
            '';
          };
        };

        formatter = nixfmt;
      }
    );
}
