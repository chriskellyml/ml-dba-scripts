(: RECIPE FOR SPAWNING A FUNCITON MANY TIMES 
 : - The module can also be used with corb!
 :)
declare variable $DRY_RUN := fn:false();
declare variable $BATCH_SIZE := 10;
declare variable $LIMIT := 100000000;

(: IMPLEMENT!! THIS COLLECTOR SHOULD GATHER THE ITEMS TO PROCESS :)
declare function local:collect() {
  for $i in (1 to 100)
  return <item>{$i}</item>
};

(: IMPLEMENT!! THIS FUNCTION SHOULD DO THE ACTUAL WORK :)
declare function local:process(
  $startIndex as xs:integer,
  $items as item()*
) {
  let $_ :=
    for $item at $index in $items
    let $msg := 'Processing item #' || xs:string($startIndex + $index - 1)
    return xdmp:log($msg)
  return 'Processed ' || fn:count($items) || ' items'
};

(:        P L U M B I N G        :)
(: You do not typically want to change the following code :)
declare function local:distribute-tasks()
{
  let $workToDo := local:collect()
  return 
    if ($DRY_RUN)
    then (
      "!!! DRY RUN -- Set $DRY_RUN TO false() to proceed !!!",
      fn:count($workToDo) || " items ready to process in batches of " || $BATCH_SIZE,
      "Showing first 5 items:",
      $workToDo[1 to 5]
    )
    else
      let $num := fn:count($workToDo)
      let $total := fn:ceiling($num div $BATCH_SIZE)
      return
        for $i in (0 to $total)
        let $start := ($i*$BATCH_SIZE + 1)
        let $next := $workToDo[$start to  $i*$BATCH_SIZE + $BATCH_SIZE]
        return (
          try {
            xdmp:spawn-function(function() {
              local:process($start, $next)
            }, <options xmlns="xdmp:eval">
              <result>true</result>
            </options>)
          } catch ($e) {
            xdmp:log($e)
          },
          'Batch ' || $start || ' spawned'
        )
};

local:distribute-tasks()

