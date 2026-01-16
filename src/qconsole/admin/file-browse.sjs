/*
 * FILE-BROWSE.SJS - MarkLogic File System Browser
 * 
 * PURPOSE: Browse and list files/directories on MarkLogic server filesystem
 * 
 * USAGE INSTRUCTIONS:
 * 1. Run this query in MarkLogic Query Console
 * 2. Set database to "Documents" (required)
 * 3. Configure the entryPoint variable to browse specific directories
 * 4. Optionally set hostname to browse a specific host (leave empty for current host)
 * 
 * CONFIGURATION VARIABLES:
 * - entryPoint: Path to browse (default: '/export/data/forests/Logs')
 * - hostname: Specific host to browse (empty = current host)
 * 
 * OUTPUT: Returns formatted directory listing with file types and paths
 * 
 * EXAMPLES:
 * - Browse logs: entryPoint = '/var/opt/MarkLogic/Logs'
 * - Browse data: entryPoint = '/var/opt/MarkLogic/Data'
 * - Browse specific host: hostname = 'ml-node-01'
 */

const entryPoint = '/export/data/forests/Logs'
const hostname = '' // for a specific host use this

// IMPLEMENTATION
const host = hostname || xdmp.hostName(xdmp.host())
const rest = `${host}//${entryPoint}`.replace('//', '', 'g')
const ep = `file://${rest}`
var listing = `Listing for entrypoint [${ep}] \n---\n`
const fname = x => {
  const decorate = x.type === 'directory' ? '/' : ''
  // props: filename|pathname|type|contentLength|lastModified
  return `${(x.contentLength + '           ').substr(0, 8)} ${entryPoint}/${x.filename}${decorate}\n`.replace('//','/')
}
try {
  xdmp.filesystemDirectory(ep)
    .sort((a, b) => {
      const af = fname(a)
      const bf = fname(b)
      return af > bf ? 1 : af < bf ? -1 : 0
    })
    .map(x => {
      listing += fname(x)
      return x
    })
} catch (e) {
  listing = `Invalid entryPoint [${ep}]. Check permissions and/or form`
}

listing
