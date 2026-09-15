def --wrapped get-hash [url: string, --name (-n): string = "source", ...args] {
  nix store prefetch-file $url --name $name ...$args o+e>| str replace -r "^.*[(]hash\\s+'([^']+)'.*$" '$1'
}

def main [path: string] {
  open $path | transpose k v | each {|$i|
    let others = ($i.v | reject -o url hash sha256)
    let url = if $i.v.mainUrl? != null {
      if ($i.v.mainUrl | str contains "codeberg.org") {
        let r = http head $i.v.mainUrl | where {|e| $e.name == "link"} | get 0.value | parse '<{link}>;{_}' | get 0.link
        sleep 2sec
        $r
      } else {
        curl -w '%{url_effective}\n' $i.v.mainUrl -I -L -s -S  -o /dev/null
      }
    } else {
      $i.v.url
    }
    let hash = if $i.v.type? != "file" {
      get-hash $url --unpack
    } else {
      get-hash $url
    }

    sleep 2sec
    { $i.k: ({ url: $url, hash: $hash } | merge { ...$others }) }
  } | into record | to json
}
