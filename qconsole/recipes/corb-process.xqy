(:
 : NOTE: remove all lines starting with :DBG: before using in production
 : e.g In bash you can run something like:
 :    sed '/^ *:DBG:/d' collect.xqy
 :)
xquery version "1.0-ml";

declare variable $URI as xs:string? external := ();

(: COMMON :)
declare variable $JOB_NAME as xs:string external := 'devel';

declare function local:process()
{
    for $uri in local:get-uris()
    let $doc := doc($uri)
    let $created := $doc//@created
    return $created || ' ' || $uri
};

(:: P L U M B I N G ::)
declare function local:get-uris() {
  (:DBG:)(: temporary list of uris for developement and testing :)
  (:DBG:)if (empty($URI))
  (:DBG:)then xdmp:invoke-function(function () {
  (:DBG:)  let $uri := '/' || $JOB_NAME || '/collected.xml'
  (:DBG:)  let $_ := xdmp:log('DBG: collecting uris from stored document [' || $uri || ']')
  (:DBG:)  return doc($uri)//uri/xs:string(.) },
  (:DBG:)  <options xmlns="xdmp:eval"><database>{xdmp:database("Documents")}</database></options>)
  (:DBG:)else
  fn:tokenize($URI, ';')
};

local:process()

(: A P P E N D I X :)
(: CORB SAMPLE PROPERTIES FILE SECTION FOR PROCESSOR :)
(:
# job.properties
# Properties file sample (copy to .properties file and fill in the values)
PROCESS-MODULE=/path/to/process.xqy

# example vars
URIS-MODULE.JOB_NAME=testing
:)
