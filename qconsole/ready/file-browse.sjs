const entryPoint = '/' 

// IMPLEMENTATION
var listing  = ''
xdmp.filesystemDirectory(entryPoint)
  .map(x => {
    const decorate = x.type === 'directory' ? '/' : ''
    listing += `${entryPoint}/${x.filename}${decorate}\n`.replace('//','/')
    return x
  })

listing
