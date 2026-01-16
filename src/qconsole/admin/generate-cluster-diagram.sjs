const EXTRACT_DB = 'content-d';

const admin = require("/MarkLogic/admin.xqy");
let config = admin.getConfiguration();

const buildMap = (database) => {
  const forests = Array.from(admin.getForestIds(config));
  const dbId = xdmp.database(database);
  const hosts = Array.from(xdmp.hosts()).map(h => xdmp.hostName(h)).sort();
  const topology = {
    hosts,
    database: dbId,
    forests: []
  };

  forests
    .filter(x => `${admin.forestGetDatabase(config, x)}` === `${xs.string(dbId)}`)
    .forEach(x => {
      const rps = Array.from(admin.forestGetReplicas(config, x)).map(x => admin.forestGetName(config, x));
      const name = admin.forestGetName(config, x);
      const host = hosts.indexOf(xdmp.hostName(admin.forestGetHost(config, x)));
      topology.forests.push({
        name,
        host,
        replicas: rps.join(';'),
        replicaHost: rps.map(r => {
          const id = admin.forestGetHost(config, admin.forestGetId(config, r));
          return hosts.indexOf(xdmp.hostName(id));
        }).join(';'),
      });
    });

  return topology;
};

const asHtml = (topology) => {
  const colors = [
    '#FF6347', '#3CB371', '#BA55D3', '#FFE4C4', '#D2691E', '#00BFFF', '#4682B4', '#FFA07A', '#FFDEAD', '#B0C4DE',
    '#FFD700', '#8B4513', '#5F9EA0', '#B22222', '#FF1493', '#ADFF2F', '#2E8B57', '#9400D3', '#FF69B4', '#7FFF00',
    '#6495ED', '#DC143C', '#00CED1', '#FF4500', '#DAA520', '#32CD32', '#8A2BE2', '#FFDAB9', '#40E0D0', '#FF7F50',
    '#6A5ACD', '#FF00FF', '#7B68EE', '#8B0000', '#4169E1', '#F4A460', '#EE82EE', '#CD5C5C', '#00FA9A', '#D8BFD8'
  ];
  
  const active = topology.forests.map(x => [x.name, x.host, x.host]);
  const replicas = topology.forests.map(x => [x.replicas, x.replicaHost, x.host]);
  
  const rows = (list) => topology.hosts.map((h, i) => `
    <td>${list.filter(x => +x[1] === i).map(x => {
      const c = colors[x[2] % colors.length];
      return `<div style="color:${c}">${x[0]}</div>`;
    }).join('')}</td>`).join('');

  return `<table border="1">
    <thead>
      <tr><th>Info</th>${topology.hosts.map(h => `<th>${h}</th>`).join('')}</tr>
    </thead>
    <tbody>
      <tr><td>Active</td>${rows(active)}</tr>
      <tr><td>Replicas</td>${rows(replicas)}</tr>
    </tbody>
  </table>`;
};

const extractTopology = (extdb) => {
  const topo = buildMap(extdb);
  return asHtml(topo);
};

const result = extractTopology(EXTRACT_DB);
result;
