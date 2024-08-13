const entryPoint = '/export/data/backup' 

// IMPLEMENTATION
var listing  = ''
try {
  xdmp.filesystemDirectory(entryPoint)
    .map(x => {
      const decorate = x.type === 'directory' ? '/' : ''
      listing += `${entryPoint}/${x.filename}${decorate}\n`.replace('//','/')
      return x
    })  
} catch (e) {
  listing = `Invalid entryPoint [${entryPoint}]. Check permissions and/or form`
}


listing
