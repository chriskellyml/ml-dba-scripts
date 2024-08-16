xquery version "1.0-ml";
(:~
 : This query should be run from the MarkLogic query console.
 : @DEFAULTS:database=Documents
 :)
declare namespace dir = "http://marklogic.com/xdmp/directory";

declare variable $DRY_RUN := true();
declare variable $PATH := '/tmp/foo';

(: I M P L E M E N T A T I O N :)
declare function local:list-files($directory as xs:string) as xs:string* {
  let $entries := xdmp:filesystem-directory($directory)/dir:entry
  let $files :=
    for $entry in $entries
    where $entry/dir:type = "file"
    return $entry/dir:pathname
  let $directories :=
    for $entry in $entries
    where $entry/dir:type = "directory"
    return $entry/dir:pathname
  return
    ($files,
     for $subdir in $directories
     return local:list-files($subdir))
};

if (xdmp:database-name(xdmp:database()) ne 'Documents') then ("", "Please change to database to Documents to continue!", "") else
  let $files := local:list-files($PATH)
  let $timestamp := fn:substring(fn:replace(xs:string(fn:current-dateTime()), '[^0-9]', ''), 1, 15)
  let $name := fn:string-join($timestamp, '_') || '.zip'
  let $dlUri := "/export/" || xdmp:get-current-user() || "/files_" || $name
  let $contents := xdmp:zip-create(
    <parts xmlns="xdmp:zip">{$files ! <part>{.}</part>}</parts>, 
    ($files ! xdmp:external-binary(.))
  )
  return xdmp:document-insert($dlUri, $contents)

