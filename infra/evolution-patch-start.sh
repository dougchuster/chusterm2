#!/bin/bash
# Applies runtime patches to Evolution API before starting.
# Mounted as a volume so fixes survive image upgrades without rebuilding.

# --- Patch 1: await loadChatwoot() in connectToWhatsapp ---
# The original code calls loadChatwoot() without await (comma-operator pattern).
# This leaves localChatwoot.enabled=undefined when messages arrive, silently
# disabling the Chatwoot integration until the set endpoint is called manually.
node -e '
const fs = require("fs");
const file = "/evolution/dist/main.js";
let code = fs.readFileSync(file, "utf8");

const OLD = "return this.loadChatwoot(),this.loadSettings(),this.loadWebhook(),this.loadProxy(),await this.createClient(e)";
const NEW = "return(async()=>{await this.loadChatwoot();this.loadSettings();this.loadWebhook();this.loadProxy();return await this.createClient(e)})()";

if (code.includes(OLD)) {
  code = code.replace(OLD, NEW);
  fs.writeFileSync(file, code);
  console.log("[PATCH] loadChatwoot await fix applied.");
} else if (code.includes(NEW)) {
  console.log("[PATCH] loadChatwoot fix already present, skipping.");
} else {
  console.log("[PATCH WARNING] Expected pattern not found in main.js — may have changed in this image version.");
}
'

# --- Patch 2: do not cache decryption-failed messages as "duplicate" ---
# When Baileys fails to decrypt (Bad MAC / SessionError), it emits the message
# with no decoded `message` field. The original code caches the message id
# unconditionally BEFORE checking validity, so when WhatsApp retransmits the
# message after Baileys recovers the session, the retry is dropped as a
# "duplicate". Move the cache.set to AFTER the validity check so only
# successfully-decrypted messages get the duplicate marker.
node -e '
const fs = require("fs");
const file = "/evolution/dist/main.js";
let code = fs.readFileSync(file, "utf8");

const OLD = "if(await this.baileysCache.set(a,!0,5*60),t!==\"notify\"&&t!==\"append\"||n.message?.protocolMessage||n.message?.pollUpdateMessage||!n?.message||(_t.default.isLong(n.messageTimestamp)&&(n.messageTimestamp=n.messageTimestamp?.toNumber()),o?.groupsIgnore&&n.key.remoteJid.includes(\"@g.us\")))continue;";
const NEW = "if(t!==\"notify\"&&t!==\"append\"||n.message?.protocolMessage||n.message?.pollUpdateMessage||!n?.message||(_t.default.isLong(n.messageTimestamp)&&(n.messageTimestamp=n.messageTimestamp?.toNumber()),o?.groupsIgnore&&n.key.remoteJid.includes(\"@g.us\")))continue;await this.baileysCache.set(a,!0,5*60);";

if (code.includes(OLD)) {
  code = code.replace(OLD, NEW);
  fs.writeFileSync(file, code);
  console.log("[PATCH] duplicate-cache-after-decrypt fix applied.");
} else if (code.includes(NEW)) {
  console.log("[PATCH] duplicate-cache-after-decrypt fix already present, skipping.");
} else {
  console.log("[PATCH WARNING] duplicate-cache pattern not found in main.js — may have changed in this image version.");
}
'

# --- Patch 3: resolve WhatsApp @lid-only messages before Chatwoot contact lookup ---
# Some Baileys events arrive with remoteJid="@lid" but without key.senderPn.
# Evolution then searches/creates a Chatwoot contact using the LID number
# (for example +211...), opening a duplicate conversation. Rehydrate senderPn
# from a prior message with the same remoteJid before createConversation runs.
node -e '
const fs = require("fs");
const file = "/evolution/dist/main.js";
let code = fs.readFileSync(file, "utf8");

const OLD = "async createConversation(s,e){let t=e.key.remoteJid.includes(\"@lid\")&&e.key.senderPn,i=t?e.key.senderPn:e.key.remoteJid,o=`${s.instanceName}:createConversation-${i}`,n=`${s.instanceName}:lock:createConversation-${i}`,r=5e3;";
const NEW = "async createConversation(s,e){if(e.key.remoteJid.includes(\"@lid\")&&!e.key.senderPn){try{let a=await this.prismaRepository.message.findFirst({where:{instanceId:s.instanceId,key:{path:[\"remoteJid\"],equals:e.key.remoteJid},chatwootConversationId:{not:null}},orderBy:{messageTimestamp:\"desc\"}});a?.key?.senderPn&&(e.key.senderPn=a.key.senderPn,this.logger.verbose(`[PATCH] resolved LID ${e.key.remoteJid} to senderPn ${e.key.senderPn}`))}catch(a){this.logger.warn(`[PATCH] could not resolve LID ${e.key.remoteJid}: ${a}`)}}let t=e.key.remoteJid.includes(\"@lid\")&&e.key.senderPn,i=t?e.key.senderPn:e.key.remoteJid,o=`${s.instanceName}:createConversation-${i}`,n=`${s.instanceName}:lock:createConversation-${i}`,r=5e3;";

if (code.includes(OLD)) {
  code = code.replace(OLD, NEW);
  fs.writeFileSync(file, code);
  console.log("[PATCH] chatwoot LID senderPn rehydration fix applied.");
} else if (code.includes(NEW)) {
  console.log("[PATCH] chatwoot LID senderPn fix already present, skipping.");
} else {
  console.log("[PATCH WARNING] chatwoot createConversation LID pattern not found in main.js.");
}
'

# --- Patch 4: never save an unresolved @lid as a fake E.164 phone number ---
node -e '
const fs = require("fs");
const file = "/evolution/dist/main.js";
let code = fs.readFileSync(file, "utf8");

const OLD = "(r&&r.includes(\"@\")||!r)&&(c.phone_number=`+${e}`)";
const NEW = "(r&&r.includes(\"@\")&&!r.includes(\"@lid\")||!r)&&(c.phone_number=`+${e}`)";

if (code.includes(OLD)) {
  code = code.replace(OLD, NEW);
  fs.writeFileSync(file, code);
  console.log("[PATCH] unresolved LID fake-phone prevention applied.");
} else if (code.includes(NEW)) {
  console.log("[PATCH] unresolved LID fake-phone prevention already present, skipping.");
} else {
  console.log("[PATCH WARNING] createContact phone_number pattern not found in main.js.");
}
'

# --- Patch 5: redirecionar GET /manager/login para o login customizado do ChusteRM ---
# Injeta um <script> no index.html do manager que redireciona para CHUSTERM_URL/manager/login.
# Isso faz com que tanto o acesso direto (porta 8085) quanto via nginx vão para nossa tela.
node -e '
const fs   = require("fs");
const { execSync } = require("child_process");

const CHUSTERM_URL = (process.env.CHUSTERM_URL || "").replace(/\/$/, "");
const SERVER_URL   = (process.env.SERVER_URL   || "http://localhost:8080").replace(/\/$/, "");

if (!CHUSTERM_URL || CHUSTERM_URL === SERVER_URL) {
  console.log("[PATCH5] CHUSTERM_URL nao configurado ou igual a SERVER_URL — ignorando redirect patch.");
  process.exit(0);
}

const TARGET = CHUSTERM_URL + "/manager/login";
const MARKER = "chusterm-login-redirect-v1";
const SCRIPT = "<script id=\"" + MARKER + "\">(function(){var p=window.location.pathname;if(p===\"/manager/login\"||p===\"/manager/login/\"){window.location.replace(\"" + TARGET + "\");}})();<\/script>";

let htmlFiles = [];
try {
  htmlFiles = execSync("find /evolution -name \"index.html\" -not -path \"*/node_modules/*\" 2>/dev/null")
    .toString().trim().split("\n").filter(Boolean);
} catch(e) {}

if (htmlFiles.length === 0) {
  console.log("[PATCH5] Nenhum index.html encontrado em /evolution.");
  process.exit(0);
}

let patched = 0;
htmlFiles.forEach(function(f) {
  try {
    const html = fs.readFileSync(f, "utf8");
    if (html.includes(MARKER)) { console.log("[PATCH5] Redirect ja presente em " + f); return; }
    if (!html.includes("</head>")) return;
    fs.writeFileSync(f, html.replace("</head>", SCRIPT + "</head>"));
    console.log("[PATCH5] Redirect injetado em " + f + " -> " + TARGET);
    patched++;
  } catch(e) {
    console.log("[PATCH5] Erro ao patchar " + f + ": " + e.message);
  }
});

if (patched === 0) console.log("[PATCH5] Nenhum arquivo foi modificado.");
'

# Run original Evolution API startup
. ./Docker/scripts/deploy_database.sh && npm run start:prod
