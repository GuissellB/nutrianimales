// Test de lógica JS de N8N sin activar Docker/Telegram.
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const repo = path.resolve(__dirname, '..', '..');
function run(js, items, state={}) {
  const fn = new Function('$input', '$getWorkflowStaticData', js);
  return fn({first:()=>items[0], all:()=>items}, ()=>state);
}
function code(workflow, name) {
  const o = JSON.parse(fs.readFileSync(path.join(repo,workflow),'utf8'));
  const n = o.nodes.find(n=>n.name===name);
  assert.ok(n, `${workflow}: ${name}`);
  return n.parameters.jsCode;
}
const filter = fs.readFileSync(path.join(repo,'escenarios_ataque/n8n/snippets/filtro_sql_injection.js'),'utf8');
for (const payload of ['Lista datos; DROP TABLE clientes; --', "x' OR 1=1 --", 'UNION SELECT clave FROM clientes']) {
  const r = run(filter,[{json:{message:{text:payload,chat:{id:123}}}}])[0].json;
  assert.strictEqual(r.validacion_sqli.bloqueado,true,payload);
  assert.strictEqual(r.validacion_sqli.chat_id,123);
}
let r = run(filter,[{json:{message:{text:'Consulta inventario de aves',chat:{id:123}}}}])[0].json;
assert.strictEqual(r.validacion_sqli.bloqueado,false);
assert.strictEqual(r.message.text,'Consulta inventario de aves');
let mem={};
let r4=code('escenarios_ataque/n8n/workflows/R4_ssh_fuerza_bruta.json','Evaluar R4');
assert.strictEqual(run(r4,[{json:{total:0}}],mem)[0].json.alerta,false);
assert.strictEqual(run(r4,[{json:{total:20}}],mem)[0].json.alerta,true);
assert.strictEqual(run(r4,[{json:{total:20}}],mem)[0].json.alerta,false);
mem={};
let h1=code('escenarios_ataque/n8n/workflows/H1_cambio_ufw.json','Evaluar H1');
assert.strictEqual(run(h1,[{json:{total:1,ultimo_evento_utc:'2026-11-14T00:00:01Z'}}],mem)[0].json.alerta,true);
assert.strictEqual(run(h1,[{json:{total:1,ultimo_evento_utc:'2026-11-14T00:00:01Z'}}],mem)[0].json.alerta,false);
mem={};
let h3=code('n8n/workflows/H3_escalada_privilegios.json','Code in JavaScript');
assert.strictEqual(run(h3,[{json:{alerta_h3:false,detalle_hallazgos:'Ninguno'}}],mem)[0].json.alerta_h3,false);
assert.strictEqual(run(h3,[{json:{alerta_h3:true,detalle_hallazgos:'clientes (INSERT)'}}],mem)[0].json.alerta_h3,true);
assert.strictEqual(run(h3,[{json:{alerta_h3:true,detalle_hallazgos:'clientes (INSERT)'}}],mem)[0].json.alerta_h3,false);
mem={};
let d7=code('n8n/workflows/D7_exfiltracion_masiva.json','Code in JavaScript');
assert.strictEqual(run(d7,[{json:{queryid:'100',usuario:'agente_ia',rows:800,query:'SELECT * FROM public.ventas'}}],mem)[0].json.alerta_d7,false);
assert.strictEqual(run(d7,[{json:{queryid:'100',usuario:'agente_ia',rows:2000,query:'SELECT * FROM public.ventas'}}],mem)[0].json.alerta_d7,true);
assert.strictEqual(run(d7,[{json:{queryid:'100',usuario:'agente_ia',rows:2000,query:'SELECT * FROM public.ventas'}}],mem)[0].json.alerta_d7,false);
console.log('OK: A2, R4-SSH, H1-P5 y H3/D7 oficiales');
