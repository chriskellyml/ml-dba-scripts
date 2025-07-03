xquery version "1.0-ml";

(::::      U S E R    P A R A M S     ::::)
declare variable $DRY_RUN := fn:true(); (: summarize what the query will do :)
(: Customize query for to build the list :)
declare variable $SELECT_QUERY :=
  let $type := 'foo'
  return cts:and-query((
    cts:collection-query('latest'),
    cts:collection-query('/' || $type),
  ));
(: For complex queries, it may be easier to export the list to the Documents database :)
declare variable $URI_LIST := (); (: doc('/uris/list.xml')//uri/xs:string(.); :)
declare variable $LIMIT := 5000;
declare variable $FORMAT := 'ZIP'; (: RAW, CSV, CSVZIP, ZIP :)

(::::   I M P L E M E N T A T I O N   ::::)
(:~
 : 1. Create a query used to select URIs
 : 2. Create a timestamp
 : 3. Create a dump
 : 4. Store the dump for download
 : 5. Return the result
 :)
if (xdmp:database-name(xdmp:database()) ne 'Documents') then ("", "Please change to database to Documents to continue!", "") else
  (: Create a query used to select URIs:)
  let $_ := ('csv', 'zip') ! cts:uri-match('/export/*/dump_2*' || .) ! xdmp:document-delete(.)
  let $OPTS := <options xmlns="xdmp:eval"><database>{xdmp:database('Documents')}</database></options>
  let $uris :=  if (not(empty($URI_LIST))) then $URI_LIST else xdmp:invoke-function(function() {
    cts:uris((), (), $SELECT_QUERY)[1 to $LIMIT]
  }, $OPTS)
  let $timestamp := fn:substring(fn:replace(xs:string(fn:current-dateTime()), '[^0-9]', ''), 1, 15)
  let $dump :=
    if ($FORMAT = "ZIP") then ()
    else xdmp:invoke-function(function() {
      let $rows := $uris ! (
        . || ',' ||
        fn:string-join(xdmp:document-get-collections(.), '|') || ',' ||
        xdmp:base64-encode(xdmp:quote(xdmp:document-get-permissions(.))) || ',' ||
        xdmp:base64-encode(xdmp:quote(doc(.)/node()))
      )
      let $headers := (
        "# Exported info ",
        "# "|| xdmp:quote(map:new((
          map:entry('host', xdmp:host-name(xdmp:host())),
          map:entry('time', fn:current-dateTime()),
          map:entry('dump_id', 'dump_' || $timestamp),
          map:entry('user', xdmp:get-current-user()),
          map:entry('count', count($uris)),
          map:entry('query', $SELECT_QUERY)
        ))),
        "URI,COLLECTIONS,PERMISSION,CONTENT"
      )
      return fn:string-join(($headers, $rows ), '&#10;')
    }, $OPTS)
          
  let $storeForDownload := function ($contents) {
    let $name := fn:string-join($timestamp, '_') || '.' || fn:lower-case($FORMAT)
    let $dlUri := "/export/" || xdmp:get-current-user() || "/dump_" || $name
    let $_ := xdmp:document-insert($dlUri, $contents)
    return (
        "Exported [" || count($uris) || "] documents in [" || xdmp:elapsed-time() || "]",
        "",
        "1. Click explore and click to download [" || $dlUri || "]",
        "",
        "2. To upload locally, 'cd' to browser 'Downloads' and run:",
        "",
        "  curl --digest --user admin:admin -X PUT --data-binary " || "@$(ls dump_2*.zip|tail -1) ""http://localhost:8000/v1/documents?uri=/import/dump.zip""",
        "  ^^ Consider adding above command as an alias in your shell rc file! ^^"
    )
  }
  return 
    if ($DRY_RUN)
    then (  
      "Found " || count($uris) || " documents",
      if ($FORMAT = "ZIP")
      then $uris[1 to 10]
      else fn:substring($dump, 1, 1000)
    )
    else
      switch ($FORMAT)
      case 'RAW' return $dump
      case 'CSV' return $storeForDownload(text { $dump })
      case 'CSVZIP' return $storeForDownload(xdmp:zip-create(<parts xmlns="xdmp:zip"><part>export_dump.csv</part></parts>, text { $dump }))
      case 'ZIP' return
        let $zip-content := xdmp:invoke-function(function() {
          xdmp:zip-create(
            <parts xmlns="xdmp:zip">{
              for $uri in $uris
              return <part>{fn:replace($uri, "^/", "")}</part>
            }</parts>,
            $uris ! doc($uri)
          )
        }, $OPTS)
        return $storeForDownload($zip-content)
      default return "Unsupport FORMAT [" || $FORMAT || ']'
