# Bundle sql scripts as a Nix package so that it can be deployed into a server.
{runCommand, ...}:
runCommand "migration-data" { } ''
  mkdir $out
  cp -r ${../db/migrations}/*.sql $out
''