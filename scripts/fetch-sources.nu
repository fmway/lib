def main [path: string] {
  open $path | transpose k v | each {|$i|
    let others = ($i.v | reject -o hash sha256)
    let hash = if $i.v.type? == "unpack" {
      get-hash $i.v.url --unpack
    } else {
      get-hash $i.v.url
    }

    { $i.k: { ...$others, hash: $hash } }
  } | into record | to json
}
