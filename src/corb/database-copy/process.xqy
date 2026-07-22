xquery version "1.0-ml";

declare namespace prop = "http://marklogic.com/xdmp/property";
declare namespace sec  = "http://marklogic.com/xdmp/security";

declare variable $URI    as xs:string external;
declare variable $SOURCE as xs:string external;
declare variable $TARGET as xs:string external;
declare private variable $SRC-OPTS := <options xmlns="xdmp:eval"><database>{ xdmp:database($SOURCE) }</database></options>
declare private variable $TGT-OPTS := <options xmlns="xdmp:eval"><database>{ xdmp:database($TARGET) }</database><<transaction-mode>update</transaction-mode></options>

declare private function local:in-source($fn) { xdmp:invoke-function($fn , $SRC-OPTS) };
declare private function local:in-target($fn) { xdmp:invoke-function($fn , $SRC-OPTS) };

let $uris := fn:tokenize($URI, ";")
let $_ := xdmp:log("Processing " || count($uris) || " uris. First is: " || $uris[1])
for $uri in $uris 
(: Read from source. xdmp:invoke-function returns item()* so JSON
   nodes, XML nodes, binary nodes and text all pass through intact. :)
let $_ := local-in-source(function() {
  if (not(doc-available($uri)))
  then fn:error((), "URI not availble: " || $uri )
  else ()
})
let $perms   := local:in-source(function() { xdmp:document-get-permissions($uri) }) 
let $colls   := local:in-source(function() { xdmp:document-get-collections($uri) })
let $quality := local:in-source(function() { xdmp:document-get-quality($uri) })
let $props   := local:in-source(
  function() {
    xdmp:document-properties($uri)/*[
      fn:node-name(.) ne xs:QName("prop:directory") and
      fn:node-name(.) ne xs:QName("prop:last-modified")
    ]
  }
)
let $meta := local:in-source(function() { xdmp:document-get-metadata($uri) })
let $node := local:in-source(function() { 
  let $data := fn:doc($uri)/node() 
  return 
    if (empty($data))
    then fn:error((), "Empty data for URI " || $uri)
    else ()
})

(: Write into target database :)
return local:in-target(
  function() {
    xdmp:document-insert($uri, $node, $perms, $colls, xs:integer($quality)),
    if (fn:exists($props))
    then xdmp:document-set-properties($uri, $props)
    else (),
    xdmp:document-set-metadata($uri, if (fn:exists($meta)) then $meta else map:map())
  }
)
