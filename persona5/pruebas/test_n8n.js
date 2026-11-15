// Pruebas de lógica JS de n8n sin n8n instalado.
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const root = path.join(__dirname, '..');
function ejecutar(js, items, mem={}) {
  const fn = new Function('$input', '$getWorkflowStaticData', js);
  return fn({first:()=>items[0], all:()=>items}, ()=>mem);
}
function source(name, label) {
  const d=JSON.parse(fs.readFileSync(path.join(root, 'n8n/workflows',name),'utf8'));
  return d.nodes.find(n=>n.name===label).parameters.jsCode;
}
let filtro=fs.readFileSync(path.join(root,'n8n/snippets/filtro_sql_injection.js'),'utf8');
for(const payload of ['Lista datos; DROP TABLE clientes; --', "x' OR 1=1 --",'UNION SELECT clave FROM clientes']) {
  assert.strictEqual(ejecutar(filtro,[{json:{message:{text:payload,chat:{id:123}}}}])[0].json.validacion_sqli.bloqueado,true, payload);
}
let limpio=ejecutar(filtro,[{json:{message:{text:'Lista de alimentos de aves',chat:{id:123}}}}])[0].json;
assert.strictEqual(limpio.validacion_sqli.bloqueado,false);
assert.strictEqual(limpio.message.text,'Lista de alimentos de aves');

let memoria={};let r4=source('R4_ssh_fuerza_bruta.json','Evaluar R4');
assert.strictEqual(ejecutar(r4,[{json:{total:0}}],memoria)[0].json.alerta,false);
assert.strictEqual(ejecutar(r4,[{json:{total:20}}],memoria)[0].json.alerta,true);
assert.strictEqual(ejecutar(r4,[{json:{total:20}}],memoria)[0].json.alerta,false);
assert.strictEqual(ejecutar(r4,[{json:{total:0}}],memoria)[0].json.alerta,false);
assert.strictEqual(ejecutar(r4,[{json:{total:6}}],memoria)[0].json.alerta,true);

memoria={};let h1=source('H1_cambio_ufw.json','Evaluar H1');
assert.strictEqual(ejecutar(h1,[{json:{total:1,ultimo_evento_utc:'2026-11-14T00:00:01Z'}}],memoria)[0].json.alerta,true);
assert.strictEqual(ejecutar(h1,[{json:{total:1,ultimo_evento_utc:'2026-11-14T00:00:01Z'}}],memoria)[0].json.alerta,false);
assert.strictEqual(ejecutar(h1,[{json:{total:2,ultimo_evento_utc:'2026-11-14T00:00:02Z'}}],memoria)[0].json.alerta,true);

memoria={};let h3=source('H3_grant_agente_ia.json','Evaluar H3');
assert.strictEqual(ejecutar(h3,[{json:{total_permisos:0}}],memoria)[0].json.alerta,false);
assert.strictEqual(ejecutar(h3,[{json:{total_permisos:4}}],memoria)[0].json.alerta,true);
assert.strictEqual(ejecutar(h3,[{json:{total_permisos:4}}],memoria)[0].json.alerta,false);

memoria={};let d7=source('D7_select_masivo.json','Evaluar D7');
assert.strictEqual(ejecutar(d7,[{json:{query_id:'100',filas_acumuladas:'7500',consulta:'SELECT * FROM ventas'}}],memoria)[0].json.alerta,false);
assert.strictEqual(ejecutar(d7,[{json:{query_id:'100',filas_acumuladas:'9000',consulta:'SELECT * FROM ventas'}}],memoria)[0].json.alerta,true);
assert.strictEqual(ejecutar(d7,[{json:{query_id:'100',filas_acumuladas:'9000',consulta:'SELECT * FROM ventas'}}],memoria)[0].json.alerta,false);
assert.strictEqual(ejecutar(d7,[{json:{query_id:'101',filas_acumuladas:'1100',consulta:'SELECT * FROM clientes'}}],memoria)[0].json.alerta,true);
console.log('OK: filtro A2 y evaluadores R4/H1/H3/D7');
