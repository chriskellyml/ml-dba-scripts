xquery version "1.0-ml";
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare variable $MODE := ("get", "set")[1];
declare variable $DBNAME := "my-content";

let $config := admin:get-configuration()
let $dbid := admin:database-get-id($config, $DBNAME)
return 
  if ($MODE = "set") 
  then admin:database-get-attached-forests($config,$dbid) ! xdmp:forest-name(.)
  else
    let $forest-names-in-order := (
      "content-1-m",
      "content-2-m",
      "content-3-m"
    )
    let $forest-ids := $forest-names-in-order ! xdmp:forest (.)
    let $config := admin:database-reorder-forests($config, $dbid, $forest-ids)
    return (
      'reordering to: ' || fn:string-join ($forest-names-in-order, ', '),
      admin:save-configuration($config)
    )
