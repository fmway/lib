set -l url $argv[1]
set -e argv[1]
set opts $argv
string match -rq "[-]{2}name" -- "$opts" || set -p opts --name source
nix store prefetch-file $url $opts &| string replace -r '^.*[(]hash\s+\'(.+)\'[)].*$' '$1'
