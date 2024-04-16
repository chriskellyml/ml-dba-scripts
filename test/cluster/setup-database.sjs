javascript=
const DATA = {
  database: 'testdb',
  forests: ['f1', 'f2']
}

const { database, forest, hosts, documentInsert } = xdmp
const {
  getConfiguration,
  saveConfiguration,
  forestCreate,
  databaseAttachForest,
  databaseExists,
  forestExists,
  forestRename,
  forestDelete,
  databaseDelete,
  databaseCreate
} = require("/MarkLogic/admin.xqy")

let C = getConfiguration()
let newConf

if (!databaseExists(C, DATA.database)) {
  newConf = databaseCreate(C, DATA.database, database('Security'), database('Schemas'))
  saveConfiguration(newConf)  
}

const hlist = Array.from(hosts())
DATA.forests.forEach((f, i) => {
  const h = hlist[i % hlist.length]
  const fName = DATA.forests[i]
  if (!forestExists(C, fName)) {
    saveConfiguration(forestCreate(C, fName, h, null, null, null))  
  }
})

DATA.forests.forEach((f, i) => {
  const fName = DATA.forests[i]
  if (forestExists(C, fName)) {
    saveConfiguration(databaseAttachForest(C, database(DATA.database), forest(fName)))  
  }
})

"Database setup complete"


