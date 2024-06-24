xquery version "1.0-ml";

declare variable $FOLDER_TO_LIST as xs:string := '/tmp/backups/Security';
 
declare function local:recursive-copy(
  $filesystem as xs:string
) as item()*
{
  for $e in xdmp:filesystem-directory($filesystem)/dir:entry
  return 
    if ($e/dir:type/text() = "file")
    then $e/dir:pathname/text()
    else local:recursive-copy($e/dir:pathname)
};
 
declare function local:zip-manifest(
  $filelist as xs:string*
) as element()
{
<parts xmlns="xdmp:zip">{ $filelist ! <part>{.}</part>}</parts>
};
 
declare function local:zip-content(
  $filelist as xs:string
) as item()*
{
  $filelist ! xdmp:external-binary(.)
};
 
let $filelist := local:recursive-copy($FOLDER_TO_ZIP)
return $filelist
 
