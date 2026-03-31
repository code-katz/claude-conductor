const fs = require('fs');
const path = require('path');
const os = require('os');
const express = require('express');
const chokidar = require('chokidar');

// --- Pricing ---
const PRICING = {
  'claude-opus-4-6':   { input: 15.00, output: 75.00 },
  'claude-sonnet-4-6': { input: 3.00,  output: 15.00 },
  'claude-haiku-4-5':  { input: 0.80,  output: 4.00 },
};

function getPricing(model) {
  if (!model) return PRICING['claude-sonnet-4-6'];
  for (const [key, val] of Object.entries(PRICING)) {
    if (model.includes(key)) return val;
  }
  return PRICING['claude-sonnet-4-6']; // fallback
}

// --- SESSIONS.md Parsing ---
let conductorData = { activeSessions: [], mergeOrder: '', projectRoot: '' };
let conductorLinks = new Map(); // conductorSessionNumber -> { sessionId, persona, task, files, status, dependsOn }

function findSessionsFile(startDir) {
  let dir = startDir || process.cwd();
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, '.git'))) {
      const sf = path.join(dir, 'SESSIONS.md');
      if (fs.existsSync(sf)) return { file: sf, root: dir };
      return { file: null, root: dir };
    }
    dir = path.dirname(dir);
  }
  return { file: null, root: startDir || process.cwd() };
}

function parseSessionsTable(content) {
  const lines = content.split('\n');
  const sessions = [];
  let inActiveTable = false;
  let headerPassed = false;

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('## Active Sessions')) {
      inActiveTable = true;
      headerPassed = false;
      continue;
    }
    if (inActiveTable && trimmed.startsWith('##')) break; // next section
    if (!inActiveTable) continue;
    if (!trimmed.startsWith('|')) continue;
    // Skip header row and separator
    if (trimmed.includes('---')) { headerPassed = true; continue; }
    if (!headerPassed) continue;

    const cols = trimmed.split('|').map(c => c.trim()).filter(c => c !== '');
    if (cols.length < 6) continue;

    sessions.push({
      number: parseInt(cols[0], 10),
      persona: cols[1] || '',
      task: cols[2] || '',
      files: cols[3] || '',
      status: cols[4] || '',
      started: cols[5] || '',
      dependsOn: cols[6] || '',
      notes: cols[7] || '',
    });
  }
  return sessions;
}

function parseMergeOrder(content) {
  const lines = content.split('\n');
  let inMerge = false;
  const mergeLines = [];
  for (const line of lines) {
    if (line.trim().startsWith('## Merge Order')) { inMerge = true; continue; }
    if (inMerge && line.trim().startsWith('##')) break;
    if (inMerge && line.trim()) mergeLines.push(line.trim());
  }
  return mergeLines.join('\n');
}

function loadSessionsFile(filePath) {
  if (!filePath || !fs.existsSync(filePath)) {
    conductorData = { activeSessions: [], mergeOrder: '', projectRoot: conductorData.projectRoot };
    return;
  }
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    conductorData.activeSessions = parseSessionsTable(content);
    conductorData.mergeOrder = parseMergeOrder(content);
  } catch (e) {
    // Silently ignore parse errors
  }
}

// --- Auto-linking: JSONL first-message scan ---
const autoLinks = new Map(); // JSONL sessionId -> { conductorNumber, persona }
const scannedSessions = new Set(); // sessionIds we've already scanned

function scanSessionForLink(sessionId) {
  if (scannedSessions.has(sessionId)) return;
  const session = sessions.get(sessionId);
  if (!session) return;

  // Look through recent log for user messages that contain session patterns
  for (const entry of session.recentLog) {
    if (entry.type !== 'user') continue;
    const text = entry.msg || '';

    // Match patterns: "session #1", "Session 1", "#1 Akira", "You are session #2 (Sasha)"
    const sessionMatch = text.match(/[Ss]ession\s*#?(\d+)/);
    if (sessionMatch) {
      const num = parseInt(sessionMatch[1], 10);
      // Try to extract persona: "(Sasha)", "/sasha", "Persona: Sasha"
      const personaMatch = text.match(/\((\w+)\)|\/(\w+)|[Pp]ersona:\s*(\w+)/);
      const persona = personaMatch ? (personaMatch[1] || personaMatch[2] || personaMatch[3]) : '';
      autoLinks.set(sessionId, { conductorNumber: num, persona });
      scannedSessions.add(sessionId);
      return;
    }

    // Match: "/conductor u 1", "/conductor update 1"
    const cmdMatch = text.match(/conductor\s+u(?:pdate)?\s+(\d+)/i);
    if (cmdMatch) {
      const num = parseInt(cmdMatch[1], 10);
      autoLinks.set(sessionId, { conductorNumber: num, persona: '' });
      scannedSessions.add(sessionId);
      return;
    }
  }
}

function loadLinksFile(projectRoot) {
  const linksPath = path.join(projectRoot, '.conductor-links.json');
  if (!fs.existsSync(linksPath)) return;
  try {
    const data = JSON.parse(fs.readFileSync(linksPath, 'utf8'));
    if (Array.isArray(data)) {
      for (const entry of data) {
        if (entry.sessionId && entry.conductorNumber) {
          autoLinks.set(entry.sessionId, {
            conductorNumber: entry.conductorNumber,
            persona: entry.persona || '',
          });
          scannedSessions.add(entry.sessionId);
        }
      }
    }
  } catch (e) {
    // Ignore malformed file
  }
}

function saveLinksFile(projectRoot) {
  const linksPath = path.join(projectRoot, '.conductor-links.json');
  const data = [];
  for (const [sessionId, link] of autoLinks) {
    data.push({ sessionId, conductorNumber: link.conductorNumber, persona: link.persona });
  }
  try {
    fs.writeFileSync(linksPath, JSON.stringify(data, null, 2) + '\n');
  } catch (e) {
    // Silently ignore write errors
  }
}

// --- Session State ---
const sessions = new Map();
const fileOffsets = new Map(); // path -> byte offset
const seenMessageIds = new Map(); // sessionId -> Set of message.id

function getOrCreateSession(sessionId) {
  if (!sessions.has(sessionId)) {
    sessions.set(sessionId, {
      sessionId,
      projectHash: '',
      cwd: '',
      label: '',
      model: '',
      gitBranch: '',
      status: 'idle',
      tokensIn: 0,
      tokensOut: 0,
      cacheCreationIn: 0,
      cacheReadIn: 0,
      costUSD: 0,
      turnCount: 0,
      activeFiles: [],
      recentLog: [],
      startedAt: null,
      lastEventAt: null,
      lastEventType: '',
      lastContentTypes: [],
      lastTurnInputTotal: 0, // input + cache for context window estimate
      permissionMode: '',
      version: '',
      subagents: {}, // agentId -> { task, status, tokensOut, lastEventAt }
    });
    seenMessageIds.set(sessionId, new Map()); // messageId -> {in, out, cacheCreate, cacheRead}
  }
  return sessions.get(sessionId);
}

function addToRecentLog(session, entry) {
  session.recentLog.push(entry);
  if (session.recentLog.length > 30) {
    session.recentLog = session.recentLog.slice(-30);
  }
}

function extractActiveFiles(content) {
  const files = [];
  if (!Array.isArray(content)) return files;
  for (const block of content) {
    if (block.type === 'tool_use' && block.input) {
      const fp = block.input.file_path || block.input.path || block.input.command;
      if (fp && typeof fp === 'string' && !fp.includes(' ')) {
        files.push(path.basename(fp));
      }
    }
  }
  return files;
}

function processEvent(event, projectHash) {
  if (!event || !event.sessionId) return;
  if (event.type === 'file-history-snapshot' || event.type === 'queue-operation' || event.type === 'last-prompt') return;

  const session = getOrCreateSession(event.sessionId);
  if (!event.timestamp) return; // skip events without timestamps
  const ts = event.timestamp;

  if (!session.startedAt) session.startedAt = ts;
  session.lastEventAt = ts;
  session.lastEventType = event.type;
  session.projectHash = projectHash;

  if (event.cwd && !session.cwd) {
    session.cwd = event.cwd;
    const parts = event.cwd.split('/').filter(Boolean);
    session.label = parts.slice(-2).join('/');
  }
  if (event.gitBranch && !session.gitBranch) {
    session.gitBranch = event.gitBranch;
  }
  if (event.version) session.version = event.version;
  if (event.permissionMode) session.permissionMode = event.permissionMode;

  const msg = event.message || {};
  const content = msg.content;
  const contentTypes = Array.isArray(content)
    ? content.map(c => c.type)
    : (typeof content === 'string' ? ['text'] : []);
  session.lastContentTypes = contentTypes;

  if (event.type === 'assistant' && msg.usage) {
    const msgId = msg.id;
    const usage = msg.usage;
    const seen = seenMessageIds.get(event.sessionId);

    if (msg.model) session.model = msg.model;

    // Track per-message-id usage, only count the delta
    const prev = seen.get(msgId) || { in: 0, out: 0, cacheCreate: 0, cacheRead: 0 };
    const curr = {
      in: usage.input_tokens || 0,
      out: usage.output_tokens || 0,
      cacheCreate: usage.cache_creation_input_tokens || 0,
      cacheRead: usage.cache_read_input_tokens || 0,
    };

    // Add only the difference (later events for same msgId have cumulative values)
    session.tokensIn += Math.max(0, curr.in - prev.in);
    session.tokensOut += Math.max(0, curr.out - prev.out);
    session.cacheCreationIn += Math.max(0, curr.cacheCreate - prev.cacheCreate);
    session.cacheReadIn += Math.max(0, curr.cacheRead - prev.cacheRead);

    seen.set(msgId, curr);

    // Track last turn's total input for context window estimate
    session.lastTurnInputTotal = curr.in + curr.cacheCreate + curr.cacheRead;

    // Recalculate cost
    const pricing = getPricing(session.model);
    session.costUSD =
      (session.tokensIn * pricing.input / 1_000_000) +
      (session.tokensOut * pricing.output / 1_000_000) +
      (session.cacheCreationIn * pricing.input * 0.25 / 1_000_000) +
      (session.cacheReadIn * pricing.input * 0.10 / 1_000_000);

    // Log tool use
    if (Array.isArray(content)) {
      for (const block of content) {
        if (block.type === 'tool_use') {
          addToRecentLog(session, {
            time: ts,
            type: 'tool',
            msg: block.name + (block.input?.file_path ? `: ${path.basename(block.input.file_path)}` : ''),
          });
        } else if (block.type === 'text' && block.text) {
          const snippet = block.text.substring(0, 120);
          addToRecentLog(session, { time: ts, type: 'think', msg: snippet });
        }
      }
      // Track active files
      const newFiles = extractActiveFiles(content);
      if (newFiles.length) {
        const fileSet = new Set([...newFiles, ...session.activeFiles]);
        session.activeFiles = [...fileSet].slice(0, 10);
      }
    }

    // Count turns by unique message IDs with stop_reason
    if (msg.stop_reason) {
      session.turnCount++;
    }
  }

  // --- Subagent tracking ---
  if (event.agentId && !event.agentId.startsWith('acompact')) {
    const aid = event.agentId;
    if (!session.subagents[aid]) {
      session.subagents[aid] = { agentId: aid, task: '', status: 'idle', tokensOut: 0, lastEventAt: null };
    }
    const sub = session.subagents[aid];
    sub.lastEventAt = ts;

    // Derive subagent status
    const subElapsed = Date.now() - new Date(ts).getTime();
    sub.status = subElapsed < 15_000 ? 'thinking' : 'idle';

    // Capture task from first user message
    if (!sub.task && event.type === 'user' && msg.role === 'user') {
      const text = typeof content === 'string' ? content : (Array.isArray(content) ? content.find(c => c.type === 'text')?.text : '');
      if (text) sub.task = text.substring(0, 120);
    }

    // Track subagent output tokens
    if (event.type === 'assistant' && msg.usage && msg.stop_reason) {
      sub.tokensOut += msg.usage.output_tokens || 0;
    }
  }

  if (event.type === 'user' && msg.role === 'user') {
    const text = typeof content === 'string'
      ? content.substring(0, 120)
      : (Array.isArray(content) ? content.find(c => c.type === 'text')?.text?.substring(0, 120) : '');
    if (text) {
      addToRecentLog(session, { time: ts, type: 'user', msg: text });
    }
  }
}

// --- Enhanced Status Detection ---
// Maps dashboard states to conductor-aware statuses
const EDIT_TOOLS = new Set(['Edit', 'Write', 'NotebookEdit']);
const TEST_PATTERNS = /\b(test|jest|pytest|vitest|mocha|lint|eslint|ruff|biome|check)\b/i;

function deriveStatus(session) {
  if (!session.lastEventAt) return 'idle';
  const elapsed = Date.now() - new Date(session.lastEventAt).getTime();

  if (elapsed > 300_000) return 'idle-stale'; // 5 min -> disconnected
  if (elapsed > 60_000) return 'idle';

  // Check for error in recent log
  const lastLogs = session.recentLog.slice(-3);
  if (lastLogs.some(l => l.type === 'error')) return 'error';

  if (elapsed < 15_000) {
    if (session.lastEventType === 'assistant') {
      if (session.lastContentTypes.includes('tool_use')) return 'thinking';
      if (session.lastContentTypes.includes('text')) return 'waiting';
      if (session.lastContentTypes.includes('thinking')) return 'thinking';
    }
    if (session.lastEventType === 'progress') return 'thinking';
    if (session.lastEventType === 'user') return 'thinking';
  }

  return 'idle';
}

// Conductor-enriched status: refines 'thinking' into coding/planning/reviewing
function deriveConductorStatus(session) {
  const base = deriveStatus(session);
  if (base !== 'thinking') {
    if (base === 'waiting') return 'needs_input';
    if (base === 'idle-stale') return 'disconnected';
    return base;
  }

  // Check recent tool use to distinguish coding vs planning vs reviewing
  const recentTools = session.recentLog.slice(-5);
  for (let i = recentTools.length - 1; i >= 0; i--) {
    const entry = recentTools[i];
    if (entry.type !== 'tool') continue;

    const toolName = entry.msg.split(':')[0].trim();

    // Bash with test/lint commands -> reviewing
    if (toolName === 'Bash' && TEST_PATTERNS.test(entry.msg)) return 'reviewing';

    // Write/Edit tools -> coding
    if (EDIT_TOOLS.has(toolName)) return 'coding';
  }

  // No edit tools in recent history -> planning (reading/exploring)
  return 'planning';
}

// --- JSONL File Processing ---
function processFile(filePath) {
  let stat;
  try { stat = fs.statSync(filePath); } catch { return; }
  const offset = fileOffsets.get(filePath) || 0;
  if (stat.size <= offset) return;

  const projectHash = path.basename(path.dirname(filePath));
  const stream = fs.createReadStream(filePath, { start: offset, encoding: 'utf8' });
  let buffer = '';

  stream.on('data', (chunk) => { buffer += chunk; });
  stream.on('end', () => {
    fileOffsets.set(filePath, stat.size);
    const lines = buffer.split('\n');
    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const event = JSON.parse(line);
        processEvent(event, projectHash);
      } catch (e) {
        // Skip malformed lines (partial writes)
      }
    }
  });
}

// --- Express Server ---
const app = express();
app.use(express.static(path.join(__dirname, 'public')));

app.post('/api/open-folder', express.json(), (req, res) => {
  const folder = req.body.path;
  if (!folder || typeof folder !== 'string') return res.status(400).json({ error: 'No path' });
  if (!fs.existsSync(folder)) return res.status(404).json({ error: 'Folder not found' });
  const { execFile } = require('child_process');
  const plat = process.platform;
  if (plat === 'win32') {
    execFile('explorer', [folder.replace(/\//g, '\\')], () => {});
  } else if (plat === 'darwin') {
    execFile('open', [folder], () => {});
  } else {
    execFile('xdg-open', [folder], () => {});
  }
  res.json({ ok: true });
});

app.get('/api/sessions', (req, res) => {
  // Run auto-linking scan on all sessions
  for (const sessionId of sessions.keys()) {
    scanSessionForLink(sessionId);
  }
  // Save links if any new ones were found
  if (autoLinks.size > 0 && conductorData.projectRoot) {
    saveLinksFile(conductorData.projectRoot);
  }

  // Build list with derived status
  const all = [];
  for (const session of sessions.values()) {
    const status = deriveStatus(session);
    const conductorStatus = deriveConductorStatus(session);
    // Convert subagents object to sorted array, only include active ones
    const subagentList = Object.values(session.subagents)
      .filter(s => s.status === 'thinking')
      .sort((a, b) => new Date(b.lastEventAt || 0) - new Date(a.lastEventAt || 0));

    // Enrich with conductor data if linked
    const link = autoLinks.get(session.sessionId);
    let conductor = null;
    if (link) {
      const csession = conductorData.activeSessions.find(s => s.number === link.conductorNumber);
      if (csession) {
        conductor = {
          number: csession.number,
          persona: csession.persona,
          task: csession.task,
          files: csession.files,
          conductorStatus: csession.status,
          dependsOn: csession.dependsOn,
        };
      } else {
        conductor = {
          number: link.conductorNumber,
          persona: link.persona,
          task: '',
          files: '',
          conductorStatus: '',
          dependsOn: '',
        };
      }
    }

    all.push({
      ...session,
      status,
      conductorStatus,
      conductor,
      costUSD: Math.round(session.costUSD * 10000) / 10000,
      subagents: subagentList,
    });
  }

  // Active sessions (thinking/waiting/error) always shown individually.
  // Idle sessions: only show the most recent per project label.
  const active = all.filter(s => s.status !== 'idle' && s.status !== 'idle-stale');
  const idle = all.filter(s => s.status === 'idle' || s.status === 'idle-stale');
  const activeLabels = new Set(active.map(s => s.label));
  const latestIdleByLabel = new Map();
  for (const s of idle) {
    if (activeLabels.has(s.label)) continue;
    const existing = latestIdleByLabel.get(s.label);
    if (!existing || new Date(s.lastEventAt || 0) > new Date(existing.lastEventAt || 0)) {
      latestIdleByLabel.set(s.label, s);
    }
  }

  const result = [...active, ...latestIdleByLabel.values()];
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  for (const s of result) {
    if (s.status === 'idle' && (!s.lastEventAt || new Date(s.lastEventAt) < todayStart)) {
      s.status = 'idle-stale';
    }
  }
  result.sort((a, b) => {
    const aToday = a.lastEventAt && new Date(a.lastEventAt) >= todayStart ? 1 : 0;
    const bToday = b.lastEventAt && new Date(b.lastEventAt) >= todayStart ? 1 : 0;
    if (aToday !== bToday) return bToday - aToday;
    return (a.label || '').localeCompare(b.label || '');
  });
  res.json(result);
});

// --- Conductor API endpoints ---
app.get('/api/conductor', (req, res) => {
  res.json({
    projectRoot: conductorData.projectRoot,
    activeSessions: conductorData.activeSessions,
    mergeOrder: conductorData.mergeOrder,
  });
});

app.get('/api/links', (req, res) => {
  const links = [];
  for (const [sessionId, link] of autoLinks) {
    links.push({ sessionId, conductorNumber: link.conductorNumber, persona: link.persona });
  }
  res.json(links);
});

// --- Start ---
const WATCH_DIR = path.join(os.homedir(), '.claude', 'projects');
const PORT = process.env.PORT || 3001;

// Find and load SESSIONS.md
const { file: sessionsFile, root: projectRoot } = findSessionsFile(process.cwd());
conductorData.projectRoot = projectRoot;
if (sessionsFile) {
  loadSessionsFile(sessionsFile);
  console.log(`SESSIONS.md: ${sessionsFile} (${conductorData.activeSessions.length} active)`);

  // Watch for changes
  const sessionsWatcher = chokidar.watch(sessionsFile, {
    persistent: true,
    awaitWriteFinish: { stabilityThreshold: 200, pollInterval: 100 },
  });
  sessionsWatcher.on('change', () => loadSessionsFile(sessionsFile));
} else {
  console.log('SESSIONS.md: not found (conductor features disabled)');
}

// Load existing manual links
loadLinksFile(projectRoot);
if (autoLinks.size > 0) {
  console.log(`Links: ${autoLinks.size} session(s) linked`);
}

console.log(`Watching: ${WATCH_DIR}`);
console.log(`Dashboard: http://localhost:${PORT}`);

// Watch the projects directory (chokidar v5 needs directory, not glob)
const watcher = chokidar.watch(WATCH_DIR, {
  persistent: true,
  ignoreInitial: false,
  depth: 4, // reach projects/hash/session/subagents/*.jsonl
  awaitWriteFinish: { stabilityThreshold: 300, pollInterval: 100 },
});

function shouldProcessFile(filePath) {
  return filePath.endsWith('.jsonl') && !path.basename(filePath).includes('compact');
}
watcher.on('add', (filePath) => {
  if (shouldProcessFile(filePath)) processFile(filePath);
});
watcher.on('change', (filePath) => {
  if (shouldProcessFile(filePath)) processFile(filePath);
});

const server = app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} already in use. Kill the existing process or use a different port.`);
    process.exit(1);
  }
  throw err;
});
