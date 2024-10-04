xquery version "1.0-ml";

declare variable $uri := "/test/test.xml";
declare variable $filename := fn:substring-before(fn:tokenize($uri,"/")[last()],".");
declare variable $overwrite:= false();

let $doc := fn:doc($uri)
let $tmpfile := '/tmp/' || fn:uuid()
return (
  xdmp:invoke-function(
    function() {
      xdmp:save('/tmp/' $uuid, $doc)
    }
  ),
  xdmp:invoke-function(
    function() {
      xdmp:document-load(
        $tmpfile,
        map:map() 
          => map:with("uri", if ($overwrite) then $uri else ($uri || ".bin"))
          => map:with("format", "binary"))
    }
  ),
  xdmp:invoke-function(
    function() {
      xdmp:file-delete($tmpfile)
    }
  ),
);
