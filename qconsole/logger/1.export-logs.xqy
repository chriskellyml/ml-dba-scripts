xquery version "1.0-ml";
(:~
 : This query should be run from the MarkLogic query console.
 :)
declare variable $TYPE := 'ErrorLog';
declare variable $DRY_RUN := true();
declare variable $PORT_LIST := ();
declare variable $HOST_LIST := ();
declare variable $LOG_PATH := '/var/opt/MarkLogic/Logs';

(::::   I M P L E M E N T A T I O N   ::::)
if (xdmp:database-name(xdmp:database()) ne 'Documents') then ("", "Please change to database to Documents to continue!", "") else
  let $entries := (
    for $host in xdmp:hosts()
    for $entry in xdmp:filesystem-directory($LOG_PATH)//*:entry
    let $fn := $entry//*:filename/xs:string(.)
    where ends-with($fn, $TYPE || '.txt')
      and
        (: only give requested ports :)
        if (not(empty($PORT_LIST))) then ($PORT_LIST ! starts-with($fn, .)) else true()
      and
        (: skip empties :)
        $entry//*:content-length ne 0
      and
        $entry//*:type eq 'file'
      and
        (: only give requested hosts :)
        if (not(empty($HOST_LIST))) then ($HOST_LIST = xdmp:host-name($host)) else true()
    return 
      <logfile>
         <host>{xdmp:host-name($host)}</host>
         <filename>{$fn}</filename>
         <path>{'file://' || xdmp:host-name($host) || '/' || $entry/*:pathname/xs:string(.)}</path>
         <size>{$entry/*:content-length/xs:integer(.)}</size>
         <modified>{fn:substring($entry/*:last-modified/xs:string(.), 1, 10)}</modified>
      </logfile>)
  let $rawSize := fn:sum($entries/size/xs:integer(.))
  return
    if ($DRY_RUN)
    then (
      "Download " || count($entries) || " files.",
      "Total size uncompressed: " || $rawSize || ".",
      $entries
    )
    else
      let $timestamp := fn:substring(fn:replace(xs:string(fn:current-dateTime()), '[^0-9]', ''), 1, 15)
      let $contents := xdmp:zip-create( 
        <parts xmlns="xdmp:zip">{
          for $e in $entries
          return <part>{$e/*:host/xs:string(.) || '/' || $e/*:filename/xs:string(.)}</part>
        }</parts>,
        $entries ! text { xdmp:filesystem-file(./path/xs:string(.)) }
      )
      let $name := fn:string-join($timestamp, '_') || '.zip'
      let $dlUri := "/export/" || xdmp:get-current-user() || "/logs_" || $name
      let $_ := xdmp:document-insert($dlUri, $contents)
      return (
          "Export complete!",
          "",
          "Click explore and click on document: " || $dlUri || " to download.",
          "",
          "To upload locally, 'cd' to your browser 'Downloads' directory and try:",
          "",
          "  curl --digest --user admin:admin -X PUT --data-binary " || "@$(ls logs_2*.zip|tail -1) ""http://localhost:8000/v1/documents?uri=/import/" || xdmp:get-current-user() || "/dump.zip""",
          "  ^^ Consider adding above command as an alias in your shell rc file! ^^",
          "",
          "Please delete after downloading!"
      )
  
