(:
 : NOTE: remove all lines starting with :DBG: before using in production
 : e.g In bash you can run something like:
 :    sed '/^ *:DBG:/d' collect.xqy
 :)
xquery version "1.0-ml";

declare option xdmp:mapping "false";

(: INPUTS :)
declare variable $start-date as xs:string? external := '2024-01-01';
declare variable $end-date as xs:string? external := '2024-12-31';

(: COMMON :)
declare variable $JOB_NAME as xs:string := 'devel';
declare variable $LIMIT as xs:string? external := '10';
declare variable $COLS_REQUIRED as xs:string? external := '/foo,/bar';

(:DBG:)(: DEVELOPMENT ONLY :)
(:DBG:)declare variable $COLS_CONSTRAINT as xs:string? external := '/baz';

declare function local:main() {
  let $customQuery := (
      cts:field-range-query("created", ">=", xs:dateTime($start-date || 'T00:00:00')),
      cts:field-range-query("created", "<=", xs:dateTime($end-date || 'T23:59:59'))
  ) 
  return local:collect($customQuery)
};

(:: P L U M B I N G ::)
declare function local:collect($customQuery) {
  (: CAST/CONVERT INPUTS :)
  let $COLS_REQUIRED := if (not(empty($COLS_REQUIRED))) then fn:tokenize($COLS_REQUIRED, ',') else ()
  (:DBG:)let $COLS_CONSTRAINT := if (not(empty($COLS_CONSTRAINT))) then fn:tokenize($COLS_CONSTRAINT, ',') else ()

  (: MAIN :)
  let $query := (
    if (count($COLS_REQUIRED) gt 0)
    then cts:or-query($COLS_REQUIRED ! cts:collection-query(.))
    else (),
    $customQuery
  )
  let $uris := cts:uris((), (), cts:and-query(($query
    (:DBG:),if (count($COLS_CONSTRAINT) gt 0)
    (:DBG:) then cts:or-query($COLS_CONSTRAINT ! cts:collection-query(.))
    (:DBG:) else ()
  )))[1 to xs:integer($LIMIT)]

  (:DBG:)(: temporarily write urls to db :)
  (:DBG:)let $_ := xdmp:invoke-function(function () {
  (:DBG:)  let $uri := '/' || $JOB_NAME || '/collected.xml'
  (:DBG:)  let $_ := xdmp:log('Storing collected uris in document [' || $uri || '')
  (:DBG:)  return xdmp:document-insert($uri, <collected><count>{count($uris)}</count><uris>{$uris ! <uri>{.}</uri>}</uris></collected>)  },
  (:DBG:)  <options xmlns="xdmp:eval"><database>{xdmp:database("Documents")}</database></options>)
  return (count($uris), $uris)
};

local:main()

(: A P P E N D I X :)
(: CORB SAMPLE PROPERTIES FILE SECTION FOR COLLECTOR :)
(:
# job.properties
# Properties file sample (copy to .properties file and fill in the values)
URIS-MODULE=/path/to/collect.xqy
URIS-MODULE.LIMIT=50
URIS-MODULE.COLS_CONSTRAINT=/baz

# example vars
URIS-MODULE.cols_required=/foo,/bar
URIS-MODULE.startDate=2024-01-01
URIS-MODULE.endDate=2024-01-10
URIS-MODULE.JOB_NAME=testing
:)
