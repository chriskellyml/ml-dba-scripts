xquery version "1.0-ml";

declare variable $LIMIT as xs:string external;
declare variable $PAGE as xs:string external;

let $limit := xs:positiveInteger($LIMIT)
let $page := xs:positiveInteger($PAGE)
let $start := (($page - 1) * $limit) + 1
let $uris := fn:subsequence(cts:uris((), ("document", "ascending")), $start, $limit)
return (fn:count($uris), $uris)
