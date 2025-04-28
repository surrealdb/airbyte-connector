{
  description = "Airbyte SurrealDB destination connector devenv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    #nixpkgs-python.url = "github:cachix/nixpkgs-python";
  };

  outputs = { self, nixpkgs }: 
    let
      system = "x86_64-linux";

      #pythonVersion = "3.11.11";

      pkgs = import nixpkgs { inherit system; };
      #myPython = nixpkgs.packages.${system}.${pythonVersion};
    in
    {
      # See https://nixos.org/manual/nixpkgs/stable/#sec-fhs-environments
      devShells.${system}.default = (pkgs.buildFHSEnv {
        name = "airbyte-ci-fhs";
        targetPkgs = pkgs: [
          pkgs.glibc
          pkgs.openssl
          pkgs.python3
          pkgs.python3Packages.pip
          # airbyte-ci deps below
          pkgs.zlib
          pkgs.git
          pkgs.which
          pkgs.curl
          pkgs.docker
          pkgs.stdenv
        ];
        runScript = pkgs.writeShellScript "shell-hook" ''
          echo "Entering FHS environment for airbyte-ci..."
          python --version
          make deps
          # so that airbyte-ci and dagger are accessible
          export PATH=$PATH:$HOME/.local/bin
          # Keep the original shell prompt if possible
          if [ -n "$PS1" ]; then
            export PS1="\[\e[0;32m\](fhs-env)\[\e[0m\] $PS1"
          fi
          # So that curl has access to the certs
          export CURL_CA_BUNDLE=$NIX_SSL_CERT_FILE
          # So that airbyte-ci (and its http / ssl module) do not fail with FileNotFound
          export SSL_CERT_FILE=$NIX_SSL_CERT_FILE
          exec bash
        '';
        
        profile = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc ]}"
        '';
      }).env;
    };
}
