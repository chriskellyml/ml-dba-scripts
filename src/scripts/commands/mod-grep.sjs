const { invokeFunction, modulesDatabase } = xdmp

const uriList = invokeFunction(() => {
  return fn.subsequence(cts.uriMatch('*delete*'), 1, 10)
}, { database: modulesDatabase() })

uriList
