const entryPoint = '/export/data/forests/Logs'
const hostname = '' // for a specific host use this

// IMPLEMENTATION
const host = hostname || xdmp.hostName(xdmp.host())
const rest = `${host}//${entryPoint}`.replace('//', '', 'g')
const ep = `file://${rest}`
var listing = `Listing for entrypoint [${ep}] \n---\n`
const fname = x => {
  const decorate = x.type === 'directory' ? '/' : ''
  return `${entryPoint}/${x.filename}${decorate}\n`.replace('//','/')
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

