{
  python3,
  writeShellScriptBin,
}:

# Wiki ingestion for the project vault. Depends only on mwparserfromhell: the
# MediaWiki API is talked to with urllib, so there is no HTTP client to pin.
writeShellScriptBin "lore-ingest" ''
  exec ${
    python3.withPackages (ps: [ ps.mwparserfromhell ])
  }/bin/python3 ${../scripts/lore-ingest.py} "$@"
''
