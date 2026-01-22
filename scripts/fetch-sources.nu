def main [path: string] {
  open $path | transpose k v | each {|$i|
    let others = ($i.v | reject -o url hash sha256)
    let url = if $i.v.mainUrl? != null {
      curl -w '%{url_effective}\n' $i.v.mainUrl -I -L -s -S  -o /dev/null
    } else {
      $i.v.url
    }
    let hash = if $i.v.type? != "file" {
      get-hash $url --unpack
    } else {
      get-hash $url
    }

    { $i.k: ({ url: $url, hash: $hash } | merge { ...$others }) }
  } | into record | to json
}
