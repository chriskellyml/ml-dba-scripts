const { collectionQuery, uris } = cts

let filteredUris = []
for (let uri of uris('', null, collectionQuery())) {
  const contents = fn.doc(uri).toObject() 
  if (contents.isGood) {}
    filteredUris.push(uri)
  }
}

filteredUris
