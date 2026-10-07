{ lib, python3, fetchurl }:

python3.pkgs.buildPythonApplication rec {
  pname = "bitchat-cli";
  version = "0.2.3";
  format = "pyproject";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/aa/4c/218fbe66469ff633fc0f1f51976cc83d4355c1f99a648dc5d489d05e4cda/bitchat_cli-${version}.tar.gz";
    hash = "sha256-Z8bFhCvJzUWbW/q3610wjzT47q173lW9/+u1dYu/fd4=";
  };

  build-system = with python3.pkgs; [ setuptools ];

  propagatedBuildInputs = with python3.pkgs; [
    bleak
    cryptography
    prompt-toolkit
  ];

  pythonImportsCheck = [ "bitchat_cli" ];

  meta = {
    description = "Serverless peer-to-peer chat over a Bluetooth LE mesh, wire-compatible with the bitchat app";
    homepage = "https://github.com/dearabhin/bitchat-cli";
    license = lib.licenses.gpl3Plus;
    mainProgram = "bitchat-cli";
  };
}
