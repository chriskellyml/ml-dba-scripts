/* This script will check your cluster and build a html table visualizing the
 * current topology. Be sure to switch to html view below to see the output as
 * intented */

/**
 * ---------------------------------------------------------------------------- 
 * TEMPLATE FOR TOPOLOGY BUILDER SCRIPT
 * COPY THIS TO A NEW SCRIPT AND ADAPT TO YOUR NEEDS
 * DELETE THIS COMMENT BLOCK
 * ----------------------------------------------------------------------------
**/

/**
 * 
 * Configure ENV in server variable DATA_SCRIPT_CONFIG
 * e.g.
 * ENV = {
 *  loc: {
 *   hosts: ['localhost'],
 *   database: 'content-db',
 *     forests: {
 *       state1: [
 *         ['content-db-1-0', null, 0, 1],
 *         ['content-db-2-0', null, 0, 2],
 *         ['content-db-3-0', null, 1, 2],
 *         ['content-db-4-0', null, 1, 0],
 *         ['content-db-5-0', null, 2, 0],
 *         ['content-db-6-0', null, 2, 1],
 *       ]
 *     }
 *   }
 * }
 * 
 */

var STEP, CUR_ENV

// Initialize external variables if not provided by invoker
STEP = STEP || 1
CUR_ENV = CUR_ENV || 'loc'

const { ENV, defined, message } = JSON.parse(xdmp.getServerField('DATA_SCRIPT_CONFIG'))

const DRY_RUN = 0, GEN_STATE = 1,
  CLEANUP = 2, BUILD_MAP = 4,
  EXTRACT_TOPO = 5, DUMP_CONFIG = 6
const EXTRACT_DB = 'content-d'
const CUR_STATE = 'state1'
/*******************************************/

if (!defined) message
else {
  console.log('Creating databases')
  const PREFIX = ''

  const makeCfg = (env, state) => ({
    hosts: ENV[env].hosts,
    database: PREFIX + ENV[env].database,
    securityDatabase: 'Security',
    schemasDatabase: 'Schemas',
    rebalance: !!(ENV[env].rebalance && ENV[env].rebalance[state]),
    disableReplication: !!(ENV[env].disableReplication && ENV[env].disableReplication[state]),
    forests: ENV[env].forests[state].reduce((p, n) => {
      p.push({
        name: PREFIX + n[0],
        oldName: n[1] ? `${PREFIX}${n[1]}` : null,
        host: n[2],
        replicaHost: n[3]
      })
      return p
    }, []),
    // methods
    replicaName: x => x.substring(0, x.length - 2) + '-1',
  })

  /* ---------------------------------------------------------------------------- */
  /* ----- [Wed Dec 21 17:06:01 CET 2022] - GENERATED SCRIPT - DO NOT MODIFY ---- */
  const admin = require("/MarkLogic/admin.xqy")
  let config = admin.getConfiguration()

  const buildMap = (database) => {
    const forests = Array.from(admin.getForestIds(config))
    const dbId = xdmp.database(database)
    const hosts = Array.from(xdmp.hosts()).map(h => xdmp.hostName(h)).sort()
    const topology = {
      hosts,
      database: dbId,
      forests: []
    }
    const colors = ['#FF6347', '#3CB371', '#BA55D3', '#FFE4C4', '#D2691E', '#00BFFF', '#4682B4', '#FFA07A', '#FFDEAD', '#B0C4DE']
    forests
      .filter(x => `${admin.forestGetDatabase(config, x)}` === `${xs.string(dbId)}`)
      .forEach(x => {
        const rps = Array.from(admin.forestGetReplicas(config, x)).map(x => admin.forestGetName(config, x))
        const name = admin.forestGetName(config, x)
        const host = hosts.indexOf(xdmp.hostName(admin.forestGetHost(config, x)))
        topology.forests.push({
          name,
          host,
          replicas: rps.join(';'),
          replicaHost: rps.map(r => {
            const id = admin.forestGetHost(config, admin.forestGetId(config, r))
            return hosts.indexOf(xdmp.hostName(id))
          }).join(';'),
        })
      })

    // topology as html
    const asHtml = topology => {
      const active = topology.forests.map(x => [x.name, x.host, x.host])
      const replicas = topology.forests.map(x => [x.replicas, x.replicaHost, x.host])
      const rows = list => topology.hosts.map((h, i) => `
      <td>${list.filter(x => +x[1] === i).map(x => {
        const c = colors[x[2]]
        return `<div style="color:${c}">${x[0]}</div>`
      }).join('')}</td>`).join('')
      return `<table border="1">
        <thead>
          <tr><th>Info</th>${topology.hosts.map(h => `<th>${h}</th>`).join('')}</tr>
        </thead>
        <tbody>
          <tr><td>Active</td>${rows(active)}</tr>
          <tr><td>Replicas</td>${rows(replicas)}</tr>
        </tbody>
      </table>`
    }

    return {
      html: asHtml(topology),
      topology
    }
  }

  /* ---------------------------------------------------------------------------- */
  /* ----- [Wed Dec 21 17:06:01 CET 2022] - GENERATED SCRIPT - DO NOT MODIFY ---- */
  class DbCleaner {
    constructor(database, prefix) {
      console.log('-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~')
      console.log('Constructing DbCleaner')
      this.ready = true
      if (!admin.databaseExists(config, database)) {
        console.log(`DbCleanern not running. No database [${database}] found.`)
        this.ready = false
        return
      }
      this.prefix = prefix
      this.dbId = xs.unsignedLong(xdmp.database(database))
      const xx = admin.databaseGetAttachedForests(config, this.dbId)
      this.forests = Array.from(xx).reduce((p, n) => {
        p[n] = {}
        return p
      }, {})
    }
    execute() {
      const { invokeFunction } = xdmp
      if (this.ready) {
        invokeFunction(() => { this.detachReplicas() }, { isolation: 'different-transaction' })
        invokeFunction(() => { this.detachForests() }, { isolation: 'different-transaction' })
        invokeFunction(() => { this.removeForests() }, { isolation: 'different-transaction' })
        invokeFunction(() => { this.deleteDanglingForests() }, { isolation: 'different-transaction' })
        invokeFunction(() => { this.deleteDatabase() }, { isolation: 'different-transaction' })
        return this.preview()
      } else {
        return 'No db. Not ready!'
      }
    }
    detachReplicas() {
      Object.keys(this.forests).forEach(f => {
        const reps = Array.from(admin.forestGetReplicas(config, f))
        console.log('Found replicas:', reps)
        this.forests[f] = reps
        if (reps.length) {
          // 7535600512114472960
          reps.forEach(r => {
            console.log(`Removing replica [${r}] from forest [${f}]`)
            config = admin.forestRemoveReplica(config, xs.unsignedLong(f), xs.unsignedLong(r))
          })
          console.log('Saving config ...')
          admin.saveConfiguration(config)
        }
      })
    }
    detachForests() {
      const ids = Object.keys(this.forests)
      ids.forEach(forestId => {
        config = admin.databaseDetachForest(config, this.dbId, xs.unsignedLong(forestId))
      })
      admin.saveConfiguration(config)
    }
    removeForests() {
      const ids = Object.keys(this.forests)
      config = admin.forestDelete(config, ids, true)
      admin.saveConfiguration(config)
    }
    deleteDanglingForests() {
      Array.from(admin.getForestIds(config))
        .map(id => {
          return {
            id,
            name: admin.forestGetName(config, id),
          }
        })
        .filter(x => `${x.name}`.startsWith(this.prefix))
        .forEach(x => {
          if (admin.forestExists(config, x.name)) {
            config = admin.forestDelete(config, xs.unsignedLong(x.id), true)
          }
        })
      admin.saveConfiguration(config)
    }
    deleteDatabase() {
      config = admin.databaseDelete(config, this.dbId)
      admin.saveConfiguration(config)
    }
    preview() {
      return {
        forests: this.forests
      }
    }
  }

  /* ---------------------------------------------------------------------------- */
  /* ----- [Wed Dec 21 17:06:01 CET 2022] - GENERATED SCRIPT - DO NOT MODIFY ---- */
  /**
   * Static methods for running admin steps
   */
  class TopoRunner {
    constructor() { }

    static attachForest(c, data) {
      const { forest, database } = data
      c = admin.databaseAttachForest(c, xdmp.database(database), admin.forestGetId(c, forest))
      admin.saveConfiguration(c)
    }

    static createForest(c, data) {
      const { forest, hosts, host } = data
      const hostName = hosts[host]
      const fExists = admin.forestExists(c, forest)
      console.log(`    -> Forest [${forest}] ${fExists ? 'exists.' : ' does not exist.'}`)
      if (!fExists) {
        console.log(`    -> Creating forest [${forest}] on host [${hostName}]`)
        c = admin.forestCreate(c, forest, xdmp.host(hostName), null)
        admin.saveConfiguration(c)
      } else {
        console.log(`    -> WARNING: Forest [${forest}] already exists. Not re-creating!`)
      }
    }

    static detachAndDeleteReplicas(c, data) {
      const { forest, forestId, replicaIds } = data
      replicaIds.map(id => {
        c = admin.forestRemoveReplica(c, xs.unsignedLong(forestId), xs.unsignedLong(id))
      })
      admin.saveConfiguration(c)

      replicaIds.forEach(r => {
        if (admin.forestExists(c, forest)) {
          console.log(`    -> Forest [${r}] exists. Attempting to delete`)
          try {
            c = admin.forestDelete(c, xs.unsignedLong(r), true)
          } catch (e) {
            console.log(`    -> ERROR: Could not delete forest [${r}]`)
            console.log(e)
          }
        } else {
          console.log(`    -> WARNING: Forest replica [${r}] does not exist. Nothing to delete!`)
        }
      })
      admin.saveConfiguration(c)
    }

    static linkReplica(c, data) {
      const { forest, replica } = data
      if (!admin.forestExists(c, forest)) {
        console.log(`WARNING: failed to assign replica [${replica}] to forest [${forest}] because forest does not exist!`)
        return
      }
      console.log(`    -> Adding the replica [${replica}] to forest [${forest}]`)
      c = admin.forestAddReplica(
        c,
        xdmp.forest(forest),
        xdmp.forest(replica)
      )
      admin.saveConfiguration(c)
    }

    static renameForest(c, data) {
      const { fromId, toName } = data
      if (admin.forestExists(c, toName)) {
        console.log(`    -> WARNING: Attempted to rename forest [${admin.forestGetName(c, fromId)}] to existing forest [${toName}]`)
      } else {
        console.log(`    -> Renaming forest [${admin.forestGetName(c, fromId)}] to [${toName}]`)
        try {
          c = admin.forestRename(c, xs.unsignedLong(fromId), toName)
          admin.saveConfiguration(c)
        } catch (e) {
          console.log('ERROR while renaming fromId [${fromId}] to [${toName}]')
          console.log(e.code)
          console.log(e.stack)
          console.log(`S: ${e.stack}`)
          console.log(e)
        }
      }
    }
    static insertDocuments(c, data) {
      const { amount, database } = data
      [new Array(amount)].forEach((_, i) => {
        xdmp.invokeFunction(() => {
          xdmp.documentInsert(`/tmp/uri-${i}.xml`, { record: i }, {
            collections: ['/test/topo-maker']
          })
        }, { database: xdmp.database(database) })
      })
      /*
      return [
        TopoMaker.topmatter(description),
        'let $_ := ',
        `  for $i in (1 to ${amount})`,
        `  let $uri := "/tmp/uri-" || xs:string($i) || ".xml"  `,
        `  return xdmp:invoke-function(function () {
              xdmp:document-insert($uri, <test-data>{$i}</test-data>, <options xmlns="xdmp:document-insert">  
                  <collections>
                    <collection>/test/topo-maker</collection>
                  </collections>
                </options>)
            }, <options xmlns="xdmp:eval"><database>{xdmp:database("${database}")}</database></options>)
  
        `,
        `return "DONE: Data insertion for [${amount}] documents complete."`
      ]
      */
    }

    static summarizeDocumentsByForest(c, data) {
      const { forests, database } = data
      /*
      return [
        `import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";`,
        TopoMaker.topmatter(description),
        `return xdmp:invoke-function(function () {`,
        `  map:new(`,
        `    for $name in (${forests.map(name => `"${name}"`)})`,
        `    let $uris := cts:uris((), (), cts:collection-query('/test/topo-maker'), (), functx:value-intersect(admin:forest-get-id($config, $name), xdmp:database-forests(xdmp:database())))`,
        `    return map:entry($name, fn:count($uris))`,
        `  ) ! xdmp:to-json(.)` ,
        `}, <options xmlns="xdmp:eval"><database>{xdmp:database("${database}")}</database></options>)`
      ]
      */
    }

    static createDatabase(c, { database, security = 'Security', schemas = 'Schemas' }) {
      c = admin.databaseCreate(c, database, xdmp.database(security), xdmp.database(schemas))
      admin.saveConfiguration(c)
    }
    static disableRebalancing(c, data) {
      TopoRunner.toggleRebalancing(c, data.database, false)
    }
    static enableRebalancing(c, data) {
      TopoRunner.toggleRebalancing(c, data.database, false)
    }
    static toggleRebalancing(c, database, on = true) {
      const id = xdmp.database(database)
      c = admin.databaseSetRebalancerEnable(c, id, on)
      admin.saveConfiguration(c)
    }
  }

  /**
   * Migrate to new topology based on existing topology
   */
  class TopoMaker {
    constructor(plan) {
      console.log('-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~')
      console.log('           Constructing TopoMaker')
      this.plan = plan
      this.warnings = []
      this.script = [
        `(::::::::::::::::::::::::::::::::::::::::::
 : GENERATED SCRIPT @ ${fn.currentDateTime()}
 :
 :)`,
      ]
      if (this.execute()) {
        console.log('Execution complete.')
      } else {
        this.script = ['Not every step has a function defined!', ...this.warnings]
      }
    }

    run() {
      console.log(`Planned steps:`)
      this.plan.forEach((task, i) => {
        console.log(`  ${i} [${task.step}]: ${task.description}`)
      })
      console.log('--')
      this.plan.forEach((task, i) => {
        const { step, data, description } = task
        if (!TopoRunner[step]) {
          console.log(`Missing method [${step}]!`)
        } else {
          console.log(`${('    ' + i).substr(-3)} Executing [${step}]: ${description}`)
          xdmp.invokeFunction(() => {
            let c = admin.getConfiguration()
            TopoRunner[step](c, data)
          }, {
            isolation: 'different-transaction',
            transactionMode: 'update-auto-commit'
          })
          console.log(`    Finsihed [${step}]: ${description}`)
          xdmp.sleep(1000)
        }
      })
    }
    execute() {
      if (!this.plan.every(({ step }) => {
        if (!this[step]) {
          this.warnings.push(`Missing method for step[${step}]`)
        }
        return this[step]
      })) {
        return false
      } else {
        this.plan.forEach(({ step, data, description }) => {
          this.wrap(this[step](data, description), step)
        })
        return true
      }
    }

    static toggleRebalancing(database, on = true) {
      return [
        `let $db-id := xdmp:database('${database}')`,
        `let $config := admin:database-set-rebalancer-enable(
        $config,
        $db-id,
        ${on ? 'fn:true()' : 'fn:false()'}
      )`,
        TopoMaker.saveConfig()
      ]
    }

    wrap(lines, step) {
      this.script = [
        ...this.script,
        `(:::)`,
        `(:::)`,
        `(:::: NEXT STEP [${step}] ::::)`,
        'xquery version "1.0-ml";',
        ...lines,
        ';',
        '',
        '',
      ]
    }

    //------ STATIC METHODS -------
    static saveConfig() {
      return `let $_ := admin:save-configuration($config)`
    }
    static topmatter(d) {
      return `import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
let $_ := xdmp:log("RUNNING STEP: ${d}")
let $config := admin:get-configuration()
`
    }

  }
  /* ---------------------------------------------------------------------------- */
  /* ----- [Wed Dec 21 17:06:01 CET 2022] - GENERATED SCRIPT - DO NOT MODIFY ---- */
  class WorkListBuilder {
    constructor(c = {}) {
      this.CONFIG = c
      this.database = c.database
      this.hosts = c.hosts
      this.rebalance = c.rebalance
      this.enableReplication = c.enableReplication
      this.forests = c.forests
      this.workList = []
    }

    // Generate plan of work to do
    plan() {
      this.initialize()
      this.checkIfDatabaseNeeded()
      this.detachAndDeleteExistingReplicas()
      this.checkIfForestsExist()
      this.createAndAttachReplicas()
      if (this.disableReplication) {
        // this.disableReplicaForests()
      }
      // this.insertSomeData()
      this.finalize()
    }
    // Get the state of the database
    initialize() {

    }
    finalize() {
      const { database } = this
      //this.assign(' Rebalancing', { database },  `Re-enable rebalancing in database [${database}]` )
    }
    checkIfDatabaseNeeded() {
      const { database } = this
      const exists = admin.databaseExists(config, database)
      console.log(`DD: Checking if db exists [${database}] -> [${exists}]`)
      if (!exists) {
        this.assign(
          'createDatabase', { database },
          `Create a database [${database}]`
        )
      }
      if (!this.rebalance) {
        this.assign('disableRebalancing', { database }, `Disable rebalancing in database [${database}]`)
      }
    }

    checkIfForestsExist() {
      this.forests.forEach(f => {
        const { oldName, name, host } = f
        if (oldName) {
          // FIXME: does not take into consideration if forest destination host has been changed.
          if (admin.forestExists(config, oldName)) {
            // TODO: Check what host the forest is on
            this.assign(
              'renameForest',
              {
                fromId: admin.forestGetId(config, oldName),
                toName: name
              },
              `Rename forest [${oldName}] to [${name}] on host [${host}]`
            )
          }
        } else {
          if (!admin.forestExists(config, name)) {
            this.assign(
              'createForest', {
              forest: f.name,
              hosts: this.hosts,
              host: f.host
            },
              `Create a primary forest [${f.name}] on host [${this.hosts[f.host]}]`
            )
            this.assign(
              'attachForest', { forest: f.name, database: this.database },
              `Attach forest [${f.name}] to database [${this.database}]`
            )
          }
        }
      })
    }

    detachAndDeleteExistingReplicas() {
      if (!admin.databaseExists(config, this.database)) return
      const forests = [
        ...this.forests.map(f => f.name),
        ...Array.from(admin.databaseGetAttachedForests(config, xdmp.database(this.database)))
          .map(x => xdmp.forestName(x)),
      ]
      console.log(`Found forests [${forests.join(',')}]. Checking for replicas.`)
      forests.forEach(name => {
        if (admin.forestExists(config, name)) {
          console.log(`Preparing [detachAndDeleteExistingRepicas]. Checking forest [${name}] for existing replicas for removal.`)
          const forestId = admin.forestGetId(config, name)
          const replicaIds = Array.from(admin.forestGetReplicas(config, forestId))
          if (replicaIds.length) {
            this.assign(
              'detachAndDeleteReplicas',
              {
                forest: name,
                forestId,
                replicaIds
              },
              `Remove and delete replicas [${replicaIds.map(x => admin.forestGetName(config, x) + '/' + x).join(',')}] from forest [${name}]`
            )
          }
        }
      })
    }

    createAndAttachReplicas() {
      // All previous replicas have been removed ...
      this.forests.forEach(f => {
        const { name, replicaHost } = f
        const { replicaName } = this.CONFIG
        const rname = replicaName(name)
        if (!admin.forestExists(config, rname)) {
          this.assign(
            'createForest', {
            forest: rname,
            hosts: this.hosts,
            host: replicaHost
          },
            `Create a replica forest [${rname}] on host [${this.hosts[replicaHost]}]`
          )
        }
        this.assign(
          'linkReplica',
          {
            forest: name,
            replica: rname
          },
          `Adding a new replica [${rname}] to forest [${name}]`
        )
      })
    }

    disableReplicaForests() {
      if (!admin.databaseExists(config, this.database)) return
      const forests = [
        ...this.forests.map(f => f.name),
        ...Array.from(admin.databaseGetAttachedForests(config, xdmp.database(this.database)))
          .map(x => xdmp.forestName(x)),
      ]
      console.log(`Found forests [${forests.join(',')}]. Checking for replicas.`)
      forests.forEach(name => {
        if (admin.forestExists(config, name)) {

          const forestId = admin.forestGetId(config, name)
          const replicaIds = Array.from(admin.forestGetReplicas(config, forestId))
          if (replicaIds.length) {
            this.assign(
              'disableForest',
              {
                forest: name,
                forestId,
              },
              `Disabing replica forest [${forest}] from forest [${name}]`
            )
          }
        }
      })
    }

    // Insert a few hundred records so we can analyse where they go
    // and how they are rebalanced later
    insertSomeData() {
      const amount = 50
      this.assign(
        'insertDocuments', {
        amount: 50,
        database: this.database
      },
        `Inserting [${amount}] records in database`
      )
      this.assign(
        'summarizeDocumentsByForest', {
        forests: this.forestNames,
        database: this.database,
        amount,
      },
        `Check which uris are in each forest of [${this.forestNames.join(',')}]`
      )
    }
    preview() {
      return this.workList.map((x, i) => `${i}: ${x.description}`).join('\n')
    }
    assign(step, data, description) {
      this.workList.push({ step, data, description })
    }
    get forestNames() { return this.forests.map(f => f.name) }
  }

  /* ---------------------------------------------------------------------------- */
  /* ----- [Wed Dec 21 17:06:01 CET 2022] - GENERATED SCRIPT - DO NOT MODIFY ---- */
  const run = (step, state, env, extdb) => {
    console.log(`%`)
    console.log(`%`)
    const CONFIG = makeCfg(env, state)
    if (!CONFIG) CONFIG = { database: '', }

    let beforeMap = ''
    if (admin.databaseExists(config, CONFIG.database)) {
      beforeMap = buildMap(CONFIG.database)
    }
    const WLB = new WorkListBuilder(CONFIG)
    WLB.plan()

    switch (step) {
      case GEN_STATE:
        const TM = new TopoMaker(WLB.workList)
        TM.run()
        return fn.head(xdmp.invokeFunction(() => {
          return buildMap(CONFIG.database).html
        }, { isolation: 'different-transaction' }))
        break

      case CLEANUP:
        const DC = new DbCleaner(CONFIG.database, PREFIX)
        return DC.execute()
        break

      case BUILD_MAP:
        return buildMap(CONFIG.database).html
        break

      case EXTRACT_TOPO:
        const topo = buildMap(extdb).topology
        topo.forests = topo.forests.reduce((p, n) => {
          p.push([n.name, null, n.host, +n.replicaHost])
          return p
        }, [])
        return topo
        break

      case DUMP_CONFIG:
        return CONFIG
        break

      case DRY_RUN:
      default:
        return WLB.preview() + '\n\n' +
          JSON.stringify({
            map: beforeMap,
            plan: WLB.workList
          }, null, 2)
        break
    }
  }


  const result = run(STEP, CUR_STATE, CUR_ENV, EXTRACT_DB)
  /* show a html map of cluster */
  result
}
