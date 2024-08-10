xquery version "1.0-ml";
(:~
 : This query should be run from the MarkLogic query console.
 : @DEFAULTS:database=Documents
 :)

declare variable $DRY_RUN := true();

declare variable $DAYS := (0,1,3);
declare variable $TYPES := ( 'ErrorLog', 'AccessLog', 'Request')[1];
declare variable $PORT_LIST := (); (: e.g. ('8010', '8000') :)
declare variable $HOST_LIST := ();
declare variable $LOG_PATH := '/var/opt/MarkLogic/Logs';

(::::   I M P L E M E N T A T I O N   ::::)
if (xdmp:database-name(xdmp:database()) ne 'Documents') then ("", "Please change to database to Documents to continue!", "") else
  let $size-data := map:entry('size', 0)
  let $entries :=
    for $days-ago in $DAYS
    let $entries := (
      for $type in $TYPES
      for $host in xdmp:hosts()
      for $entry in xdmp:filesystem-directory($LOG_PATH)//*:entry
      let $fn := $entry//*:filename/xs:string(.)
      where ends-with($fn,
        $type ||
        xs:string(if ($days-ago eq 0) then '' else ('_' || $days-ago)) ||
        '.txt')
        (: only give requested ports :)
        and (if (not(empty($PORT_LIST))) then ($PORT_LIST ! starts-with($fn, .)) else true())
        (: skip empties :)
        and $entry//*:content-length ne 0
        and $entry//*:type eq 'file'
        (: only give requested hosts :)
        and (if (not(empty($HOST_LIST))) then ($HOST_LIST = xdmp:host-name($host)) else true())
      return
        <logfile>
           <host>{xdmp:host-name($host)}</host>
           <filename>{$fn}</filename>
          <date>{
            xs:string(current-date() - xs:dayTimeDuration("P"|| xs:string($days-ago) || "D"))
           }</date>
           <path>{
             'file://'
             || xdmp:host-name($host)
             || '/' || $entry/*:pathname/xs:string(.)
           }</path>
           <size>{$entry/*:content-length/xs:integer(.)}</size>
           <modified>{fn:substring($entry/*:last-modified/xs:string(.), 1, 10)}</modified>
        </logfile>
    )
    let $_ := map:put(
      $size-data, 'size',
      fn:sum(($entries/size/xs:integer(.), map:get($size-data, 'size')))
    )
    return $entries
  return
    if ($DRY_RUN)
    then (
      "================== DRY RUN MODE =================",
      "   Please change $DRY_RUN to false to proceed    ",
      "=================================================",
      "Download " || count($entries) || " files.",
      "Total size uncompressed: " || (map:get($size-data, 'size') div 1000000) || " MB.",
      "Estimate compressed size: " || (map:get($size-data, 'size') div 20000000) || " MB.",
      $entries//*:path/xs:string(.)
    )
    else
      let $timestamp := fn:substring(fn:replace(xs:string(fn:current-dateTime()), '[^0-9]', ''), 1, 15)
      let $name := fn:string-join($timestamp, '_') || '.zip'
      let $dlUri := "/export/" || xdmp:get-current-user() || "/logs_" || $name
      let $contents := xdmp:zip-create(
        <parts xmlns="xdmp:zip">{
          for $e in $entries
          let $date-part := $e/*:date/fn:string()
          return <part>{
            $e/*:host/xs:string(.)
            || '/' || $date-part
            || '/' || $e/*:filename/xs:string(.)
          }</part>
        }</parts>,
        $entries ! text { xdmp:filesystem-file(./path/xs:string(.)) }
      )
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
