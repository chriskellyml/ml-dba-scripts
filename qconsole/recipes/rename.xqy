xquery version "1.0-ml";

declare variable $OLD_URI := "/tmp/foo.xml";
declare variable $NEW_URI := "/tmp/bar.xml";

(: P L U M B I N G :)
let $_ := (
  xdmp:set-server-field("mldna-rename-old-name", $OLD_URI),
  xdmp:set-server-field("mldna-rename-new-name", $NEW_URI))
return
  if (fn:doc-available($OLD_URI))
  then
    xdmp:document-insert($NEW_URI, doc($OLD_URI),
      map:map() => map:with("collections", xdmp:document-get-collections($OLD_URI))
                => map:with("permissions", xdmp:document-get-permissions($OLD_URI))
                => map:with("quality", xdmp:document-get-quality($OLD_URI)))
  else 'Nothing to rename'
;
xquery version "1.0-ml";

let $OLD_URI := xdmp:get-server-field("mldna-rename-old-name")
let $NEW_URI := xdmp:get-server-field("mldna-rename-new-name")
return
  if (fn:doc-available($NEW_URI))
  then xdmp:document-delete($OLD_URI)
  else 'Document rename was not successful'
