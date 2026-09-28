{ nixfmt, fetchFromGitHub }:

nixfmt.overrideAttrs {
  dontVersionCheck = true;
  src = fetchFromGitHub {
    owner = "llakala";
    repo = "nixfmt";
    rev = "70a028bb68f85f3be61c75d55ec3ad480859a666";
    hash = "sha256-g7LXG89RnvdA6PjoA2j6jMSCf0pdhqhZEDKqGCYgWrE=";
  };
}
