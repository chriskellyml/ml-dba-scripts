const entryPoint = '/export/data/MarkLogic/Forests/lvbb-content-1/Large'
const hostname = '' // for a specific host use this

// IMPLEMENTATION
const host = hostname || xdmp.hostName(xdmp.host())

// normalize "host/path" and also "file://host/path"
const normPath = s => String(s).replace(/\/{2,}/g, '/')
const asFileUri = p => `file://${normPath(p)}`

const basePath = normPath(`${host}/${entryPoint}`)
const baseUri = asFileUri(basePath)

let listing = `Listing for entrypoint [${baseUri}] \n---\n`

const pad8 = n => String(n == null ? 0 : n).padEnd(8, ' ').slice(0, 8)
const fileLine = (fullPath, info) =>
  `${pad8(info.contentLength)} ${normPath(`${fullPath}/${info.filename}`)}\n`
const formatBytes = n =>
  n >= 1024 ** 3 ? `${(n / 1024 ** 3).toFixed(2)} GB` :
  n >= 1024 ** 2 ? `${(n / 1024 ** 2).toFixed(2)} MB` :
  n >= 1024 ? `${(n / 1024).toFixed(2)} KB` :
  `${n} bytes`
// CHANGE this helper (replace the old listAllFiles + any .toArray usage)
function listAllFiles(dirPath) {
  const dirUri = asFileUri(dirPath)
  const entries = xdmp.filesystemDirectory(dirUri) // sequence

  const out = []
  for (const ent of entries) { // Server-side JS can iterate sequences
    const nextPath = normPath(`${dirPath}/${ent.filename}`)
    if (ent.type === 'directory') {
      out.push(...listAllFiles(nextPath))
    } else {
      out.push({ path: nextPath, size: ent.contentLength || 0 })
    }
  }
  return out
}
let totalSize = 0
try {
  const files = listAllFiles(basePath)

  files
    .sort((a, b) => b.size - a.size || (a.path > b.path ? 1 : a.path < b.path ? -1 : 0))
    .forEach(f => {
      // Print as: "<size> <full path>"
      totalSize += f.size
      listing += `${pad8(f.size)} ${f.path}\n`
    })
} catch (e) {
  listing =
    `TOTAL ${totalSize} bytes\n` +
    `Invalid entryPoint [${baseUri}]. Check permissions and/or form.\n` +
    `Error: ${e}`
}

listing = 
   `TOTAL ${formatBytes(totalSize)} bytes\n` +
   listing

listing
