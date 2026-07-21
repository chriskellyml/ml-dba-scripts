xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

declare variable $source := @SOURCE@;
declare variable $target := @TARGET@;

declare function local:attach-forests(
  $config as element(configuration),
  $database-id as xs:unsignedLong,
  $forest-ids as xs:unsignedLong*
) as element(configuration)
{
  if (fn:empty($forest-ids)) then
    $config
  else
    local:attach-forests(
      admin:database-attach-forest($config, $database-id, $forest-ids[1]),
      $database-id,
      fn:subsequence($forest-ids, 2)
    )
};

let $config := admin:get-configuration()
let $source-id := admin:database-get-id($config, $source)
let $target-id := admin:database-get-id($config, $target)
let $source-forest-ids := admin:database-get-attached-forests($config, $source-id)
let $forest-ids :=
  for $position in 1 to fn:count($source-forest-ids)
  return admin:forest-get-id($config, fn:concat($target, "-", $position))
let $config := local:attach-forests($config, $target-id, $forest-ids)
return admin:save-configuration($config)
