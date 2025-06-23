{
  description = "QiCore Agent Orchestration Platform - System Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Allow unfree packages (CUDA)
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };
      in
      {
        # Development shell - ONLY system libraries and tools
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Core development tools
            python312        # Python interpreter only
            uv              # Python package manager (replaces poetry)
            
            # Essential system libraries for Python packages
            gcc              # C compiler and libraries
            glibc            # Standard C library
            zlib             # Compression library
            libffi           # Foreign function interface
            openssl          # Cryptography
            sqlite           # Database
            pkg-config       # For finding libraries
            
            # Development utilities (using system Ollama)
            git
            curl
            wget
            jq
            zsh              # User's default shell for compatibility
          ];

          # Environment variables for proper library linking
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [
            pkgs.gcc.cc.lib
            pkgs.glibc
            pkgs.zlib
            pkgs.libffi
            pkgs.openssl
            pkgs.sqlite
          ]}:/nix/store/*/lib:/nix/store/*/lib64";
          
          # Ensure Python can find system libraries
          PKG_CONFIG_PATH = pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" [
            pkgs.openssl
            pkgs.zlib
            pkgs.libffi
            pkgs.sqlite
          ];

          shellHook = ''
            echo "🚀 QiCore Agent Orchestration Platform - Development Environment"
            echo "📦 Package Management: uv (fast, modern Python package manager)"
            echo "🛠️  System Libraries: Nix-provided (C++, CUDA, etc.)"
            echo ""
            
            # GPU detection (simplified)
            if command -v nvidia-smi >/dev/null 2>&1; then
              GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null || echo "Unknown GPU")
              echo "🎮 GPU: $GPU_NAME"
            else
              echo "⚠️  No NVIDIA GPU detected - CPU mode only"
            fi
            
            echo "🤖 Ollama: Available via system installation wrapper"
            echo "🐍 Python: $(python --version)"
            echo "⚡ uv: $(uv --version)"
            echo ""
            echo "🎯 Architecture:"
            echo "  • Nix: System libraries, development tools, CUDA support"
            echo "  • uv: Python packages (fast, pre-built wheels)"
            echo "  • No more poetry2nix compilation hell! 🎉"
            echo ""
            echo "Quick start:"
            echo "  uv sync                         # Install Python dependencies (FAST!)"
            echo "  ollama serve                    # Start Ollama (auto-detects GPU)"
            echo "  ollama pull llama3.2:3b        # Download recommended model"
            echo "  uv run python -m mcp_server.main  # Run MCP server"
            echo ""
            echo "Development:"
            echo "  uv add <package>               # Add new dependency"
            echo "  uv run <command>               # Run command in uv environment"
            echo "  uv run python -c 'import...'   # Test imports"
            echo ""
            echo "Why uv + Nix:"
            echo "  ✅ 10-100x faster than poetry"
            echo "  ✅ No PyTorch compilation"
            echo "  ✅ Pre-built wheels for everything"
            echo "  ✅ System libraries from Nix"
            echo "  ✅ Best of both worlds!"
          '';
        };
      }
    );
}