xquery version "1.0-ml";
import module namespace admin = "http://marklogic.com/xdmp/admin"
    at "/MarkLogic/admin.xqy";

declare variable $foreign-database := 1111111111111111111; (: get the id of the foreign database from admin console on foreign cluster :)
declare variable $foreign-cluster := 2222222222222222222;  (: get the id of the foreign cluster from admin console on this cluster :)
declare variable $database-name := 'Documents';  (: get the id of the foreign cluster from admin console on this cluster :)

let $cfg := admin:get-configuration()
let $fmaster := admin:database-foreign-master($foreign-cluster, $foreign-database, fn:true())
let $cfg := admin:database-set-foreign-master( $cfg, xdmp:database($database-name), $fmaster)
return admin:save-configuration($cfg)
