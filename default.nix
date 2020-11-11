{
  sources ? import ./nix/sources.nix,
  use-vivado ? true,              # set to true to install and use Vivado, only works on Linux
  pkgs ? import sources.nixpkgs (
    if use-vivado
    then { config.allowUnfree = true; }
    else { }
  )
}:

with builtins;
with pkgs;
with lib;
with callPackage ./library.nix {};

rec {

  inherit pkgs;

  # to force fetching all source
  project_list = attrNames (fromJSON (readFile ./nix/sources.json));
  all_source = linkFarm "all_source" (map (name: { inherit name; path = getAttr name sources; }) project_list);

  inherit (import ./nix-fpgapkgs { inherit pkgs; }) vivado migen;

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
    src = sources.vtr;
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

  vtr-run = vtr.overrideAttrs (attrs: {
    src = sources.vtr-run;
  });

  replace_constants = subst:
    concatMapStrings (name:
      let
        m = getAttr name subst;
      in
        "bash ${./scripts/replace-consts.sh} ${name} ${concatMapStrings (key: " ${key}=${toString (getAttr key m)}") (attrNames m)}\n")
      (attrNames subst);

  vtr-custom = subst: vtr.overrideAttrs (attrs: rec {
    src = sources.vtr-run;
    patches = [ ./patches/vpr_kscale.patch ];
    postPatch = ''
      touch constants.patch
      ${replace_constants subst}
      mkdir -p $out
      cp constants.patch $out
    '';
  });

  abc-verifier = src: attrs:
    (pkgs.abc-verifier.override attrs).overrideAttrs (oldAttrs: {
      inherit src;
    }) // {
      inherit (src) rev; # this doesn't update otherwise
    };

  yosys-symbiflow = yosys-with-symbiflow-plugins {
    stdenv = clangStdenv;
    yosys = (pkgs.yosys.override {
      stdenv = clangStdenv;
      abc-verifier = abc-verifier sources.abc-symbiflow {
        stdenv = clangStdenv;
      };
    }).overrideAttrs (oldAttrs: rec {
      src = sources.yosys-symbiflow;
      preBuild = oldAttrs.preBuild + ''
        echo 'CXXFLAGS += "-std=c++11 -Os -fno-merge-constants"' > Makefile.conf
        echo 'ABCREV=default' >> Makefile.conf
        echo 'ABCMKARGS="CC=clang" "CXX=clang++"' >> Makefile.conf
        cp -r ${sources.abc-symbiflow} abc
        chmod -R a+w abc
      '';
      postInstall = ''
        cp yosys-abc $out/bin/
      '';
      doCheck = false;
    });
  };
  yosys-symbiflow-run = yosys-with-symbiflow-plugins {
    stdenv = clangStdenv;
    yosys = (pkgs.yosys.override {
      stdenv = clangStdenv;
      abc-verifier = abc-verifier sources.abc-symbiflow {
        stdenv = clangStdenv;
      };
    }).overrideAttrs (oldAttrs: rec {
      src = sources.yosys-symbiflow;
      preBuild = oldAttrs.preBuild + ''
        echo 'CXXFLAGS += "-std=c++11 -Os -fno-merge-constants"' > Makefile.conf
        echo 'ABCREV=default' >> Makefile.conf
        echo 'ABCMKARGS="CC=clang" "CXX=clang++"' >> Makefile.conf
        cp -r ${sources.abc-symbiflow} abc
        chmod -R a+w abc
      '';
      postInstall = ''
        cp yosys-abc $out/bin/
      '';
      doCheck = false;
    });
    src = sources.yosys-symbiflow-plugins-run;
  };

  yosys-git = (pkgs.yosys.override {
    abc-verifier = abc-verifier sources.abc-yosys {};
  }).overrideAttrs (oldAttrs: rec {
    src = sources.yosys;
    doCheck = false;
  });

  yosys-with-symbiflow-plugins = {
    yosys,
    stdenv ? pkgs.stdenv,
    src ? sources.yosys-symbiflow-plugins,
    plugins ? "xdc fasm params selection",
    bin ? "yosys-filterlib,yosys-smtbmc,yosys-abc"
  }: stdenv.mkDerivation {
    inherit (yosys) name; # HACK keep path the same size to allow bbe replacement
    inherit src plugins;
    phases = "unpackPhase buildPhase installPhase";
    buildPhase = ''
      for i in $plugins; do
        make -C ''${i}-plugin ''${i}.so
      done
    '';
    installPhase = ''
      mkdir -p $out/bin $out/share/yosys/plugins
      cp -rs ${yosys}/share $out/
      cp -s ${yosys}/bin/{${bin}} $out/bin/
      sed "s|${yosys}|''${out}|g" ${yosys}/bin/yosys-config > $out/bin/yosys-config
      ${bbe}/bin/bbe -e "s|${yosys}|''${out}|g" ${yosys}/bin/yosys > $out/bin/yosys
      chmod +x $out/bin/{yosys,yosys-config}
      for i in $plugins; do
        make -C ''${i}-plugin install PLUGINS_DIR=$out/share/yosys/plugins
      done
    '';
    buildInputs = [ yosys bison flex tk libffi readline ];
  };

  sv2v = with haskellPackages.override {
    overrides = self: super: {
      githash = pkgs.haskell.lib.overrideCabal super.githash {
        version = "0.1.4.0";
        sha256 = "0rsz230srhszwybg5a40vhzzp9z0r4yvdz4xg2hwwwphmbi8pfy3";
      };
    };
  }; mkDerivation {
    pname = "sv2v";
    version = "0.0.5";
    src = sources.sv2v;
    isLibrary = false;
    isExecutable = true;
    executableHaskellDepends = [
      array base cmdargs containers directory filepath githash hashable
      mtl
    ];
    executableToolDepends = [ alex happy pkgs.git ];
    homepage = "https://github.com/zachjs/sv2v";
    description = "SystemVerilog to Verilog conversion";
    license = stdenv.lib.licenses.bsd3;
  };

  # custom Python
  python = pkgs.python37.override {
    packageOverrides = import ./python-overlay.nix {
      inherit pkgs sources prjxray migen;
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
        sv2v
        terminaltables
        textx
        tinyfpgab
        tox
        tqdm
        virtualenv
        vtr-xml-utils
        xc-fasm
        yapf
        Mako
        edalize-lowRISC
        fusesoc-lowRISC
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
    src = sources.symbiflow-arch-defs;
    postPatch = ''
      patchShebangs utils
      patchShebangs third_party/prjxray/utils
    '';
    configurePhase = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      export XDG_CACHE_HOME=$PWD/.cache
      mkdir -p $XDG_CACHE_HOME
      mkdir -p build
      pushd build
      cmake \
        -DUSE_CONDA=FALSE \
        -DCMAKE_INSTALL_PREFIX=$out \
        -DYOSYS_DATADIR="${yosys}/share/yosys" \
        -DVPR_CAPNP_SCHEMA_DIR="${vtr}/capnp" \
        ..
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

  symbiflow-arch-defs-200t = symbiflow-arch-defs.overrideAttrs (attrs: {
    name = "symbiflow-200t";
    configurePhase = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      export XDG_CACHE_HOME=$PWD/.cache
      mkdir -p $XDG_CACHE_HOME
      mkdir -p build
      pushd build
      cmake \
        -DUSE_CONDA=FALSE \
        -DCMAKE_INSTALL_PREFIX=$out \
        -DYOSYS_DATADIR="${yosys}/share/yosys" \
        -DVPR_CAPNP_SCHEMA_DIR="${vtr}/capnp" \
        -DINSTALL_DEVICE=xc7a200t \
        ..
      popd
    '';
  });

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

  inherit (sources) prjxray-db;

  prjxray = stdenv.mkDerivation {
    name = "prjxray";
    src = sources.prjxray;
    postPatch = ''
      patchShebangs utils
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
      ln -s ${prjxray-db} $out/database
    '';

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export phases="patchPhase configurePhase buildPhase"
    '';
  };

  nextpnr-xilinx = stdenv.mkDerivation {
    name = "nextpnr-xilinx";
    src = sources.nextpnr-xilinx;
    nativeBuildInputs = [ cmake ];
    buildInputs = [
      yosys-git
      prjxray
      python37
      (boost.override { python = python37; enablePython = true; })
      eigen
    ] ++ optionals stdenv.cc.isClang [
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

  mac-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        sysctl -a | grep machdep.cpu
  '';

  no-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        echo "lscpu not available"
  '';

  prjxray-config = writeScriptBin "prjxray-config" ''
    #!${pkgs.stdenv.shell}
    echo "${prjxray-db}"
  '';

  capnp-schemas-dir = writeScriptBin "capnp-schemas-dir" ''
    #!${pkgs.stdenv.shell}
    echo "${vtr}/capnp"
  '';

  fpga-tool-perf = make-fpga-tool-perf {};
  fpga-tool-perf-test = make-fpga-tool-perf {
    constants = {
      "vpr/src/route/bucket.cpp" = {
        kMaxMaxBuckets = 42;
      };
    };
  };
  make-fpga-tool-perf = options@{extra_vpr_flags ? {}, constants ? {}}: let
    src = sources.fpga-tool-perf;
    default_vpr_flags = {
      max_router_iterations = 500;
      routing_failure_predictor = "off";
      router_high_fanout_threshold = -1;
      constant_net_method = "route";
      route_chan_width = 500;
      router_heap = "bucket";
      clock_modeling = "route";
      place_delta_delay_matrix_calculation_method = "dijkstra";
      place_delay_model = "delta_override";
      router_lookahead = "extended_map";
      check_route = "quick";
      strict_checks = "off";
      allow_dangling_combinational_nodes = "on";
      disable_errors = "check_unbuffered_edges:check_route";
      congested_routing_iteration_threshold = 0.8;
      incremental_reroute_delay_ripup = "off";
      base_cost_type = "delay_normalized_length_bounded";
      bb_factor = 10;
      initial_pres_fac = 4.0;
      check_rr_graph = "off";
      suppress_warnings = "noisy_warnings.log,sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R:check_route:set_rr_graph_tool_comment:calculate_average_switch";
    };
    vpr_flags = default_vpr_flags // extra_vpr_flags;
    mkTest = { projectName, toolchain, board }: let
      symbiflow-arch-defs-install = if board == "nexys-video" then symbiflow-arch-defs-200t else symbiflow-arch-defs;
    in stdenv.mkDerivation rec {
      name = "fpga-tool-perf-${projectName}-${toolchain}-${board}";
      inherit src;
      usesVPR = hasPrefix "vpr" toolchain;
      yosys = yosys-symbiflow-run;
      vtr = vtr-custom constants;
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
        scalene
        simplejson
        symbiflow-xc-fasm2bels
        terminaltables
        textx
        tqdm
        xc-fasm
        yapf
      ]);
      buildInputs = [
        capnp-schemas-dir
        coreutils
        getopt
        icestorm
        nextpnr
        nextpnr-xilinx
        prjxray
        prjxray-config
        python-with-packages
        symbiflow-arch-defs-install
        vtr
        yosys
      ] ++ optionals stdenv.isLinux [
        no-lscpu
      ] ++ optionals stdenv.isDarwin [
        mac-lscpu
      ];
      toolchain-arg = if toolchain == "vivado-yosys" then "yosys-vivado" else toolchain;
      buildPhase = ''
        cat << EOF > env.sh
        export PYTHONPATH=${prjxray}
        export VIVADO_SETTINGS=${vivado_settings}
        export XRAY_DATABASE_DIR=${prjxray-db}
        export XRAY_FASM2FRAMES="-m prjxray.fasm2frames"
        export XRAY_TOOLS_DIR="${prjxray}/bin"
        export SYMBIFLOW="${symbiflow-arch-defs-install}"
        export FPGA_TOOL_PERF_BASE_DIR=$(pwd)
        EOF
        source env.sh

        mkdir -p env/conda/pkgs
        rm -f env/conda/pkgs/nextpnr-xilinx
        ln -s ${nextpnr-xilinx} env/conda/pkgs/nextpnr-xilinx
        source $VIVADO_SETTINGS
        python3 fpgaperf.py \
          --project ${projectName} \
          --toolchain ${toolchain-arg} \
          --board ${board} \
          --out-dir $out \
          --verbose \
          ${optionalString usesVPR '' --params_string='${flags_to_string vpr_flags}' ''}
      '';
      installPhase = ''
        mkdir -p $out/nix-support
        cp ${vtr}/constants.patch $out
        cat <<EOF > $out/options.json
        ${toJSON options}
        EOF
        echo "file json $out/meta.json" > $out/nix-support/hydra-build-products
        find $out \
            -type f \
          ! -name meta.json \
          ! -name hydra-build-products \
            -printf "file data %p\n" >> $out/nix-support/hydra-build-products
      '';
      shellHook = ''
        export PYTHONPATH=${prjxray}
        export VIVADO_SETTINGS=${vivado_settings}
        export XRAY_DATABASE_DIR=${prjxray-db}
        export XRAY_FASM2FRAMES="-m prjxray.fasm2frames"
        export XRAY_TOOLS_DIR="${prjxray}/bin"
        export SYMBIFLOW="${symbiflow-arch-defs-install}"
        export FPGA_TOOL_PERF_BASE_DIR=$(pwd)
        export LD_LIBRARY_PATH=${lib.makeLibraryPath [stdenv.cc.cc]}
      '';
      requiredSystemFeatures = [ "benchmark" ]; # only run these on benchmark machines
    };
    projectNames = map (n: head (match "([^.]*).json$" n)) (attrNames (readDir (src + "/project/")));
    boards = fromJSON (readFile (src + "/other/boards.json"));
  in
    listToAttrs (map (projectName:
      let
        projectInfo = fromJSON (readFile (src + "/project/${projectName}.json"));
        boards = concatMap (vendor: projectInfo.vendors.${vendor}) (attrNames projectInfo.vendors);
        mkBoard = toolchain: board: {
          name = board;
          value = mkTest { inherit projectName toolchain board; };
        };
        mkToolchain = toolchain: {
          name = toolchain;
          value = listToAttrs (map (mkBoard toolchain) boards);
        };
      in
        {
          name = projectName;
          value = listToAttrs (map mkToolchain projectInfo.required_toolchains);
        }) projectNames);

  symbiflow-examples = stdenv.mkDerivation rec {
    name = "symbiflow-examples";
    src = sources.symbiflow-examples;
    yosys = yosys-symbiflow;
    python-with-packages = python.withPackages (p: with p; [
      lxml
      simplejson
      intervaltree
      python-constraint
      python-prjxray
      fasm
      textx
    ]);
   buildInputs =  [
      symbiflow-arch-defs-install
      yosys
      vtr
      python-with-packages
      prjxray
    ];
    shellHook = ''
      export XRAY_DATABASE_DIR=${prjxray-db}
      export XRAY_FASM2FRAMES="-m prjxray.fasm2frames"
      export XRAY_TOOLS_DIR="${prjxray}/bin"
      #export SYMBIFLOW="${symbiflow-arch-defs-install}"
    '';
  };

  litex-buildenv = let
    riscvPkgs = bits: import source.nixpkgs {
      crossSystem = {
        config = "riscv${bits}-none-elf";
        libc = "newlib";
        platform = systems.platforms.riscv-multiplatform "${bits}";
      };
    };
    with-litex-buildenv = attrs@{ name, platform, cpu, target, bits }:
      (riscvPkgs bits).stdenv.mkDerivation rec {
        name = "litex-buildenv-${attrs.name}";
        src = fetchgit {
          url = "https://github.com/timvideos/litex-buildenv.git";
          rev = "bbe77980b3006f0c656dab3b9fa886eb0c86f59b";
          sha256 = "0c8js5mvj2fdpfqcwz5w90yn091223an09573jxd2x9r08krsi4y";
          leaveDotGit = true;
          deepClone = true;
        };
        python-with-packages = python.withPackages (p:
          with p.litexPackages;
          [
            litex
            liteeth
            litedram
            litepcie
            litevideo
            liteiclink
            litesdcard
            litex-boards
            pythondata-cpu-vexriscv
            pythondata-cpu-rocket
          ]);
        nativeBuildInputs = [
          python-with-packages
          verilator
          dtc
          git
          vivado
        ];
        patches = [ ./patches/litex-buildenv.patch ];
        buildPhase = ''
          export PLATFORM=${platform}
          export CPU=${cpu}
          export TARGET=${target}
          python make.py --platform=${platform} --cpu-type=${cpu} --cpu-variant=linux --target=${target}
        '';
        installPhase = ''
          cp -r build $out
        '';
      };
    configs = mapAttrs (name: attrs: with-litex-buildenv (attrs // { inherit name; }));
  in
    configs {
      vexriscv = {
        platform = "arty";
        cpu = "vexriscv";
        target = "base";
        bits = "64";
      };
      rocket = {
        platform = "arty";
        cpu = "rocket";
        target = "base";
        bits = "64";
      };
    };

  with-yosys-git = mkShell {
    buildInputs = [ yosys-git ];
  };
}

# Local Variables:
# eval: (add-to-list 'imenu-generic-expression '("Package" "^  \\([a-zA-Z0-9_-]+\\) =.*$" 1))
# End:
