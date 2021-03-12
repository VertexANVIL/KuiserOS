{ buildPythonPackage
, fetchPypi
, requests
, pathspec
, otherstuf
, launchpadlib
}:

buildPythonPackage rec {
    pname = "charm-tools";
    version = "2.8.3";

    src = fetchPypi {
        inherit pname version;
        sha256 = "sha256-H9f9vt1nh5Zap1mSBCl5s1TyqsY7sj6hhbZfNxz07h9=";
    };

    propagatedBuildInputs = [
        requests
        pathspec
        otherstuf
        launchpadlib
    ];
}