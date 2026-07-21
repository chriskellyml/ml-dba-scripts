xquery version "1.0-ml";

declare namespace prop = "http://marklogic.com/xdmp/property";
declare namespace sec  = "http://marklogic.com/xdmp/security";

declare variable $URI    as xs:string external;
declare variable $SOURCE as xs:string external;
declare variable $TARGET as xs:string external;

for $uri in fn:tokenize($URI, ";")

(: Read from source. xdmp:invoke-function returns item()* so JSON
   nodes, XML nodes, binary nodes and text all pass through intact. :)
let $perms := xdmp:invoke-function(
  function() { xdmp:document-get-permissions($uri) },
  <options xmlns="xdmp:eval"><database>{ xdmp:database($SOURCE) }</database></options>
)
let $colls := xdmp:invoke-function(
  function() { xdmp:document-get-collections($uri) },
  <options xmlns="xdmp:eval"><database>{ xdmp:database($SOURCE) }</database></options>
)
let $quality := xdmp:invoke-function(
  function() { xdmp:document-get-quality($uri) },
  <options xmlns="xdmp:eval"><database>{ xdmp:database($SOURCE) }</database></options>
)
let $props := xdmp:invoke-function(
  function() {
    xdmp:document-properties($uri)/*[
      fn:node-name(.) ne xs:QName("prop:directory") and
      fn:node-name(.) ne xs:QName("prop:last-modified")
    ]
  },
  <options xmlns="xdmp:eval"><database>{ xdmp:database($SOURCE) }</database></options>
)
let $meta := xdmp:invoke-function(
  function() { xdmp:document-get-metadata($uri) },
  <options xmlns="xdmp:eval"><database>{ xdmp:database($SOURCE) }</database></options>
)
let $node := xdmp:invoke-function(
  function() { fn:doc($uri)/node() },
  <options xmlns="xdmp:eval"><database>{ xdmp:database($SOURCE) }</database></options>
)

(: Write into target database :)
return xdmp:invoke-function(
  function() {
    xdmp:document-insert($uri, $node, $perms, $colls, xs:integer($quality)),
    if (fn:exists($props))
    then xdmp:document-set-properties($uri, $props)
    else (),
    xdmp:document-set-metadata($uri, if (fn:exists($meta)) then $meta else map:map())
  },
  <options xmlns="xdmp:eval">
    <database>{ xdmp:database($TARGET) }</database>
    <transaction-mode>update</transaction-mode>
  </options>
)
