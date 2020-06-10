{
  pkgs ? import <nixpkgs> {},
  use-prebuilt-symbiflow ? true, # set to false to build symbiflow-arch-defs
  use-vivado ? false             # set to true to install and use Vivado, only works on Linux
}:

with pkgs;
with lib;

rec {

  inherit (import ./nix-fpgapkgs {}) vivado;

  # toolchain
  vtr = stdenv.mkDerivation {
    name = "vtr-symbiflow";
    nativeBuildInputs = [
      bison
      cmake
      flex
      pkg-config
    ];
    buildInputs = [
      cairo
      clang-tools
      coreutils
      fontconfig
      gperftools
      gtk3
      harfbuzz
      mount
      pcre
      perl
      python27
      python3
      tbb
      time
      xorg.libX11
      xorg.libXdmcp
      xorg.libXft
      xorg.libpthreadstubs
    ];
    src = fetchGit {
      url = "https://github.com/SymbiFlow/vtr-verilog-to-routing.git";
      ref = "master+wip";
      rev = "8980e46218542888fac879961b13aa7b0fba8432";
    };
    postInstall =
      if stdenv.isDarwin
      then
        ''
          for i in vpr genfasm; do
            install_name_tool -add_rpath ${tbb}/lib $out/bin/$i
          done
        ''
      else
        "";
    enableParallelBuilding = true;
  };

  abc-verifier = { url ? "https://github.com/berkeley-abc/abc", rev }:
    pkgs.abc-verifier.overrideAttrs (oldAttrs: rec {
      src = fetchGit {
        inherit url rev;
      };
    }) // {
      inherit rev; # this doesn't update otherwise
    };

  yosys-symbiflow = (pkgs.yosys.override {
    abc-verifier = abc-verifier {
      rev = "623b5e82513d076a19f864c01930ad1838498894";
    };
  }).overrideAttrs (oldAttrs: rec {
    src = fetchGit {
      url = "https://github.com/SymbiFlow/yosys.git";
      ref = "master+wip";
      rev = "6bccd35a41ab82f52f0688478310899cfec04e08";
    };
    doCheck = false;
  });

  yosys-git = (pkgs.yosys.override {
    abc-verifier = abc-verifier {
      url = "https://github.com/YosysHQ/abc.git";
      rev = "fd2c9b1c19216f6b756f88b18f5ca67b759ca128";
    };
  }).overrideAttrs (oldAttrs: rec {
    src = fetchGit {
      url = "https://github.com/YosysHQ/yosys.git";
      rev = "8f1a32064639fa17d67bda508df941c8846a0664";
    };
    doCheck = false;
  });

  yosys-symbiflow-plugins = { yosys }: stdenv.mkDerivation {
    name = "yosys-symbiflow-plugins";
    src = fetchGit {
      url = "https://github.com/SymbiFlow/yosys-symbiflow-plugins.git";
      rev = "1c495fd47ddfc54a9f815c0ba97dc112e1731bd6";
    };
    phases = "unpackPhase buildPhase installPhase";
    plugins = "xdc fasm";
    buildPhase = ''
      for i in $plugins; do
        make -C ''${i}-plugin ''${i}.so
      done
    '';
    installPhase = ''
      mkdir $out
      for i in $plugins; do
        cp ''${i}-plugin/''${i}.so $out
      done
    '';
    buildInputs = [ yosys bison flex tk libffi readline ];
  };

  # custom Python
  python = pkgs.python37.override {
    packageOverrides = import ./python-overlay.nix {
      inherit pkgs prjxray;
      pythonPackages = python37Packages;
    };
  };

  # SymbiFlow architecture definitions
  symbiflow-arch-defs = clangStdenv.mkDerivation rec {
    name = "symbiflow";
    yosys = yosys-symbiflow;
    buildInputs = let
      python-with-packages = python.withPackages (p: with p; [
        GitPython
        arpeggio
        cairosvg
        colorclass
        cytoolz
        fasm
        flake8
        hilbertcurve
        intervaltree
        lxml
        matplotlib
        numpy
        pandas
        pdfminer
        pip
        progressbar2
        pycapnp
        pyjson
        pyserial
        pytest
        python-constraint
        python-prjxray
        python-sdf-timing
        python-symbiflow-v2x
        python-utils
        scipy
        setuptools
        simplejson
        six
        sortedcontainers
        svgwrite
        terminaltables
        textx
        tinyfpgab
        tox
        tqdm
        virtualenv
        vtr-xml-utils
        yapf
      ]);
    in
      [
        cmake
        git
        glib
        icestorm
        libiconv
        libxml2
        libxslt
        ncurses5
        nodejs
        openocd
        perl
        pkg-config
        python-with-packages
        readline
        sqlite-interactive
        tcl
        tinyprog
        verilog
        vtr
        wget
        xorg.libICE
        xorg.libSM
        xorg.libX11
        xorg.libXext
        xorg.libXrender
        xxd
        yosys
        zlib
      ];
    src = fetchgit {
      url = "https://github.com/HackerFoo/symbiflow-arch-defs.git";
      branchName = "dont-use-conda";
      fetchSubmodules = true;
      rev = "718b11060997641ed84b538eebcd6f127aab3cc0";
      sha256 = "1lvcfw72wb9k1l4bs42hyviyn8brsgb98hj0lyx3v8k725ba0lb6";
    };
    YOSYS_SYMBIFLOW_PLUGINS = yosys-symbiflow-plugins { inherit yosys; };
    patches = [
      ./patches/symbiflow-arch-defs.patch
    ];
    postPatch = ''
      patchShebangs utils
      patchShebangs third_party/prjxray/utils
      patch -d third_party/prjxray -p1 < ${ ./patches/prjxray.patch }
    '';
    configurePhase = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      mkdir -p build
      pushd build
      cmake -DUSE_CONDA=FALSE -DCMAKE_INSTALL_PREFIX=$out -DYOSYS_DATADIR="${yosys}/share/yosys" -DVPR_CAPNP_SCHEMA_DIR="${vtr}/capnp" ..
      popd
    '';
    buildPhase = ''
      export VPR_NUM_WORKERS=$NIX_BUILD_CORES
      make -C build -j $NIX_BUILD_CORES all
    '';
    enableParallelBuilding = true;
    installPhase = "make -C build -j $NIX_BUILD_CORES install";

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      export phases="configurePhase buildPhase"
    '';
  };

  vivado_settings = writeScript "settings64.sh"
    (if use-vivado
     then ''
       export XILINX_VIVADO=${vivado}/opt/Vivado/2017.2
       if [ -n "''${PATH}" ]; then
         export PATH=${vivado}/opt/Vivado/2017.2/bin:$PATH
       else
         export PATH=${vivado}/opt/Vivado/2017.2/bin
       fi
    '' else ''
       echo "Vivado not installed"
    '');

  prjxray = stdenv.mkDerivation {
    name = "prjxray";
    srcs = [
      (fetchgit {
        name = "prjxray";
        url = "https://github.com/SymbiFlow/prjxray.git";
        fetchSubmodules = true;
        rev = "35ead5e40f6a9fdc4d338e4471d8de2bd47ef787";
        sha256 = "05h2pw0nkq9zhsaw2zblma2im8ywd5nvcwn8wjdl4jpva1av0yyj";
      })
      (fetchGit {
        name = "prjxray-db";
        url = "https://github.com/SymbiFlow/prjxray-db.git";
        rev = "20adf09d395fbd8c3ab90a5bd7e3cdf3e8db33b3";
      })
    ];
    patches = [ ./patches/prjxray.patch ];
    postPatch = ''
      patchShebangs utils
    '';
    setSourceRoot = ''
      sourceRoot="prjxray"
    '';
    nativeBuildInputs = [ cmake ];
    buildInputs = let
      python-with-packages = python.withPackages (p: with p; [
        fasm
        intervaltree
        #junit-xml
        numpy
        openpyxl
        ordered-set
        parse
        progressbar2
        pyjson5
        pytest
        python-sdf-timing
        pyyaml
        scipy
        simplejson
        sympy
        textx
        yapf
      ]);
    in
      [
        python-with-packages
      ];
    preConfigure = "export XRAY_VIVADO_SETTINGS=${vivado_settings}";
    configurePhase = ''
      mkdir -p build $out
      pushd build
      cmake .. -DCMAKE_INSTALL_PREFIX=$out
      popd
    '';
    enableParallelBuilding = true;
    buildPhase = ''
      make -C build -j $NIX_BUILD_CORES ''${TARGET:-all}
    '';
    installPhase = ''
      make -C build install
      mkdir -p $out/build
      ln -s $out/bin $out/build/tools
      cp -r utils $out/utils
      cp -r ../prjxray-db $out/database
    '';

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export phases="patchPhase configurePhase buildPhase"
    '';
  };

  nextpnr-xilinx = stdenv.mkDerivation {
    name = "nextpnr-xilinx";
    src = fetchgit {
      url = "https://github.com/daveshah1/nextpnr-xilinx.git";
      fetchSubmodules = true;
      rev = "7e46c6a3703d029c9776d57b64e4ba94f7bc8264";
      sha256 = "0pacjhz8rxrra6g7636fkmk2zkbvq7p9058hj4q90gc22dk9x2ji";
    };
    nativeBuildInputs = [ cmake ];
    buildInputs = [
      yosys-git
      prjxray
      python37
      (boost.override { python = python37; enablePython = true; })
      eigen
    ] ++ optional stdenv.cc.isClang [
      llvmPackages.openmp
    ];
    enableParallelBuilding = true;
    DEVICES = [
      "xc7a35tcsg324-1"
      "xc7a35tcpg236-1"
      "xc7z010clg400-1"
      "xc7z020clg484-1"
    ];

    configurePhase = ''
      export XRAY_DIR=${prjxray}
      cmake -DARCH=xilinx -DBUILD_GUI=OFF -DCMAKE_INSTALL_PREFIX=$out .
    '';
    postBuild = ''
      # Compute data files for nextpnr-xilinx
      mkdir -p share
      for device in $DEVICES; do
          echo "Exporting arch for $device"
          python xilinx/python/bbaexport.py --device $device --bba share/$device.bba
          ./bbasm share/$device.bba share/$device.bin -l
      done
    '';
    postInstall = ''
      mkdir -p $out/share
      cp -r share $out/share/nextpnr-xilinx
    '';
    shellHook = ''
      export XRAY_DIR=${prjxray}
      export phases="configurePhase buildPhase"
    '';
  };

  symbiflow-arch-defs-install = if use-prebuilt-symbiflow then symbiflow-arch-defs-download else symbiflow-arch-defs;
  symbiflow-arch-defs-download = stdenv.mkDerivation {
    name = "symbiflow-arch-defs-install";
    src = fetchTarball {
      url = "https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/presubmit/install/206/20200526-034850/symbiflow-arch-defs-install-97519a47.tar.xz";
      sha256 = "0jvb556k2q92sym94y696b5hcr84ab6mfdn52qb1v5spk7fd77db";
    };
    phases = [ "unpackPhase" "patchPhase" "installPhase" ];
    patchPhase = ''
      sed -i -E -e "s|^plugin -i +([a-zA-Z0-9]+)|plugin -i $::env(YOSYS_SYMBIFLOW_PLUGINS)/\1.so|" share/symbiflow/scripts/xc7/synth.tcl
    '';
    installPhase = ''
      mkdir $out
      cp -r * $out/
    '';
  };

  mac-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        sysctl -a | grep machdep.cpu
  '';

  fpga-tool-perf = stdenv.mkDerivation rec {
    name = "fpga-tool-perf";
    src = fetchgit {
      url = "https://github.com/SymbiFlow/fpga-tool-perf.git";
      fetchSubmodules = true;
      rev = "87e7472a38cbedd66450a305ec31fbf41f8fecdc";
      sha256 = "09x0sy6hg8y0l6qy4a14v8wyfdi3xj57b1yxmc50lrkw94r1d2bc";
    };
    yosys = yosys-git; # https://github.com/SymbiFlow/yosys/issues/79
    buildInputs = let
      python-with-packages = python.withPackages (p: with p; [
        asciitable
        colorclass
        edalize
        fasm
        intervaltree
        jinja2
        lxml
        pandas
        pytest
        python-constraint
        python-prjxray
        simplejson
        terminaltables
        textx
        tqdm
        yapf
        # TODO symbiflow-xc-fasm2bels
      ]);
    in
      [
        getopt
        nextpnr-xilinx
        prjxray
        python-with-packages
        vtr
        yosys
      ] ++ optional stdenv.isDarwin [
        mac-lscpu
      ];
    YOSYS_SYMBIFLOW_PLUGINS = yosys-symbiflow-plugins { inherit yosys; };
    env_script = ''
        mkdir -p env/conda/{bin,pkgs}
        touch env/conda/bin/activate
        source env.sh
        rm -f env/conda/pkgs/nextpnr-xilinx
        ln -s ${nextpnr-xilinx} env/conda/pkgs/nextpnr-xilinx
    '';
    shellHook = ''
      export YOSYS_SYMBIFLOW_PLUGINS
      export PYTHONPATH=${prjxray}
      export VIVADO_SETTINGS=${vivado_settings}
      export XRAY_DATABASE_DIR=${prjxray}/database
      export XRAY_FASM2FRAMES="${prjxray}/utils/fasm2frames.py"
      export XRAY_TOOLS_DIR="${prjxray}/bin"
      export SYMBIFLOW="${symbiflow-arch-defs-install}"

      if [ "''${PWD##*/}" == "fpga-tool-perf" ]; then
        read -p "Run env script (y/N) " RESPONSE
        RESPONSE=''${RESPONSE,,} # tolower
        if [[ "''${RESPONSE}" =~ ^(yes|y)$ ]]; then
          ${env_script}
        fi
      fi
    '';
  };
}
