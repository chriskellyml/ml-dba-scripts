xquery version "1.0-ml";

declare variable $URI as xs:string external;
declare variable $TARGET as xs:string external;
declare namespace prop = "http://marklogic.com/xdmp/property";

for $uri in fn:tokenize($URI, ";")
let $document := fn:doc($uri)
let $root := $document/node()
let $permissions := xdmp:document-get-permissions($uri)
let $collections := xdmp:document-get-collections($uri)
let $quality := xdmp:document-get-quality($uri)
let $properties := xdmp:document-properties($uri)/*[
  fn:node-name(.) ne xs:QName("prop:directory") and
  fn:node-name(.) ne xs:QName("prop:last-modified")
]
let $metadata := xdmp:document-get-metadata($uri)
return
  xdmp:invoke-function(
    function() {
      xdmp:document-insert(
        $uri,
        $root,
        $permissions,
        $collections,
        $quality
      ),
      xdmp:document-set-properties($uri, $properties),
      xdmp:document-set-metadata(
        $uri,
        if (fn:exists($metadata)) then $metadata else map:map()
      )
    },
    <options xmlns="xdmp:eval">
      <database>{xdmp:database($TARGET)}</database>
      <transaction-mode>update</transaction-mode>
    </options>
  )
