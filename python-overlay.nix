{ pkgs, pythonPackages, prjxray }:

self: super:

with pkgs;
with lib;
with pythonPackages;
with self;

{
  # SymbiFlow Python packages
  mkSFPy = attrs@{ name, ref ? "master", user ? "SymbiFlow", ... }: buildPythonPackage ({
    src = fetchGit {
      url = "https://github.com/${user}/${name}.git";
      inherit ref;
    };
    doCheck = false;
  } // attrs);

  fasm = mkSFPy {
    name = "fasm";
    buildInputs = [ textx ];
    patches = [ ./patches/fasm.patch ];
  };

  python-sdf-timing = mkSFPy {
    name = "python-sdf-timing";
    propagatedBuildInputs = [ pyjson ply pytestrunner ];
  };

  vtr-xml-utils = mkSFPy {
    name = "vtr-xml-utils";
    propagatedBuildInputs = [ lxml pytestrunner ];
  };

  python-symbiflow-v2x = mkSFPy {
    name = "python-symbiflow-v2x";
    propagatedBuildInputs = [ lxml pytestrunner pyjson vtr-xml-utils ];
  };

  python-prjxray = mkSFPy {
    name = "prjxray";
    src = head (prjxray.srcs);
  };

  edalize = mkSFPy {
    name = "edalize";
    ref = "symbiflow";
    patches = [ ./patches/edalize.patch ];
    propagatedBuildInputs = [ pytest jinja2 ];
  };

  # symbiflow-xc-fasm2bels = mkSFPy {
  #   name = "symbiflow-xc-fasm2bels";
  #   user = "antmicro";
  #   ref = "add-fasm2bels";
  #   nativeBuildInputs = [ git python-prjxray ];
  # };

  # third party Python packages
  textx = buildPythonPackage rec {
    pname = "textX";
    version = "1.8.0";
    src = fetchPypi {
      inherit pname version;
      sha256 = "1vhc0774yszy3ql5v7isxr1n3bqh8qz5gb9ahx62b2qn197yi656";
    };
    doCheck = false;
    propagatedBuildInputs = [ arpeggio ];
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
}
