xquery version "1.0-ml";
(: credit: https://developer.marklogic.com/recipe/move-a-document/ :)

let $old-uri := '/uri1.xml' (: change to original URI :)
let $new-uri := '/uri2.xml' (: change to desired URI :)
let $lock := ($old-uri, $new-uri) ! xdmp:lock-for-update(.)
let $prop-ns := fn:namespace-uri-from-QName(xs:QName("prop:properties"))
let $properties :=
  xdmp:document-properties($old-uri)/node()/node()
    [ fn:namespace-uri(.) ne $prop-ns ]
return (
  xdmp:document-insert(
    $new-uri,
    fn:doc($old-uri),
    xdmp:document-get-permissions($old-uri),
    xdmp:document-get-collections($old-uri)
  ),
  xdmp:document-delete($old-uri),
  xdmp:document-set-properties($new-uri, $properties)
)
