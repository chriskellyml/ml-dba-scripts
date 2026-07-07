declareUpdate();
/*
 * Unblock rebalancing by deleting documents that trigger XDMP-REBALANCE errors.
 *
 * Scans all ErrorLog.txt files on every host for XDMP-REBALANCE messages, extracts the
 * document URI and the forest reported in the error, then deletes each matching document
 * from forests belonging to the configured database (DB_NAME).
 * 
 * CAUTION: This deletes live documents. Review the matched URIs before running outside
 * of a maintenance window.
 */
const list = {}
const LOG_PATH = '/export/data/MarkLogic/Logs';
const PATTERN = 'XDMP-REBALANCE';
const DB_NAME = 'foo-content'

function grepErrorLogs(pattern, logPath = LOG_PATH) {
  return Array.from(xdmp.hosts())
    .map(hostId => {
      const host = xdmp.hostName(hostId).toString();
      const dir = `file://${host}${logPath}`;
      return Array.from(xdmp.filesystemDirectory(dir))
        .filter(file => file.filename.endsWith('ErrorLog.txt'))
        .filter(file => file.contentLength !== 0)
        .map(file => {
          const path = file.pathname.toString();
          const logfile = file.filename.toString();
          return xdmp.filesystemFile(path)
            .toString()
            .split('\n')
            .filter(line => line.includes(pattern))
            .map(line => `${host} ${logfile} ${line}`);
        })
        .reduce((a, b) => a.concat(b), []);
    })
    .reduce((a, b) => a.concat(b), [])
    .join('\n');
}


grepErrorLogs(PATTERN).split('\n')
  .forEach(line => {
    //line.split('error: open \'').pop().split("'").shift()
    list[line.split('fn:doc("').pop().split('"').shift()] = line.split('error: open \'').pop().split("'").shift()
  })
Object.keys(list).map(uri => {
return Array.from(xdmp.forests())
  .map(f => {
    const name = xdmp.forestName(f)
    if (name.startsWith(DB_NAME)) {
      Array.from(cts.uris('', null, cts.documentQuery([uri]), 1.0, [f]))
       .forEach(x => xdmp.documentDelete(x))
    }
    return null
  })
})
    
