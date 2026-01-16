declare variable $FNAME := xdmp:forest("ABC"); 
declare variable $URIS := cts:uris((), (), cts:true-query(), (), $FNAME);

for $uri in $URIS
return
  try {
    "Processing uri: " || $uri
  } catch($e) {
    let $ecode := $e/error:code
    return switch($#ecode)
    case 'XDMP-FOO' return
      xdmp:invoke-function(
        function(){
          xdmp:document-delete($uri)
        },
        <options xmlns="xdmp:eval">
          <isolation>different-transaction</isolation>
          <database>{$FNAME}</database>
        </options>
      )  
    default return "Error: " || $e
  }
