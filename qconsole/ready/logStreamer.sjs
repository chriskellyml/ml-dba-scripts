/*
 * LOG STREAMER for MarkLogic
 * -
 * AUTHOR: Chris Kelly, MarkLogic Corporation
 * VERSION: 0.1
 */

const OPTION = 2

// Store different usage tests in the main function below
const SIMPLE = 1, FOLLOW = 2, RECENT_MESSAGES = 3
switch (OPTION) {
  case 1: findInLogs()
    .filter(['a', '-eval'])       // filter out lines containing negative entries, filter in others
    .sortBy(['-date', 'desc'])       // negative sign means descending
    // .hosts([1, 2, 3])                // defaults to all hosts
    // .type('access')                  // defaults to 'access'
    // .logPath('/custom/path/to/Logs') // defaults to sensible defaults
    // .verbose()                       // defaults to false
    .format('txt')                   // defaults to 'json' (a json array) and can be 'csv' or 'text'
    .process()                       // apply options in best order
    break

  case FOLLOW: findInLogs()
    .servers([8040, 8041])
    .follow()
    .process()
    .map( x => x.line )
    .join('\n')
    break
  
  case RECENT_MESSAGES: findInLogs()
    .sortBy(['-date', 'desc'])
    //.format('txt')
    .follow(false)
    .servers([8040, 8041, 'Task'])
    .process()
    .slice(1,10)
    break

  default: showHelp(); break
}

/* LICENSE: MIT
 * NOTES: This script can be run direct from Query Console but is intended to be
 *        used by simply looping using client (e.g. bash, python, node, etc.)
 *
 * DESCRIPTION:
 * Find the last error in the log and prettify
 * - To ensure proper tailing, this script makes (light) use of server
 *   fields to track the time of the most recently read log entry.
 *
 * OPTIONS:
 * - The script can be run with the following parameters:
 *   - FILTER: a string to filter the log entries by
 *   - FLAGS: a string of flags separated by '+'
 *     - no-eval: filter out noisy eval requests
 *   - HOSTS: a comma separated list of hosts to scan (if ommited it will
 *     scan all hosts in the cluster with the overhead of finding them first)
 *
 * TODO:
 * - Save and share gist
 * - Add server-side timing recommendations
 * - Integrate error log in same view
 * - Extract cluster nodes and splice those logs in with source column
 * - Skip over server stored number of lines (faster than parsing)
 * - Sort results if there are multiple
 */

/*****************************************************************/
/**                 I M P L E M E N T A T I O N                 **/
/*****************************************************************/
function findInLogs() {
  // Wrapper class to pass methods
  class LogFinder {
    constructor() {
      this._description = ''
      this._sortBy = []
      this._type = 'error'
      this._filter = []
      this._hosts = []
      this._servers = []
      this._follow = false
      this._logPath = '/var/opt/MarkLogic/Logs'
      this._output = ''
    }
    // Store user options in any order and execute in required order later
    type(str) {
      this._type = str
      return this
    }
    sortBy(arr) {
      this._sortBy = arr
      return this
    }
    filter(arr) {
      this._filter = arr
      return this
    }
    hosts(arr) {
      this._hosts = arr
      return this
    }
    logPath(str) {
      this._logPath = str
      return this
    }
    servers(arr) {
      this._servers = arr
      return this
    }
    format(str) {
      this._format = str
      return this
    }
    verbose() {
      this._verbose = true
      return this
    }
    follow(val = true) {
      this._follow = val
      return this
    }
    process() {
      const {
        _description, _sortBy, _filter, _hosts, _logPath, 
        _format, _follow, _verbose, _type, _servers
      } = this

      const fieldSorter = (fields) => (a, b) => fields.map(o => {
        let dir = 1;
        if (o[0] === '-') { dir = -1; o = o.substring(1); }
        return a[o] > b[o] ? dir : a[o] < b[o] ? -(dir) : 0;
      }).reduce((p, n) => p ? p : n, 0);

      var DEFAULTS = { VERBOSE: _verbose, TYPE: _type, LOG_PATH: _logPath, SERVERS: _servers }
      if (xdmp.getRequestPath().toString().startsWith('/qconsole')) {
        // If running from QConsole, use the provided parameters
        DEFAULTS = {
          ...DEFAULTS,
          FLAGS: 'no-eval+no-moz+no-saf+no-chrome',
          FORMAT: 'json',
          FOLLOW: _follow,
        }
      }

      const result = logStreamer({ ...DEFAULTS })
      /*
        .filter(result => {
          let removals = _filter
            .filter(f => f.startsWith('-'))
            .map(f => f.substring(1))
          return removals.every(f => !result.line.includes(f))
        })
        .filter(result => {
          let additions = _filter
            .filter(f => !f.startsWith('-'))
          return additions.some(f => result.line.includes(f)) 
        })
        */
        .sort(fieldSorter(_sortBy))
        .map((ln = {}) => {
          if (_type === 'access') {
            switch (_format) {
              case 'csv':
                return `${line.date},${line.user},${line.source},${line.rest}`
              case 'text':
              case 'txt':
                return `${line.date} ${line.user} ${line.source} ${line.rest}`
              default:
                return ln
            }
          } else {
            const { date, line, host, path } = ln 
            const logfile = path.split('/').pop()
            switch (_format) {
              case 'csv':
                return `${date},${host},${logfile},${line}`
              case 'text':
              case 'txt':
                return `${date} ${host} ${logfile} ${line}`
              default:
                return ln 
            }
          }
        })
      return result
      return [
        "DESCRIPTION: " + _description,
        "SORT BY: " + _sortBy,
        "FILTER: " + _filter,
        "HOSTS: " + _hosts,
        "LOG PATH: " + _logPath,
        result,
      ].join('\n')

      /*

      [
        "VERSION: " + VERSION,
        "===== LOG DATA =====",
        ,
        VERBOSE ? [
          '===== VERBOSE INFORMATION =====',
          `Prior cursors: ${JSON.stringify(LT.initialCursors)}`,
          `Data length: ${LT.logLength}, File: ${LT.logFile}`,
          `Log data length: ${LT.logData.length}`,
          `Time elapsed [${xdmp.elapsedTime()}]`,
        ] : ''
      ].join('\n')
       */
    }
  }
  return new LogFinder()
}

// Main implementation hoisted
function logStreamer(args) {
  const {
    VERSION = '0.0.1',
    FORMAT, FILTER, FLAGS, TYPE = 'error',
    USAGE, VERBOSE = 'false',
    SERVERS = [],
    LOG_PATH, FOLLOW
  } = args
  const DD = msg => (VERBOSE !== 'false') && xdmp.log(`DD: ${VERBOSE} ${msg}`)
  if (USAGE) {
    return [
      'Usage: recentAccess.sjs [options]',
      'Options:',
      '',
      '  FILTER: only show log entries that contain this string',
      '  FLAGS: a string of flags separated by "+"',
      '    no-eval: filter out noisy eval requests',
      '    no-moz: filter out noisy Mozilla requests',
      '    no-saf: filter out noisy Safari requests',
      '    no-chrome: filter out noisy Chrome requests',
      '  FORMAT: output format (json, csv, or text)',
      '  LOG_PATH: path to log files (default: /var/opt/MarkLogic/Logs)',
      '  FOLLOW: follow the log file (default: true)',
      '  TYPE: type of log to scan (access or error)',
      '  VERBOSE: show verbose information',
      '  USAGE: show this help message',
      '',
      'Examples:',
      '  mlsh eval -s recentAccess.sjs -v FILTER=foo,FLAGS=no-eval+no-moz+no-saf+no-chrome,FORMAT=json,LOG_PATH=/var/opt/MarkLogic/Logs,FOLLOW=true,TYPE=error,VERBOSE=true,USAGE=false',

    ].join('\n')
  } else {

    // entry point
    const main = (fmt) => {
      let LT
      DD('External variables:')
      const extVars = { FILTER, FLAGS, FORMAT, LOG_PATH, FOLLOW, TYPE, VERBOSE, USAGE }
      Object.keys(extVars).forEach(key => {
        if (extVars[key]) {
          DD(`${key}: ${extVars[key]}`)
        }
      })
      switch (TYPE) {
        case 'access':
          LT = new AccessLogTracker()
          if (LOG_PATH) LT.logPath = LOG_PATH
          LT.processLog(FILTER, FLAGS)
          break

        case 'error':
          LT = new ErrorLogTracker()
          if (LOG_PATH) LT.logPath = LOG_PATH
          LT.processLog(FILTER, FLAGS)
          LT._fileNameEnding = '_ErrorLog.txt'
          break
      }
      return LT.logData
    }

    /**
     * Base class for scannning log files and tracking position.
     */
    class LogTracker {
      constructor() {
        DD('LogTracker constructor')
        this.logData = [] // Data gather during this transaction are stored here.
        this.hosts = Array.from(xdmp.hosts()).map(x => xdmp.hostName(x).toString())
        // Cursors point to last location in all files scans
        // This is the fastest way to process only recent changes
        const sf = getServerField('LOG_CURSORS').toString().trim()
        this.cursors = sf
          ? JSON.parse(sf)
          : this.hosts.map(h => ({ host: h.toString(), logs: {} }))
        this.initialCursors = JSON.parse(JSON.stringify(this.cursors))
      }

      set logPath(path) { this._logPath = path }

      // Get the log path. Use sensible defaults if no override is provided
      get logPath() {
        return this._logPath || (platform() === 'winnt'
          ? '/Program Files/MarkLogic/Data/Logs'
          : '/var/opt/MarkLogic/Logs')
      }

      set fileNameEnding(str) { this._fileNameEnding = str }

      // Get the lines of logs from where we last left off
      get logLines() {
        const lines = this.hosts
          .map(host => Array
            .from(filesystemDirectory(this.logPath))
            .filter(x => x.filename.endsWith(this._fileNameEnding) && x.contentLength !== 0)
            .filter(x => SERVERS.length ? SERVERS.some(s => `${x.filename}`.includes(`${s}_`)) : true)
            .map(x => x.pathname)
            .map(path => ({
              path, host, cursorLocation: this.cursors
                .filter(c => c.host === host)
                .map(c => {
                  return c.logs[path] || -500
                })
            }))
          )
          .reduce((p, n) => [...p, ...n], [])
          .map(x => {
            const { host, path, cursorLocation } = x
            let data = filesystemFile(path).toString()
            this.logLength = data.length
            this.logFile = path
            this.logSize = `Path: ${path} - Size: ${data.length} - Cursor: ${cursorLocation}`
            if (FOLLOW) {
              this.cursors
              .filter(x => x.host === host)
              .forEach(x => x.logs[path] = data.length)
              data = data.substr(cursorLocation)
            }
            this.raw = data
            const lines = data.split('\n')
            return lines.map(x => ({ host, path, line: x }))
          })
          .reduce((p, n) => [...p, ...n], [])
        setServerField('LOG_CURSORS', JSON.stringify(this.cursors))
        return lines
      }
    }

    /**
     * LogTracker class
     */
    class AccessLogTracker extends LogTracker {
      constructor() {
        DD('AccessLogTracker constructor')
        super()
        this.filterFlags = {
          'no-eval': 'POST /v1/eval ',
          'no-moz': 'Mozilla',
          'no-saf': 'Safari',
          'no-chrome': 'Chrom' // Chrome, Chromium, Chrome Mobil
        }
        this.type = 'access'
        this.fileNameEnding = `_AccessLog.txt`
      }

      // Loop over all log lines and apply filters and parsing
      processLog(filter, flags = '') {
        this.flags = flags.split('+').filter(x => x)
        this.logData = this.logLines
          .filter(x => x.line.trim())
          .filter(x => Object.keys(this.filterFlags).some(flag =>
            x.line.includes(this.filterFlags[flag])
          ))
          .map(x => {
            // replace double quotes with single quotes
            x.line = x.line.replace(/\"/g, "'")
            return x
          })
          .map(x => {
            const { line } = x
            return {
              ...x,
              date: AccessLogTracker.extractDate(line),
              rest: line.split(']').slice(1).join(']').replace(/\"/g, ''),
              source: line.split(' ').shift(),
              user: line.split('-')[1].trim().split(' ').shift().trim() || '-',
            }
          })
          .filter(x => filter ? x.line.includes(filter) : true)
          .sort((a, b) => a.date > b.date ? 1 : -1)
      }

      // Extract the date as formated by the access log
      // e.g [01/Jan/2019:00:00:00 +0000]
      // ISO dates are used in other logs
      static extractDate(str) {
        let date = str.match(/\[(.*?)\]/)[1]
        let res = date.match(/([\d]{2})\/([A-Za-z]{3})\/([\d]{4}):([\d]{2}:[\d]{2}:[\d]{2})/)
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        let isoDate = `${res[3]}-${`00${months.indexOf(res[2]) + 1}`.slice(-2)}-${res[1]}T${res[4]}.000Z`
        return isoDate
      }

      // Output the log lines
      output(format = 'csv') {
        switch (format) {
          case 'csv':
            return this.logData
              .map(x => `${x.date},${x.user},${x.source},${x.rest}`)
              .join('\n')
          case 'json':
            return JSON.stringify(this.logData)
          // prettified json
          case 'jsonpp':
            return JSON.stringify(this.logData, null, 2)
          case 'text':
          case 'txt':
            return this.logData
              .map(x => `${x.date} ${x.user} ${x.source} ${x.rest}`)
              .join('\n')

          default:
            return this.logData
        }
      }
    }

    /**
     * Error log tracker class
     * @extends LogTracker
     * @param {string} filter - Filter string
     * @param {string} flags - Flags to apply to the filter
     * @param {string} format - Output format
     *
     * @example
     * const tracker = new ErrorLogTracker()
     *
     * // Set the log path  (optional)
     * tracker.logPath = '/var/opt/MarkLogic/Logs'
     *
     * // Process the logs
     * tracker.processLog('error')
     *
     * // Output the logs
     *
     * // Output as csv
     * tracker.output('csv')
     */
    class ErrorLogTracker extends LogTracker {
      constructor() {
        DD('ErrorLogTracker constructor')
        super()
        this.filterFlags = {
          'no-chrome': 'Chrom'
        }
        this.type = 'error'
        this.fileNameEnding = `ErrorLog.txt`
      }

      // Loop over all log lines and apply filters and parsing
      processLog(filter, flags = '') {
        this.flags = flags.split('+').filter(x => x)
        this.logData = this.logLines
          .filter(x => x.line.trim())
          .map(x => {
            // replace double quotes with single quotes
            x.line = x.line.replace(/\"/g, "'")
            return x
          })
          .filter(x => Object.keys(this.filterFlags).some(flag =>
            !x.line.includes(this.filterFlags[flag])
          ))
          .map(x => {
            const { line } = x
            return {
              ...x,
              date: ErrorLogTracker.extractDate(line),
            }
          })
          .filter(x => filter ? x.line.includes(filter) : true)
          .sort((a, b) => a.date > b.date ? 1 : -1)
      }

      // Extract the date as formated by the access log
      // e.g take from the start of the line
      // ISO dates are used in other logs
      static extractDate(str) {
        return str.substring(0, 25).split(' ').slice(0, 2).join('T')
      }

    }

    // extract library functions for neater code
    const {
      filesystemDirectory, filesystemFile, platform, getServerField, setServerField
    } = xdmp
    return main('txt')
  }
}

function showHelp() {
  return `
Example usage:
  findInLogs()
    .filter(['a', '-eval'])       // filter out lines containing negative entries, filter in others
  `
}



