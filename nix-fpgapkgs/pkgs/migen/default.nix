{ stdenv, fetchFromGitHub, python, buildPythonPackage,
  colorama, sphinx, sphinx_rtd_theme, verilator }:

buildPythonPackage rec {
  version = "0.9.2";
  pname = "migen";
  name = "${pname}-${version}";

  src = fetchGit {
    url = "https://github.com/m-labs/migen.git";
    rev = "94db7295fd4942d0ee27de1148a6cc7be356329d";
  };

  propagatedBuildInputs = [ colorama sphinx sphinx_rtd_theme verilator ];

  meta = with stdenv.lib; {
    description = "A Python toolbox for building complex digital hardware";
    homepage    = "https://m-labs.hk/gateware.html";
    license     = licenses.bsd2;
    platforms   = platforms.unix;
  };
}
