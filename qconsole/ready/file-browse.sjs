const entryPoint = '/export/data' 
const hostname = '' # for a specific host use this

// IMPLEMENTATION
const host = hostname || xdmp.hostName(xdmp.host())
const rest = `${host}//${entryPoint}`.replace('//', '', 'g')
const ep = `file://${rest}`
var listing = `Listing for entrypoint [${ep}] \n---\n`
try {
  xdmp.filesystemDirectory(ep)
    .map(x => {
      const decorate = x.type === 'directory' ? '/' : ''
      listing += `${entryPoint}/${x.filename}${decorate}\n`.replace('//','/')
      return x
    })  
} catch (e) {
  listing = `Invalid entryPoint [${ep}]. Check permissions and/or form`
}

listing
