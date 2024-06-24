xquery version "1.0-ml";
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
declare variable $foreign-database := 33333333333333333333;
declare variable $foreign-cluster := 44444444444444444444;  (: get the id of the foreign cluster from admin console on this cluster :)
declare variable $database-name := 'Documents';  (: get the id of the foreign cluster from admin console on this cluster :)

let $cfg := admin:get-configuration()
let $freplica := admin:database-foreign-replica($fcl, $fdb, fn:true(), 300)
let $cfg := admin:database-add-foreign-replicas($cfg, xdmp:database($database-name), $freplica)
return admin:save-configuration($cfg)
