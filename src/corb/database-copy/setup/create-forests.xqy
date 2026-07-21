xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

declare variable $source := @SOURCE@;
declare variable $target := @TARGET@;

declare function local:create-forests(
  $config as element(configuration),
  $source-forest-ids as xs:unsignedLong*,
  $forest-names as xs:string*,
  $position as xs:integer
) as element(configuration)
{
  if (fn:empty($source-forest-ids)) then
    $config
  else
    let $forest-name := fn:concat($target, "-", $position)
    let $config :=
      if ($forest-name = $forest-names) then
        $config
      else
        admin:forest-create(
          $config,
          $forest-name,
          admin:forest-get-host($config, $source-forest-ids[1]),
          ()
        )
    return local:create-forests(
      $config,
      fn:subsequence($source-forest-ids, 2),
      ($forest-names, $forest-name),
      $position + 1
    )
};

let $config := admin:get-configuration()
let $source-id := admin:database-get-id($config, $source)
let $source-forest-ids := admin:database-get-attached-forests($config, $source-id)
let $forest-names :=
  for $forest-id in admin:get-forest-ids($config)
  return admin:forest-get-name($config, $forest-id)
let $config := local:create-forests(
  $config,
  $source-forest-ids,
  $forest-names,
  1
)
return admin:save-configuration($config)
