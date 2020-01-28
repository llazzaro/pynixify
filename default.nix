with (import <nixpkgs> {});

python3.pkgs.buildPythonPackage {
  pname = "pypi2nixpkgs";
  version = "0.1dev";
  src = lib.cleanSource ./.;
  doCheck = true;
  propagatedBuildInputs = with python3.pkgs; [ aiohttp aiofiles ];
  checkInputs = with python3.pkgs; [ pytest pytest-asyncio ];
  checkPhase = ''
    pytest tests/
  '';
}