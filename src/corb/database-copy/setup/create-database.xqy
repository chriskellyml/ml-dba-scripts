xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

declare variable $source := @SOURCE@;
declare variable $target := @TARGET@;

let $config := admin:get-configuration()
let $database-names :=
  for $database-id in admin:get-database-ids($config)
  return admin:database-get-name($config, $database-id)
return
  if ($target = $database-names) then
    if (fn:empty(admin:database-get-attached-forests(
      $config,
      admin:database-get-id($config, $target)
    ))) then "NEEDS_FORESTS" else "EXISTS"
  else
    let $source-id := admin:database-get-id($config, $source)
    let $config := admin:database-copy($config, $source-id, $target)
    let $_ := admin:save-configuration($config)
    return "NEEDS_FORESTS"
