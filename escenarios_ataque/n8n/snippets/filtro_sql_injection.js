// Nodo Code de n8n: "Run Once for Each Item" NO. Seleccionar "Run Once for All Items".
// Ubicar inmediatamente después del Telegram Trigger y antes de cualquier nodo IA/SQL.
// Conservar el mensaje de origen para que la rama permitida pueda continuar.
const original = $input.first().json;
const texto = String(original.message?.text ?? original.text ?? '').slice(0, 4000);
const patrones = [
  /;\s*(drop|delete|truncate|alter|create|grant|revoke|insert|update)\b/i,
  /\b(drop|truncate)\s+(table|database|schema|role|user)\b/i,
  /\bunion\s+(all\s+)?select\b/i,
  /--\s*$|\/\*|\*\//,
  /\b(pg_sleep|pg_read_file|copy\s+.*\s+program|lo_import|xp_cmdshell)\b/i,
  /\bor\s+1\s*=\s*1\b/i,
];
const reglas = patrones.filter(p => p.test(texto)).map(p => p.source);
return [{ json: {
  ...original,
  validacion_sqli: {
    bloqueado: reglas.length > 0,
    reglas: reglas.join(' | '),
    chat_id: original.message?.chat?.id ?? original.chat_id ?? null,
    usuario_telegram: String(original.message?.from?.username ?? original.message?.from?.id ?? 'desconocido').slice(0, 100),
    detalle: `Bloqueo A2 - usuario=${String(original.message?.from?.username ?? original.message?.from?.id ?? 'desconocido').slice(0,100)}; texto=${texto.slice(0,200)}`,
  },
}}];
// Importante: este filtro es una defensa adicional. Nunca ejecutar SQL generado
// directamente a partir de entrada del chat. Consultas siempre parametrizadas
// y credenciales del agente sin INSERT/UPDATE/DELETE/DROP.
