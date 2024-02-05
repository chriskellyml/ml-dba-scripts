xquery version "1.0-ml";

(: DUMP can be specified as:
 :  - a string -> i.e. the contents of a zip dump
 :  - a binary document -> i.e. a zip dump
 :)
declare variable $DUMP:= "/import/dump.zip";
declare variable $TEMPORAL_COL := '/framework/temporal/system';
declare variable $DEST_DB := 'cup-content';
declare variable $TEMP_DB := 'Documents';
declare variable $LIMIT := 10;

(:::: I M P L E M E N T A T I O N ::::)
(:~
 : 1 Override the temporal collection options to allow for admin operations
 : 2 Extract the data from the dump and insert into the destination database
 : 3 Reset the temporal collection options to safe
 :)
if (xdmp:database-name(xdmp:database()) ne $TEMP_DB) then ("", "Please change to database to " || $TEMP_DB || " to continue!", "") else
  let $OPTS := function($db) {
    <options xmlns="xdmp:eval">
      <transaction-mode>update-auto-commit</transaction-mode>
      <isolation>different-transaction</isolation>
      <database>{xdmp:database($db)}</database>
    </options>
  }
  let $overrideTemporal := function ($opt) {
    let $q := 'xquery version "1.0-ml";
      import module namespace temporal = "http://marklogic.com/xdmp/temporal" at "/MarkLogic/temporal.xqy";
      temporal:collection-set-options("' || $TEMPORAL_COL || '", "updates-' || $opt || '")'
    return xdmp:invoke-function(function() {
      xdmp:eval($q, (), $OPTS($DEST_DB))
    })
  }
  (: execute steps in a multi-transactional statement to give more control over the environment :)
  return (
    $overrideTemporal('admin-override')
    ,
    xdmp:invoke-function(function () {
      let $data := 
        if (ends-with($DUMP, 'zip'))
        then xdmp:zip-get(doc($DUMP), 'export_dump.csv')
        else $DUMP
      (:~
       : parse rows and import 
       :)
      let $documentRows := (
        for $r in tokenize($data, '\n')[1 to $LIMIT]
        where not(starts-with($r, '#')) (: remove comments :)
        return $r
      )[2 to last()] (: as well as comments, skip header row :)
      (:~
       : extract all encoded data and insert into the destination database
       :)
      return (
        for $row in $documentRows[1 to $LIMIT]
        let $fields := tokenize($row, ',')
        let $uri := $fields[1]
        let $permissions := xdmp:unquote('<perms>' || xdmp:base64-decode($fields[3] ) || '</perms>')//*:permission
        let $contents := xdmp:unquote(xdmp:base64-decode($fields[4]))
        return xdmp:invoke-function(function () {
          xdmp:document-insert($uri, $contents, <options xmlns="xdmp:document-insert">
            <permissions>{$permissions}</permissions>
            <collections>{('/imported/data-dump', tokenize($fields[2], '\|')) ! <collection>{.}</collection>}</collections>
          </options>)
        }, $OPTS($DEST_DB))
      )  
    }, $OPTS('Documents'))
    ,
    $overrideTemporal('safe')
  )
  