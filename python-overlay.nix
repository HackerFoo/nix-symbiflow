{ pkgs, sources, pythonPackages, prjxray, migen }:

self: super:

with pkgs;
with lib;
with pythonPackages;
with self;

let

  # Build a set with only the attributes listed in `names` from `attrs`.
  intersectAttrs = names: attrs: getAttrs (intersectLists names (attrNames attrs)) attrs;

in

rec {
  fasm = buildPythonPackage {
    name = "fasm";
    src = sources.fasm;
    buildInputs = [ textx ];
    doCheck = false;
  };

  python-sdf-timing = buildPythonPackage {
    name = "python-sdf-timing";
    src = sources.python-sdf-timing;
    propagatedBuildInputs = [ pyjson ply pytestrunner ];
    doCheck = false;
  };

  vtr-xml-utils = buildPythonPackage {
    name = "vtr-xml-utils";
    src = sources.vtr-xml-utils;
    propagatedBuildInputs = [ lxml pytestrunner ];
    doCheck = false;
  };

  python-symbiflow-v2x = buildPythonPackage {
    name = "python-symbiflow-v2x";
    src = sources.python-symbiflow-v2x;
    propagatedBuildInputs = [ lxml pytestrunner pyjson vtr-xml-utils ];
    doCheck = false;
  };

  python-prjxray = buildPythonPackage {
    name = "prjxray";
    inherit (prjxray) src;
    doCheck = false;
  };

  edalize = buildPythonPackage {
    name = "edalize";
    src = sources.edalize;
    propagatedBuildInputs = [ pytest jinja2 ];
    patches = [ ./patches/edalize.patch ];
    doCheck = false;
  };

  symbiflow-xc-fasm2bels = buildPythonPackage {
    name = "symbiflow-xc-fasm2bels";
    src = sources.symbiflow-xc-fasm2bels;
    propagatedBuildInputs = [
      fasm
      intervaltree
      parameterized
      progressbar2
      pycapnp
      python-prjxray
      rr_graph
      simplejson
      textx
    ];
    doCheck = false;
  };

  rr_graph = buildPythonPackage {
    name = "symbiflow-rr-graph";
    src = sources.symbiflow-rr-graph;
    propagatedBuildInputs = [ simplejson pycapnp lxml ];
    doCheck = false;
  };

  xc-fasm = buildPythonPackage {
    name = "xc-fasm";
    src = sources.xc-fasm;
    propagatedBuildInputs = [ textx simplejson intervaltree python-prjxray fasm yapf ];
    doCheck = false;
  };

  # third party Python packages
  textx = buildPythonPackage rec {
    pname = "textX";
    version = "1.8.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "1vhc0774yszy3ql5v7isxr1n3bqh8qz5gb9ahx62b2qn197yi656";
    };
    doCheck = false;
    propagatedBuildInputs = [ arpeggio setuptools ];
  };

  hilbertcurve = buildPythonPackage rec {
    pname = "hilbertcurve";
    version = "1.0.1";
    src = fetchPypi {
      inherit pname version;
      sha256 = "b1ddf58f529219d3b76e8b61ed03e2975a724aff4848b720397c7d5601f49521";
    };
    doCheck = false;
  };

  pycapnp = buildPythonPackage rec {
    pname = "pycapnp";
    version = "1.0.0b1";
    src = fetchPypi {
      inherit pname version;
      sha256 = "0sd1ggxbwi28d9by7wg8yp9av4wjh3wy5da6sldyk3m3ry3pwv65";
    };
    doCheck = false;
    propagatedBuildInputs = [ cython capnproto ];
  };

  tinyfpgab = buildPythonPackage rec {
    pname = "tinyfpgab";
    version = "1.1.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "1dmpcckz7ibkl30v58wc322ggbcw7myyakb4j6fscm6xav23k4bg";
    };
    doCheck = false;
    propagatedBuildInputs = [ pyserial ];
  };

  pyjson = buildPythonPackage rec {
    pname = "pyjson";
    version = "1.3.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "0a4nkmc9yjpc8rxkqvf3cl3w9hd8pcs6f7di738zpwkafrp36grl";
    };
    doCheck = false;
  };

  python-constraint = buildPythonPackage rec {
    pname = "python-constraint";
    version = "1.4.0";
    src = fetchPypi {
      inherit pname version;
      extension = "tar.bz2";
      sha256 = "13nbgkr1w0v1i59yh01zff9gji1fq6ngih56dvy2s0z0mwbny7ah";
    };
    patches = [ ./patches/python-constraint.patch ];
    doCheck = false;
  };

  asciitable = buildPythonPackage rec {
    pname = "asciitable";
    version = "0.8.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "04mnd8zyphsdk5il6khsx38yxm0c1g10hkz5jbxg70i15hzgcbyw";
    };
    doCheck = false;
  };

  jinja2 = buildPythonPackage rec {
    pname = "Jinja2";
    version = "2.11.2";
    src = fetchPypi {
      inherit pname version;
      sha256 = "1c1v3djnr0ymp5xpy1h3h60abcaqxdlm4wsqmls9rxby88av5al9";
    };
    doCheck = false;
    propagatedBuildInputs = [ markupsafe ];
  };

  ipyxact = buildPythonPackage rec {
    pname = "ipyxact";
    version = "0.2.4";
    src = fetchPypi {
      inherit pname version;
      sha256 = "18mvgwnj7ccnrqx7x3cg70fyklrkymf9nadb0sh3is5csmz8gj7b";
    };
    propagatedBuildInputs = [ pyyaml ];
    doCheck = false;
  };

  simplesat = buildPythonPackage rec {
    pname = "simplesat";
    version = "0.8.2";
    src = fetchPypi {
      inherit pname version;
      sha256 = "0n6qm2gzwji19ykp3i6wm6vjw7dnn92h2flm42708fxh6lkz6hqr";
    };
    propagatedBuildInputs = [ okonomiyaki attrs six enum34 ];
    doCheck = false;
  };

  okonomiyaki = buildPythonPackage rec {
    pname = "okonomiyaki";
    version = "1.2.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "0cak484nldyp4l2f12xlmn8qpz32k7dwf2h688g90368mliqdh3f";
    };
    propagatedBuildInputs = [ attrs six jsonschema zipfile2 ];
    doCheck = false;
  };

  zipfile2 = buildPythonPackage rec {
    pname = "zipfile2";
    version = "0.0.12";
    src = fetchPypi {
      inherit pname version;
      sha256 = "0256m134qs045j1c8mmgii8ipkwhww9sjbc6xyawhykid34zfxkk";
    };
    doCheck = false;
  };

  cloudpickle = buildPythonPackage rec {
    pname = "cloudpickle";
    version = "1.5.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "820c9245cebdec7257211cbe88745101d5d6a042bca11336d78ebd4897ddbc82";
    };
    buildInputs = [ pytest mock ];
    doCheck = false;
  };

  rich = let
    pygments = buildPythonPackage rec {
      pname = "Pygments";
      version = "2.6.1";
      src = fetchPypi {
        inherit pname version;
        sha256 = "647344a061c249a3b74e230c739f434d7ea4d8b1d5f3721bc0f3558049b38f44";
      };
      propagatedBuildInputs = [ docutils ];
      doCheck = false;
    };
  in buildPythonPackage rec {
    pname = "rich";
    version = "8.0.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "15yz7rcn5cjv233xcvka9vd573pwafl31s6z9ni54r8y4k926l0v";
    };
    propagatedBuildInputs = [ CommonMark typing-extensions colorama pygments ];
    doCheck = false;
  };

  scalene = buildPythonPackage rec {
    pname = "scalene";
    version = "1.1.4";
    src = fetchPypi {
      inherit pname version;
      sha256 = "1vbdmj159va6ylifzgiynr2wkg6ag0my3jn1km97ray1b34cs26r";
    };
    propagatedBuildInputs = [ cloudpickle rich ];
    doCheck = false;
  };

  litexPackages = let
    buildLitexPackages = attrs: listToAttrs (concatMap (user:
      map (name: {
        inherit name;
        value = buildPythonPackage {
          inherit name;
          src = fetchGit {
            url = "https://github.com/${user}/${name}";
          };
          propagatedBuildInputs = [ pyyaml ];
          doCheck = false;
        };
      }) attrs.${user}) (attrNames attrs));
    packages = buildLitexPackages {
      enjoy-digital = [
        "litex"
        "liteeth"
        "litedram"
        "litepcie"
        "litevideo"
        "liteiclink"
        "litesdcard"
      ];
      litex-hub = [
        "litex-boards"
        "pythondata-cpu-vexriscv"
        "pythondata-cpu-rocket"
        "pythondata-software-compiler_rt"
      ];
    };
  in packages // (with packages; {
    litex = buildPythonPackage rec {
      name = "litex";
      src = fetchGit {
        url = "https://github.com/enjoy-digital/litex.git";
        rev = "56aa7897df99d7ad68ea537ab096c3abdc683666"; # 2020.04
      };
      propagatedBuildInputs = [ migen pyserial requests pythondata-software-compiler_rt ];
      doCheck = false;
      postPatch = ''
        cat << 'EOF' >> MANIFEST.in
        graft litex/soc/software
        graft litex/soc/cores/cpu/blackparrot
        graft litex/soc/cores/cpu/lm32
        graft litex/soc/cores/cpu/microwatt
        graft litex/soc/cores/cpu/minerva
        graft litex/soc/cores/cpu/mor1kx
        graft litex/soc/cores/cpu/picorv32
        graft litex/soc/cores/cpu/rocket
        graft litex/soc/cores/cpu/serv
        graft litex/soc/cores/cpu/vexriscv
        EOF
      '';
    };
  });

  edalize-lowRISC = buildPythonPackage {
    name = "edalize-lowRISC";
    src = sources.edalize-lowRISC;
    propagatedBuildInputs = [ pytest jinja2 ];
    doCheck = false;
  };

  fusesoc-lowRISC = buildPythonPackage {
    name = "fusesoc-lowRISC";
    src = sources.fusesoc-lowRISC;
    propagatedBuildInputs = [ edalize-lowRISC ipyxact pyparsing pyyaml simplesat setuptools_scm ];
    nativeBuildInputs = [ pkgs.git ];
    doCheck = false;
  };

}

# Local Variables:
# eval: (add-to-list 'imenu-generic-expression '("Package" "^  \\([a-zA-Z0-9_-]+\\) =.*$" 1))
# End:
