export const meta = {
  name: 'fix-pr-feedback',
  description: 'Triage review feedback in parallel, order the fixes as a DAG, apply each level concurrently',
  whenToUse: 'Driven by the fix-pr-feedback skill. Expects args from that skill, not a bare invocation.',
  phases: [
    { title: 'Collect', detail: 'fetch the review comments when the caller did not supply them' },
    { title: 'Triage', detail: 'one read-only agent per review comment' },
    { title: 'Baseline', detail: 'confirm the branch is green before touching it' },
    { title: 'Plan', detail: 'arbiter merges duplicates and adds ordering edges' },
    { title: 'Apply', detail: 'parallel edits, mutually exclusive file sets' },
    { title: 'Verify', detail: 'one type-check + test + lint pass per level' },
    { title: 'Repair', detail: 'targeted fixes for whatever the level broke' },
    { title: 'Commit', detail: 'one commit per issue, serially' },
    { title: 'Final check', detail: 'the whole suite once, after every level has landed' },
    { title: 'Push', detail: 'so the commit links in the answers resolve' },
    { title: 'Reply', detail: 'answer every automated finding on its thread' },
  ],
}

// ---------------------------------------------------------------- schemas

const COLLECT = {
  type: 'object',
  additionalProperties: false,
  required: ['items', 'excluded'],
  properties: {
    items: {
      type: 'array',
      description: 'One entry per actionable comment, in the order you read them',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['commentId', 'source', 'author', 'isBot', 'excerpt'],
        properties: {
          commentId: { type: 'string', description: 'The numeric id as a string' },
          source: { enum: ['inline', 'issue', 'review'], description: 'Which endpoint it came from — this decides how it is fetched and replied to' },
          file: { type: 'string' },
          line: { type: 'number' },
          author: { type: 'string' },
          isBot: { type: 'boolean' },
          severity: { type: 'string', description: 'From a generated finding header, if there is one' },
          category: { type: 'string' },
          reviewedSha: { type: 'string', description: 'original_commit_id — the revision the reviewer was actually looking at' },
          url: { type: 'string' },
          excerpt: { type: 'string', description: 'First ~200 characters only. Do not return whole bodies.' },
        },
      },
    },
    excluded: { type: 'number', description: 'How many comments you left out' },
    notes: { type: 'string' },
  },
}

const TRIAGE = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'rationale', 'files', 'workspaces', 'dependsOn'],
  properties: {
    verdict: {
      enum: ['fix', 'already-fixed', 'disagree', 'unclear'],
      description:
        'fix = the comment is right and you can act on it; already-fixed = the comment is right but the branch has moved past it, nothing to change; disagree = the code is correct as written; unclear = you cannot tell what is being asked',
    },
    summary: { type: 'string', description: 'One line naming what the comment is actually about' },
    rationale: { type: 'string', description: 'Why you reached that verdict, citing file:line' },
    files: {
      type: 'array',
      items: { type: 'string' },
      description:
        'Paths a fix would edit or create, including new test files, relative to the REPO ROOT — services/registries/src/x.ts, not src/x.ts, and no absolute prefix. Empty unless verdict is fix. Completeness matters: an undeclared file is one another agent may be editing at the same moment.',
    },
    workspaces: {
      type: 'array',
      items: { type: 'string' },
      description: 'Repo-relative workspace dirs owning those files, e.g. services/registries',
    },
    dependsOn: {
      type: 'array',
      items: { type: 'string' },
      description: 'Other issue ids that must be resolved before this one',
    },
    approach: { type: 'string', description: 'The minimal change, concretely. Empty unless verdict is fix.' },
    needsTest: { type: 'boolean', description: 'True when the fix changes behavior not already covered' },
    landedIn: { type: 'string', description: 'For already-fixed: the commit sha that did it, and the file:line that shows it.' },
    reply: {
      type: 'string',
      description:
        'For disagree: the rebuttal, making the positive case with file:line and the convention. For already-fixed: a short note saying where it landed. For unclear: the question for the reviewer. Empty when verdict is fix.',
    },
  },
}

const BASELINE = {
  type: 'object',
  additionalProperties: false,
  required: ['green', 'ran', 'failures'],
  properties: {
    green: { type: 'boolean' },
    ran: { type: 'array', items: { type: 'string' } },
    failures: { type: 'string', description: 'Failing excerpt if not green — errors only, not the whole log' },
  },
}

const PLAN = {
  type: 'object',
  additionalProperties: false,
  required: ['edges', 'duplicates', 'notes'],
  properties: {
    edges: {
      type: 'array',
      description: 'Ordering constraints: from must land before to',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['from', 'to', 'why'],
        properties: {
          from: { type: 'string' },
          to: { type: 'string' },
          why: { type: 'string' },
        },
      },
    },
    duplicates: {
      type: 'array',
      description: 'Groups of issue ids that are really the same fix',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['keep', 'drop', 'why'],
        properties: {
          keep: { type: 'string' },
          drop: { type: 'array', items: { type: 'string' } },
          why: { type: 'string' },
        },
      },
    },
    notes: { type: 'string' },
  },
}

const EDIT = {
  type: 'object',
  additionalProperties: false,
  required: ['ok', 'filesChanged', 'notes'],
  properties: {
    ok: { type: 'boolean', description: 'False when you could not make the change at all' },
    filesChanged: {
      type: 'array',
      items: { type: 'string' },
      description:
        'Every path you actually edited or created, relative to the REPO ROOT — including any you had to touch beyond the declared list',
    },
    outOfLane: {
      type: 'array',
      items: { type: 'string' },
      description: 'Paths you changed that were NOT in your declared file list, if any',
    },
    explanation: {
      type: 'string',
      description:
        'Two to four sentences addressed to the reviewer, which get posted verbatim under the finding: what was wrong, and what you changed. Past tense, plain prose, no headings, no bullet list, no first person, no restating the comment back. Name the symbols and files you touched. Empty only when you changed nothing.',
    },
    notes: { type: 'string', description: 'Anything the run itself needs to know — what stopped you, a judgement call, a file you left alone. Not posted.' },
  },
}

const VERIFY = {
  type: 'object',
  additionalProperties: false,
  required: ['pass', 'failures', 'ran'],
  properties: {
    pass: { type: 'boolean' },
    ran: { type: 'array', items: { type: 'string' } },
    failures: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['command', 'excerpt', 'suspectIds'],
        properties: {
          command: { type: 'string' },
          excerpt: { type: 'string', description: 'The failing portion only — not the whole log' },
          suspectIds: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
}

const ATTRIBUTE = {
  type: 'object',
  additionalProperties: false,
  required: ['attributions', 'confident'],
  properties: {
    attributions: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'why'],
        properties: { id: { type: 'string' }, why: { type: 'string' } },
      },
    },
    confident: { type: 'boolean', description: 'False if you are guessing — a wrong guess destroys good work' },
    reasoning: { type: 'string' },
  },
}

const REVERT = {
  type: 'object',
  additionalProperties: false,
  required: ['reverted', 'failed', 'statusAfter'],
  properties: {
    reverted: { type: 'array', items: { type: 'string' } },
    failed: { type: 'array', items: { type: 'string' } },
    statusAfter: { type: 'string', description: 'git status --short output' },
  },
}

const COMMIT = {
  type: 'object',
  additionalProperties: false,
  required: ['committed', 'skipped', 'statusAfter'],
  properties: {
    committed: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'sha', 'subject'],
        properties: {
          id: { type: 'string' },
          sha: { type: 'string', description: 'The full 40-character sha — it goes into a permalink' },
          subject: { type: 'string' },
        },
      },
    },
    skipped: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'why'],
        properties: { id: { type: 'string' }, why: { type: 'string' } },
      },
    },
    statusAfter: { type: 'string', description: 'git status --short output, verbatim; empty string when clean' },
  },
}

const PUSH = {
  type: 'object',
  additionalProperties: false,
  required: ['pushed'],
  properties: {
    pushed: { type: 'boolean' },
    range: { type: 'string', description: 'The ref range git reported, e.g. e9495317b..27cbdf66f' },
    error: { type: 'string', description: 'What stopped it — the hook output if a hook refused' },
  },
}

const REPLY = {
  type: 'object',
  additionalProperties: false,
  required: ['posted'],
  properties: {
    posted: { type: 'boolean' },
    alreadyPresent: { type: 'boolean', description: 'True if an equivalent reply was already on the thread and you posted nothing' },
    url: { type: 'string' },
    bodyVerified: { type: 'boolean', description: 'True if you read the posted comment back and its body was the real text, not a file path' },
    resolved: { type: 'boolean', description: 'True if the review thread was resolved after posting' },
    resolveError: { type: 'string', description: 'Why resolving failed, if it did — the reply still counts as posted' },
    error: { type: 'string' },
  },
}

// ------------------------------------------------------------------ paths

// Overlap is decided by string equality, so the spellings have to be collapsed
// first: agents are handed absolute paths by the harness and asked for
// repo-relative ones, and both turn up in practice.
function normalizePath(p, root) {
  if (typeof p !== 'string') return null
  let s = p.trim().replace(/\\/g, '/')
  if (s === '') return null
  if (root && s.startsWith(root)) s = s.slice(root.length)
  s = s.replace(/^\.\//, '').replace(/^\/+/, '').replace(/\/{2,}/g, '/').replace(/\/+$/, '')
  return s === '' ? null : s
}

// An absolute path that does not sit under the repo root is the signature of an
// agent that went to the wrong checkout — the same file path exists in the main
// clone and in every worktree. It also breaks the exclusion rule silently, since
// the two spellings no longer compare equal. Worth shouting about.
const strayPaths = []
function pathSet(paths, root) {
  const out = new Set()
  for (const p of paths || []) {
    const raw = typeof p === 'string' ? p.trim().replace(/\\/g, '/') : ''
    if (root && raw.startsWith('/') && !raw.startsWith(root)) strayPaths.push(raw)
    const n = normalizePath(p, root)
    if (n) out.add(n)
  }
  return out
}

// A Set that has been through the run journal comes back as a plain object, and
// `for ... of` on one throws while `Array.from` on one quietly yields []. The
// silent half is the dangerous one, so every read goes through here.
function asSet(value) {
  if (value instanceof Set) return value
  if (Array.isArray(value)) return new Set(value)
  return new Set()
}

function overlaps(a, b) {
  for (const x of a) if (b.has(x)) return true
  return false
}

function unique(xs) {
  return Array.from(new Set(xs))
}

// Automated review here is posted through ordinary member accounts — the same
// account that files a Claude review also leaves handwritten comments — so the
// author tells you nothing. The body does.
//
// Inline findings all open with the same header, whoever ran the review:
//
//     🟠 **Major** · `denial-of-service`
//
// Review *bodies* announce themselves in at least three different shapes on one
// PR, which is why this is a list rather than one pattern:
//
//     🤖 **Automated review by Claude Code.**
//     ## Automated review — PR #3707 … produced automatically by **Claude Code**
//     _This review was produced automatically by Claude Code._
const BOT_HEADER = /^[^\n]{0,12}\*\*(Critical|Blocker|Major|Minor|Nit)\*\*\s*[·|—–-]\s*`?([a-z0-9-]+)`?/i
//
// These match the *announcement*, not the words. "the automated review is wrong
// here" is a person talking about a bot, and posting an unattended reply to that
// is exactly the mistake worth designing against.
const BOT_MARKERS = [
  /^#{1,6}\s*automated review\b/im,
  /^[^\n]{0,20}\bautomated review by\b/im,
  /\b(?:this\s+)?(?:review|comment)\s+was\s+(?:produced|generated|written|created)\s+automatically\b/i,
  /\b(?:produced|generated|written|created)\s+automatically\s+by\b[^\n]{0,60}\bclaude\b/i,
  /^\s*🤖[^\n]{0,200}\bclaude code\b/im,
]
// Still worth keeping for genuine GitHub Apps (dependabot and friends).
const BOT_LOGIN = /\[bot\]$|^(github-actions|codecov|dependabot|renovate|copilot|coderabbitai|sonarcloud)/i

function botMeta(body) {
  const m = BOT_HEADER.exec(body || '')
  return m ? { severity: m[1], category: m[2] } : null
}

function isBotAuthor(it) {
  const body = it.body || it.excerpt || ''
  // Format beats anything the caller inferred from the account.
  if (BOT_HEADER.test(body)) return true
  for (const m of BOT_MARKERS) if (m.test(body)) return true
  if (typeof it.isBot === 'boolean') return it.isBot
  const author = (it.author || '').trim()
  return author !== '' && BOT_LOGIN.test(author)
}

// ------------------------------------------------------------------ graph

function cleanEdges(edges, ids) {
  const known = new Set(ids)
  const seen = new Set()
  const out = []
  for (const e of edges || []) {
    if (!e || !known.has(e.from) || !known.has(e.to) || e.from === e.to) continue
    const key = `${e.from}>${e.to}`
    if (seen.has(key)) continue
    seen.add(key)
    out.push(e)
  }
  return out
}

// Is there a path from id back to id, staying inside `allowed`? Used to pick a
// cycle-breaking victim that is actually in the cycle rather than merely stuck
// behind one.
function inCycle(id, out, allowed) {
  const stack = (out.get(id) || []).filter((n) => allowed.has(n))
  const seen = new Set()
  while (stack.length > 0) {
    const n = stack.pop()
    if (n === id) return true
    if (seen.has(n)) continue
    seen.add(n)
    for (const m of out.get(n) || []) if (allowed.has(m)) stack.push(m)
  }
  return false
}

// Two constraints of different kinds, deliberately kept apart:
//
//   ordering   (edges)  — A must land before B. Comes from the plan agent.
//   exclusion  (files)  — A and B may not run at the same time, in either
//                         order. Comes from a shared file.
//
// Encoding exclusion as an ordering edge — the obvious shortcut — invents a
// direction that isn't real, and that invented direction then competes with
// genuine ordering and can win. So exclusion is applied here instead, as a
// packing rule within a level: take the ready set in order and admit each
// member only if its files are still free.
function schedule(items, edges) {
  const ids = unique(items.map((i) => i.id))
  const files = new Map(items.map((i) => [i.id, asSet(i.fileSet)]))
  const indeg = new Map(ids.map((id) => [id, 0]))
  const out = new Map(ids.map((id) => [id, []]))
  for (const e of cleanEdges(edges, ids)) {
    out.get(e.from).push(e.to)
    indeg.set(e.to, indeg.get(e.to) + 1)
  }

  const levels = []
  const brokenCycles = []
  const done = new Set()
  let guard = 0

  while (done.size < ids.length && guard++ <= ids.length * 2 + 8) {
    let ready = ids.filter((id) => !done.has(id) && indeg.get(id) <= 0)

    if (ready.length === 0) {
      const remaining = ids.filter((id) => !done.has(id))
      const allowed = new Set(remaining)
      const cycle = remaining.filter((id) => inCycle(id, out, allowed))
      const victim = cycle.length > 0 ? cycle[0] : remaining[0]
      brokenCycles.push({ cycle: cycle.length > 0 ? cycle : remaining, forcedFirst: victim })
      indeg.set(victim, 0)
      ready = [victim]
    }

    const level = []
    const claimed = new Set()
    for (const id of ready) {
      const mine = files.get(id) || new Set()
      if (level.length > 0 && overlaps(mine, claimed)) continue
      level.push(id)
      for (const f of mine) claimed.add(f)
    }

    levels.push(level)
    for (const id of level) {
      done.add(id)
      for (const next of out.get(id)) indeg.set(next, indeg.get(next) - 1)
    }
  }

  // Anything the guard cut off still has to be reported rather than dropped.
  const stranded = ids.filter((id) => !done.has(id))
  return { levels, brokenCycles, stranded }
}

// A "keep" that is not itself an active fix would silently orphan everything it
// absorbed, so groups pointing at one are discarded whole; chains are followed
// to the surviving root.
function resolveDuplicates(groups, fixIds) {
  const direct = new Map()
  for (const g of groups || []) {
    if (!g || !fixIds.has(g.keep)) continue
    for (const id of g.drop || []) {
      if (id === g.keep || !fixIds.has(id) || direct.has(id)) continue
      direct.set(id, { keep: g.keep, why: g.why || '' })
    }
  }
  const resolved = new Map()
  for (const [id, info] of direct) {
    let keep = info.keep
    const seen = new Set([id])
    while (direct.has(keep) && !seen.has(keep)) {
      seen.add(keep)
      keep = direct.get(keep).keep
    }
    if (keep === id || direct.has(keep)) continue
    resolved.set(id, { keep, why: info.why })
  }
  return resolved
}

// ------------------------------------------------------------ answers
//
// Every automated finding gets an answer on its thread, whatever the outcome —
// fixed, already fixed, refuted, folded into another, or attempted and dropped.
// A reviewer reading the PR should never have to guess what happened to one.
//
// The house shape for a fix, which these reproduce:
//
//     Fixed in [`596fcddbe`](…/pull/3707/commits/596fcddbe…) — bound the analysis grid to a maximum row count.
//
//     An unbounded y or height on a stored layout made findFreeSlot scan
//     billions of rows and block the event loop. …
//
// The link text is the short sha and the href carries the full one, so the
// permalink survives a rebase of the display form but still reads short.

const SHA_IN_TEXT = /\b([0-9a-f]{7,40})\b/

function shortSha(sha) {
  return String(sha || '').trim().slice(0, 9)
}

function commitUrl(sha) {
  const full = String(sha || '').trim()
  if (!full || !ctx.repo || !ctx.prNumber) return ''
  return `https://github.com/${ctx.repo}/pull/${ctx.prNumber}/commits/${full}`
}

function commitLink(sha) {
  const url = commitUrl(sha)
  return url ? `[\`${shortSha(sha)}\`](${url})` : `\`${shortSha(sha)}\``
}

// "fix(analysis): bound the grid" and "🥅 Reject a blank name" both want to read
// as the clause after the em dash, so the conventional prefix and any leading
// emoji come off.
function commitHeadline(subject) {
  return String(subject || '')
    .replace(/^[^\p{L}\p{N}`]+/u, '')
    .replace(/^[a-z]+(\([^)]*\))?!?:\s*/i, '')
    .replace(/\s*\.\s*$/, '')
    .trim()
}

function fixedAnswer(entry) {
  const head = commitHeadline(entry.subject)
  const first = `Fixed in ${commitLink(entry.sha)}${head ? ` — ${head}` : ''}.`
  return [first, (entry.explanation || '').trim()].filter(Boolean).join('\n\n')
}

function duplicateAnswer(keeper, keeperIssue) {
  const same = keeperIssue?.url ? `the same finding as [this one](${keeperIssue.url})` : 'the same finding as another comment on this PR'
  if (!keeper) return `Covered by another fix in this pass — ${same}.`
  return [`Fixed in ${commitLink(keeper.sha)} — ${commitHeadline(keeper.subject)}.`, `This is ${same}, so one commit covers both.`, (keeper.explanation || '').trim()]
    .filter(Boolean)
    .join('\n\n')
}

// An already-fixed verdict points at a commit that predates this run, so its
// link resolves whether or not anything is pushed.
function alreadyFixedAnswer(t) {
  const m = SHA_IN_TEXT.exec(t.landedIn || '')
  const lead = m ? `Already fixed in ${commitLink(m[1])}.` : 'Already fixed on this branch.'
  const body = (t.reply || '').trim()
  // The triage text usually opens by saying the same thing; don't say it twice.
  if (body && /^(already|this is already|agreed, and this)/i.test(body)) return m ? `${lead}\n\n${body}` : body
  return [lead, body].filter(Boolean).join('\n\n')
}

function blockedAnswer(why) {
  const detail = String(why || '').replace(/\s+/g, ' ').trim().slice(0, 400)
  return `Not fixed in this pass.${detail ? ` ${detail}` : ''}`
}

function unclearAnswer(t) {
  return [`Not actioned — this finding is not specific enough to act on as written.`, (t.reply || '').trim()].filter(Boolean).join('\n\n')
}

function reviewFilename() {
  const slug = ctx.prNumber ? `pr-${ctx.prNumber}` : (ctx.branch || 'review').replace(/[^a-z0-9]+/gi, '-').toLowerCase()
  return `${slug}-human-feedback.md`
}

// The one artefact the human reviewer works from: their comments, the commit
// that answers each, and a draft they can send. Built here rather than by an
// agent so the drafts arrive exactly as they were written.
function humanReviewMarkdown(entries) {
  if (entries.length === 0) return ''
  const reviewers = unique(entries.map((e) => e.author).filter(Boolean))
  const title = ctx.prNumber ? `PR #${ctx.prNumber} — human review feedback` : 'Human review feedback'
  const out = [
    `# ${title}`,
    '',
    [
      ctx.branch ? `Branch \`${ctx.branch}\`` : null,
      `${entries.length} item${entries.length === 1 ? '' : 's'}`,
      reviewers.length > 0 ? `from ${reviewers.map((r) => `@${r}`).join(', ')}` : null,
    ]
      .filter(Boolean)
      .join(' · '),
    '',
    'None of this has been posted. Each item links to its thread and, where there',
    'is one, to the commit that answers it. The draft is a starting point — send it,',
    'rewrite it, or ignore it.',
    '',
    '| # | Where | Outcome | Commit |',
    '| --- | --- | --- | --- |',
  ]
  for (const e of entries) {
    const where = e.file ? `\`${e.file.split('/').pop()}${e.line ? `:${e.line}` : ''}\`` : '—'
    out.push(`| [${e.id}](#${e.id}) | ${where} | ${e.outcome} | ${e.sha ? commitLink(e.sha) : '—'} |`)
  }
  out.push('')
  for (const e of entries) {
    out.push(
      '---',
      '',
      `<a id="${e.id}"></a>`,
      '',
      `## ${e.id} — ${e.summary}`,
      '',
      `- **Comment:** ${e.url || '(no url)'}`,
      `- **Reviewer:** ${e.author ? `@${e.author}` : '(unknown)'}`,
      `- **Location:** ${e.file ? `\`${e.file}${e.line ? `:${e.line}` : ''}\`` : '(not inline)'}`,
      `- **Outcome:** ${e.outcome}`,
      `- **Commit:** ${e.sha ? `${commitLink(e.sha)}${e.subject ? ` — ${commitHeadline(e.subject)}` : ''}` : 'none — nothing was committed for this item'}`,
      '',
    )
    if (e.excerpt) {
      out.push('> ' + e.excerpt.replace(/\s+/g, ' ').trim().slice(0, 300) + (e.excerpt.length > 300 ? ' …' : ''), '')
    }
    out.push('### Draft reply', '', '````text', (e.draft || '(nothing drafted — this one needs an answer written from scratch)').trim(), '````', '')
  }
  return out.join('\n')
}

// -------------------------------------------------------------- prompts

// Every prompt opens with this. Subagents inherit the *session's* working
// directory, not the workflow's, and on a monorepo with worktrees that is
// routinely a different checkout of the same project — the file the comment
// names exists there too, at the same path, holding different code. On the run
// this was written from, a third of the agents read or grepped the wrong tree
// before working out where they were supposed to be.
function where(ctx) {
  return `## Where to work

Everything you do happens in:

    ${ctx.cwd}

\`cd\` there first, and use paths under it. **Your shell does not start there.**
Other checkouts and worktrees of this same repository exist on this machine and
carry the same relative paths with different content, so a bare \`git\`,
\`grep .\` or \`Read services/...\` will silently answer from the wrong one.
${ctx.branch ? `\nThe branch checked out there is \`${ctx.branch}\`. If \`git branch --show-current\` says anything else, you are in the wrong place — stop and say so rather than working on what you found.\n` : ''}
When you report file paths, report them relative to that directory.
`
}

const CONVENTIONS = `
Before judging anything, read the repo-root CLAUDE.local.md (or CLAUDE.md) and
the files it links that bear on this code. Those are the conventions the fix has
to follow, and they are frequently the reason a piece of feedback is wrong.`

function fetchCommand(it, ctx) {
  if (!it.commentId || !ctx.repo) return null
  if (it.source === 'issue') return `gh api repos/${ctx.repo}/issues/comments/${it.commentId} --jq .body`
  if (it.source === 'review') return `gh api repos/${ctx.repo}/pulls/${ctx.prNumber}/reviews/${it.commentId} --jq .body`
  return `gh api repos/${ctx.repo}/pulls/comments/${it.commentId} --jq .body`
}

function issueBlock(it, ctx) {
  const cmd = it.truncated ? fetchCommand(it, ctx) : null
  return [
    `id: ${it.id}`,
    it.author ? `author: ${it.author}${it.bot ? ' (bot)' : ''}` : null,
    it.file ? `location: ${it.file}${it.line ? `:${it.line}` : ''}` : null,
    it.url ? `url: ${it.url}` : null,
    '',
    it.body,
    cmd
      ? `\n**That is an excerpt, not the whole comment.** Read the rest before you do anything else:\n\n    ${cmd}\n`
      : null,
  ]
    .filter(Boolean)
    .join('\n')
}

function collectPrompt(ctx, select) {
  return `${where(ctx)}
Gather the review feedback on one pull request so it can be triaged.

Repo: ${ctx.repo}
PR: ${ctx.prNumber}

Read all three kinds of comment:

    gh api --paginate repos/${ctx.repo}/pulls/${ctx.prNumber}/comments
    gh api --paginate repos/${ctx.repo}/issues/${ctx.prNumber}/comments
    gh api --paginate repos/${ctx.repo}/pulls/${ctx.prNumber}/reviews

${
  select.include.length > 0
    ? `Take **exactly** these comment ids and nothing else:\n\n${select.include.join(', ')}\n`
    : `Take every comment except:\n${select.exclude.length > 0 ? `- these ids: ${select.exclude.join(', ')}\n` : ''}- anything written by the authenticated user (\`gh api user --jq .login\`) — those are the author's own replies${select.excludeSeverities.length > 0 ? `\n- generated findings graded ${select.excludeSeverities.join(' or ')}` : ''}`
}

For each one return metadata only — **an excerpt of about 200 characters, never
the whole body.** The triage agent fetches the full text itself; a large payload
here is what makes this stage fail.

Fields that matter:

- \`source\` — \`inline\` for a \`pulls/.../comments\` entry, \`issue\` for an
  \`issues/.../comments\` entry, \`review\` for a review body. This decides both
  how the body is fetched later and where a reply goes.
- \`reviewedSha\` — \`original_commit_id\`. This is the revision the reviewer was
  actually looking at, and it is how a stale review gets spotted later. Do not
  omit it.
- \`isBot\` — **not** from the author. Automated review here is posted through
  ordinary member accounts, and the same account leaves handwritten comments
  too. Set it true when the body opens with a generated finding header (a
  severity in bold — Critical, Blocker, Major, Minor, Nit — then \`·\` then a
  backticked category), or when the body says it was produced automatically by
  Claude Code, or when the login is a real GitHub App. Everything else is human.
- \`severity\` / \`category\` — from that header, when there is one.

Preserve the order you read them in: inline comments first, then issue comments,
then review bodies. Change nothing in the repo.`
}

// Automated and human review fail in opposite directions, so the scepticism has
// to point in opposite directions too.
function reviewerContext(it) {
  if (it.bot) {
    return `
## Who wrote it

An automated reviewer, posting through a team member's account${it.author ? ` (${it.author})` : ''} — so treat
this as machine output regardless of whose name is on it.
${it.severity ? `\nIt graded this **${it.severity}**${it.category ? ` under \`${it.category}\`` : ''}. That is the machine's own estimate, not a fact. A Nit that\nturns out to be wrong costs nothing to dismiss; a Major deserves a careful look\nbefore you either accept or reject it.\n` : ''}
Automated review is good at catching real mechanical defects, and also produces
confident false positives: a rule applied without the surrounding context, a
style preference stated as an error, a "this can throw" that every caller
already rules out. Check the claim against the actual code rather than assuming
it holds.

Nobody is waiting on the other end, so there is no cost to saying plainly that a
comment is wrong — and no point asking it a question, because nothing will
answer. If you cannot tell what it means, treat that as a reason to dismiss it,
not to ask.`
  }
  return `
## Who wrote it

A person on the team${it.author ? ` (${it.author})` : ''}. They may be working
from things the code does not show — a past incident, a migration in flight, a
constraint from another team, a review conversation you cannot see. If the
comment looks wrong, weigh first whether it rests on context you lack rather than
on a misreading.

When you do disagree, the rebuttal is read by a colleague: make the positive case
for the code, don't score a point. If you genuinely cannot tell what is being
asked, asking is the right move — they can answer.`
}

// A review left on an older revision is the cheapest verdict on the list and the
// most expensive to get wrong by reading the code fresh. On the run this was
// written from, 23 of 73 items were one stale batch, each of which cost a full
// read-the-function-and-its-callers pass to conclude "already done".
function stalenessContext(it) {
  if (!it.reviewedSha) return ''
  return `
## The revision it was written against

This comment was left on \`${it.reviewedSha}\`, which is not the tip. Before
reading anything else, find out whether the branch has already moved past it:

    git log --oneline ${it.reviewedSha}..HEAD -- ${it.file || '.'}
    git diff ${it.reviewedSha}..HEAD -- ${it.file || '.'}

If the change the comment asks for is already in that diff, the verdict is
**already-fixed** — name the commit in \`landedIn\` and keep \`reply\` to a
sentence or two saying where it landed. Do not argue the point; it was a fair
comment when it was written.

If the file has not changed, or has changed in some unrelated way, carry on and
judge the comment on its merits.`
}

function triagePrompt(it, all, ordered, ctx) {
  return `${where(ctx)}
You are triaging ONE piece of code review feedback on a pull request.

## The comment

${issueBlock(it, ctx)}
${reviewerContext(it)}
${stalenessContext(it)}

## Every other item on this list (for dependency detection only — do not act on them)

${all
  .filter((o) => o.id !== it.id)
  .map((o) => `- ${o.id}: ${(o.body || '').slice(0, 200).replace(/\s+/g, ' ')}`)
  .join('\n') || '(none)'}
${ordered ? '\nThis list was supplied in a deliberate order, so a later item may assume an earlier one has already landed. Reflect that in dependsOn.' : ''}
${CONVENTIONS}

## What to do

Read the code around the comment properly — the whole function, its callers, and
its tests. If the comment references something you cannot place, search the repo
for it.

Then decide whether the feedback is actually right. Be critical; do not accept it
because a reviewer wrote it. Feedback frequently rests on a misreading of the
code, conflicts with a project convention, or describes something already handled
elsewhere. Equally, do not reach for disagreement — if it is right, say so.

- **fix** — act on it. Give the minimal change in \`approach\`, concretely enough
  that another engineer could apply it without re-deriving your analysis. List in
  \`files\` every path that change would touch, including new test files, as
  paths **from the repo root** — \`services/registries/src/x.ts\`, not
  \`src/x.ts\`, and no absolute prefix.

  \`files\` matters beyond your own issue: two fixes sharing a path are never run
  at the same time, which is the only thing stopping two agents from editing one
  file simultaneously. Under-declare and they collide. Over-declare and you only
  cost some parallelism — so when in doubt, include the path.
- **already-fixed** — the comment was right, and the branch already does what it
  asks. Say which commit did it in \`landedIn\`, with the file:line that shows it.
  \`reply\` is a short factual note, not an argument.
- **disagree** — the code is correct as written. Put the rebuttal in \`reply\`:
  make the positive case, cite file:line and the convention, explain what the code
  is doing and why that shape is right. Do not merely assert it was intentional.
  Write it to be read by the reviewer; it is posted close to verbatim.
- **unclear** — you genuinely cannot tell what is being asked. Put the question
  for the reviewer in \`reply\`. Use this sparingly.

**Change no files.** This is analysis only — another agent applies your approach.`
}

function baselinePrompt(workspaces, ctx, hasIntegrationTests) {
  return `${where(ctx)}
Establish whether this branch is already green, before any fix is applied.

This matters because verification failures later on get attributed to whichever
fix seems responsible. Breakage that was already here would be blamed on an
innocent fix and could get that fix thrown away — so it has to be ruled out now.

Workspaces about to be touched: ${workspaces.join(', ') || '(none identified — infer from the repo layout)'}

In each, run \`npm run build-ts\` and \`npx biome check\`. One workspace at a time;
concurrent builds in one workspace fight over the same output. Skip the test
suites — too slow for a pre-flight, and type/lint state is what attribution
usually turns on.
${
  hasIntegrationTests
    ? `
Some of the fixes touch integration tests, which verification will run, and those
need a database. Confirm one is reachable — the workspace's \`.env.test.local\`
names it, and \`docker ps\` shows whether this worktree's stack is up. **A missing
database is a red baseline.** Report it as such: the alternative is that the first
verification pass fails for environmental reasons and blames a fix for it.
`
    : ''
}
Report honestly. Do not fix anything, and do not soften a failure: a red baseline
is useful information, not a problem to be tidied away before anyone sees it.`
}

function planPrompt(triaged, ctx) {
  return `${where(ctx)}
You are sequencing the fixes for one pull request's review feedback.

Each fix below was analysed independently, so nobody has yet seen the whole
picture. That is your job.

${triaged
  .map(
    (t) =>
      `### ${t.id} — ${t.summary}\nfiles: ${Array.from(asSet(t.fileSet)).join(', ') || '(none)'}\napproach: ${t.approach || '(none)'}\nself-declared deps: ${(t.dependsOn || []).join(', ') || '(none)'}`,
  )
  .join('\n\n')}

Two things to return.

**edges** — real ordering constraints: \`from\` must land before \`to\`.

Note what this is *not* for. Two fixes touching the same file are already
prevented from running simultaneously — that is handled separately, and it does
not imply either order. Do not add an edge merely because two fixes share a file.

What you are looking for is dependency: applying these two in the wrong order
would break the build or produce a wrong result. A signature change before its
call sites. A helper before its consumer. A rename before its importers. If two
fixes share a file *and* one genuinely depends on the other, do add the edge —
that direction is real and it will be honoured.

Be sparing. Every edge removes parallelism, and a wrong edge silently runs the
work in the wrong order.

**duplicates** — groups where two reviewers said the same thing, or one comment
is wholly contained in another. \`keep\` must be one of the ids listed above;
naming anything else discards the whole group and both fixes then run.

If a file list above reads \`(none)\` for an item with a real approach, say so in
\`notes\` rather than working around it — it means the data reaching you is wrong,
and a graph built on it would be worthless.`
}

function editPrompt(it, ctx) {
  const declared = Array.from(asSet(it.fileSet))
  return `${where(ctx)}
Apply ONE agreed fix from a pull request review.

## The comment

${issueBlock(it.issue, ctx)}

## The agreed analysis

${it.summary}

${it.rationale}

**Approach:** ${it.approach}
**Declared files:** ${declared.join(', ') || '(none declared)'}
**Needs a test:** ${it.needsTest ? 'yes' : 'no'}
${CONVENTIONS}

## Rules

Make the minimal change that addresses the comment, following the project's
conventions. Do not bundle unrelated cleanup — this becomes one commit.

${
  it.needsTest
    ? 'Add a test covering the scenario the fix changes. A test that would have passed before your change is not a test of your change.'
    : 'No test is expected here; existing coverage or the cosmetic nature of the change covers it. Add one only if that judgement turns out to be wrong, and say so in notes.'
}

**Other agents are editing other files in this same working tree right now.** The
declared list above was chosen so that no two of you share a path. If the fix
turns out to need a file outside that list, you have two options, and picking the
wrong one corrupts someone else's work:

- The file is clearly unrelated to any other review comment (a local helper, a
  new test file): change it, and list it in \`outOfLane\` as well as
  \`filesChanged\`.
- The file is plausibly something another fix also touches: **do not change it.**
  Stop, leave it alone, and say so in \`notes\`.

Report every path you actually touched in \`filesChanged\`, including ones from
the declared list you ended up not needing to change (omit those). This list —
not the declared one — is what gets verified and staged.

## The explanation

\`explanation\` is **posted to the review thread verbatim**, under a line naming
the commit, so write it for the reviewer rather than for the run. Two to four
sentences: what was actually wrong, then what you changed. Past tense, plain
prose, no headings or bullets, no "I", and don't restate the comment back at
them — they wrote it. Name the symbols and files. If the change has a
consequence worth flagging, or you deliberately left part of the comment
unaddressed, say so in a final sentence.

The shape it lands in:

    Fixed in \`abc1234\` — bound the analysis grid to a maximum row count.

    An unbounded y or height on a stored layout made findFreeSlot scan billions
    of rows and block the event loop. The layout validator now rejects anything
    past the grid maximum, and the scan stops there too.

You only get this one shot at it — nothing downstream re-reads your diff to
write a better one.

**Run no build, no test command, and no git command.** Verification and
committing happen once for the whole batch after every agent in it has finished;
a \`tsc\` or \`vitest\` started here races the others over the same build output,
and a \`git\` command here would stage another agent's half-written file.`
}

function verifyPrompt(items, workspaces, round, ctx) {
  return `${where(ctx)}
Verify a batch of review fixes that were just applied to the working tree.

${round > 0 ? `This is re-verification after repair round ${round}.\n` : ''}
## What changed

${items.map((it) => `- ${it.id}: ${it.summary}\n  files: ${Array.from(asSet(it.effective)).join(', ')}`).join('\n')}

## What to run

Workspaces touched: ${workspaces.join(', ') || '(determine from the paths above)'}

For each one, from inside that workspace:
- \`npm run build-ts\`
- \`npx vitest run <the touched and added test files>\` — those files, not the whole suite
- \`npx biome check\` over the changed paths, if the project has it

One workspace at a time. Do not parallelise them; concurrent builds in one
workspace fight over the same output.

Do not fix anything you find. Report it.

For each failure give the failing excerpt — the error lines, not the whole log —
and set \`suspectIds\` to the issues responsible.

Attribution deserves real thought, because it decides which fix gets repaired.
The file named in an error is often not the file that caused it: a type error
usually surfaces in the *consumer* of a changed signature, and a test failure
names the *test*, not the code under test. So trace it — look at what the error
is actually complaining about and which of the changes above could produce it,
rather than pattern-matching the path.

If after that you still cannot attribute a failure, leave \`suspectIds\` empty and
say so in the excerpt. That is a real answer and it is handled; a guess is not.`
}

function attributePrompt(items, failures, ctx) {
  return `${where(ctx)}
Verification failed and the verifying agent could not say which change caused
it. Work it out, because the alternative is that nobody can.

## Changes in this batch

${items.map((it) => `- ${it.id}: ${it.summary}\n  files: ${Array.from(asSet(it.effective)).join(', ')}\n  ${it.approach || ''}`).join('\n\n')}

## The failures

${failures.map((f) => `### ${f.command}\n${f.excerpt}`).join('\n\n')}

Use the evidence rather than the file names. \`git diff\` shows what actually
changed; read the failing code and the symbol the error names, and follow it back
to whichever diff introduced it. Type errors surface downstream of the change;
test failures name the test, not the cause.

Consider seriously that the answer may be **none of them** — a flaky test, a
database that is not running, or breakage that predates this run. If that is what
the evidence says, return an empty list with \`confident: true\`.

Set \`confident: false\` if you are guessing. A confident wrong answer causes
working code to be deleted; an admitted uncertainty causes the batch to be left
alone for a human. The second is much cheaper.`
}

function repairPrompt(it, failures, ctx) {
  return `${where(ctx)}
A fix you are responsible for broke verification. Repair it.

## Your issue

${it.id} — ${it.summary}
files: ${Array.from(asSet(it.effective)).join(', ')}

## The failures pointing at it

${failures.map((f) => `### ${f.command}\n${f.excerpt}`).join('\n\n')}

Fix the underlying problem. Do not weaken a test, loosen a type, or add a
suppression to make the error go away — if the honest fix is out of reach, leave
the code as it is and say so in \`notes\`. The issue is then reverted and reported
as blocked, which is a better outcome than a green run that hid a real problem.

Stay within your own files; other agents own the rest of this tree. Report
everything you touched in \`filesChanged\`. Run no build, no test, and no git
command — verification re-runs for the whole batch after you.`
}

function revertPrompt(casualties, protectedPaths, ctx) {
  return `${where(ctx)}
These fixes could not be made to pass verification and must come out of the
working tree so the rest of the batch can be committed.

${casualties.map((c) => `- ${c.id}: ${Array.from(asSet(c.revertable)).join(', ') || '(no exclusively-owned paths)'}`).join('\n')}

For each path listed: if it is tracked, \`git checkout -- <path>\`; if the fix
created it, delete it.

**Touch nothing else.** In particular these paths belong to fixes that passed and
must survive intact:

${protectedPaths.length > 0 ? protectedPaths.map((p) => `- ${p}`).join('\n') : '(none)'}

If a path you were asked to revert also appears in that protected list, skip it
and report it in \`failed\` — a shared path cannot be unpicked safely here, and a
human needs to see it.

Then run \`git status --short\` and report it verbatim in \`statusAfter\`.`
}

function commitPrompt(items, ctx) {
  return `${where(ctx)}
Commit a verified batch of review fixes — one commit per issue.

Verification has passed for the batch as a whole, so the work is sound. What
matters here is that each commit contains exactly its own issue's files.

${items.map((it) => `### ${it.id} — ${it.summary}\nfiles: ${Array.from(asSet(it.effective)).join(', ')}\n${it.approach || ''}`).join('\n\n')}

In the order listed, for each issue:
1. \`git add\` only that issue's files. Never \`git add -A\`, never \`git add .\` —
   the tree holds other issues' changes right now and they belong in other
   commits.
2. Commit with a focused Conventional Commit message describing that fix alone.
3. Let the pre-commit hook run. Never \`--no-verify\`. If it fails, fix the
   underlying problem and retry that commit; if you cannot, record the issue in
   \`skipped\` with the reason, \`git reset\` its files to unstage them — leave the
   changes in the working tree, do not discard them — and carry on to the next.

Do not push.
${
  ctx.preexisting.length > 0
    ? `\nThese paths were already dirty before this run started and are none of your business — do not stage them, do not clean them up, do not mention them as a problem:\n\n${ctx.preexisting.map((p) => `- ${p}`).join('\n')}\n`
    : ''
}
Afterwards run \`git status --short\` and report it verbatim in \`statusAfter\`.
Leftovers are expected when something was skipped; report them rather than
tidying them away.

${ctx.baseSha ? `Base of this run: ${ctx.baseSha}` : ''}`
}

function finalCheckPrompt(workspaces, ctx) {
  return `${where(ctx)}
Every fix in this run has been committed. Run the project's full gate once, so
whoever pushes knows whether the branch is actually green.

Workspaces touched: ${workspaces.join(', ') || '(determine from the repo layout)'}

In each, one at a time:
- \`npm run build-ts\`
- \`npx vitest run\` — **the whole suite**, not a file list
- \`npx biome check\`

Verification during the run only ever ran the tests each level touched, so this
is the first chance an untouched test has had to fail. That is the point of this
pass; it is not a formality.

Fix nothing. Report what failed, with the failing excerpt rather than the whole
log, and set \`green\` honestly.`
}

function pushPrompt(ctx) {
  return `${where(ctx)}
Push the branch. Every fix in this run is committed and the full suite has been
run; this is the last step before the review threads are answered, and those
answers link to the commits — so the commits have to exist on the remote first
or every link 404s.

    git push

If there is no upstream, \`git push -u origin ${ctx.branch || '<branch>'}\`.

Never \`--force\`, never \`--force-with-lease\`, never \`--no-verify\`. Let the
pre-push hook run. If it refuses, report its output verbatim in \`error\` and set
\`pushed: false\` — do not fix anything and do not retry more than once, because
whatever it caught needs a person to look at it.

Report the ref range git prints (e.g. \`e9495317b..27cbdf66f\`) in \`range\`.`
}

function replyPrompt(it, ctx) {
  const kind = it.kind || 'a reply'
  const source = it.issue.source || (it.issue.commentId && it.issue.file ? 'inline' : 'issue')
  const [owner, name] = String(ctx.repo || '').split('/')
  return `${where(ctx)}
Post ${kind} on one pull request review thread. Post the text verbatim — it is
already written and reviewed; you are the delivery step, not an editor.

Repo: ${ctx.repo}
PR: ${ctx.prNumber}
Comment kind: ${source}
Thread comment id: ${it.issue.commentId || '(none)'}
Url: ${it.issue.url || '(none)'}

Body to post:
---
${it.reply}
---

**First check whether it is already there.** This run may be a retry of one that
already posted. Read the existing replies on the thread
(\`gh api repos/${ctx.repo}/pulls/${ctx.prNumber}/comments\` for inline threads,
\`gh pr view ${ctx.prNumber} --comments\` for top-level) and look for an
equivalent comment from the authenticated user (\`gh api user --jq .login\`). If
one is there, post nothing and return \`alreadyPresent: true\`${source === 'inline' ? ' — but still\nresolve the thread as below, because the earlier run may have died before it got\nthere' : ''}. Duplicate
rebuttals on a colleague's review read badly.

One exception: a previous reply whose whole body is a file path, a bare \`@\`, or
empty is a *failed* post, not an existing one. Delete it
(\`gh api -X DELETE repos/${ctx.repo}/pulls/comments/<id>\`) and post properly.

Otherwise, **write the body to a file first** with the Write tool — say
\`reply-${it.id}.md\` in your scratchpad directory — and pass that file to \`gh\`.
The body is Markdown full of backticks, newlines and \`$\`; putting it on a
command line hands it to the shell to mangle.

${
  source === 'inline'
    ? `This is an inline review comment, so reply in its thread:

    gh api repos/${ctx.repo}/pulls/${ctx.prNumber}/comments/${it.issue.commentId}/replies -F body=@<path to that file>

\`-F\` is not a typo for \`-f\` and the two are not interchangeable here. Only
\`-F\` (\`--field\`) reads a value from a file or stdin when it starts with \`@\`.
\`-f\` (\`--raw-field\`) is a *raw string* parameter: it posts the literal text
\`@/tmp/whatever.md\` as the comment. That has happened on a real PR — twice in
one run — and it is silent, because the request succeeds.`
    : `This is a ${source === 'review' ? 'review body' : 'top-level'} comment with no inline thread, so use

    gh pr comment ${ctx.prNumber} --body-file <path to that file>

and open by quoting the point you are answering, so it is clear which comment
you mean.`
}

**Then read the posted comment back** and confirm the body is the real text:

    gh api repos/${ctx.repo}/pulls/comments/<new comment id> --jq '.body[0:80]'

If it comes back as a path, an \`@\`, or empty, the flag was wrong. Delete that
comment (\`gh api -X DELETE repos/${ctx.repo}/pulls/comments/<id>\`) and post it
again properly. Do not leave a broken reply on the thread.
${
  source === 'inline'
    ? `
**Then resolve the thread.** This is an automated reviewer's finding and it now
has its answer, so it should not stay open — that is this repo's convention for
AI-reviewer threads (threads a person started are never resolved, and none of
those reach you). Resolving needs the thread's node id, which is not the comment
id, so look it up first:

    gh api graphql -f query='
      { repository(owner: "${owner || '<owner>'}", name: "${name || '<name>'}") {
          pullRequest(number: ${ctx.prNumber}) {
            reviewThreads(first: 100) {
              nodes { id isResolved comments(first: 100) { nodes { databaseId } } } } } } }' \\
      --jq '.data.repository.pullRequest.reviewThreads.nodes[]
            | select(any(.comments.nodes[]; .databaseId == ${it.issue.commentId}))
            | .id'

Then, with the \`PRRT_…\` id that returns:

    gh api graphql -f query='mutation($id: ID!) {
      resolveReviewThread(input: { threadId: $id }) { thread { isResolved } } }' -f id=<PRRT_…>

Set \`resolved\` from what the mutation reports. If it fails, report the error in
\`resolveError\` and still return \`posted: true\` — a posted answer on an
unresolved thread is a much smaller problem than no answer, and it is not worth
retrying more than once.
`
    : ''
}
Report whether it posted and the resulting url. Do not edit or close the thread.`
}

// ------------------------------------------------------------------ run

// The Workflow tool takes `args` as a JSON value, and callers hand it a JSON
// *string* often enough that it is not worth being principled about. Getting
// this wrong is silent and expensive: every field reads as undefined, so the
// agents lose their working directory and the reply stage decides there is no PR.
function parseArgs(value) {
  if (typeof value === 'string') {
    try {
      return JSON.parse(value)
    } catch {
      return { __parseError: value.slice(0, 200) }
    }
  }
  return value && typeof value === 'object' ? value : {}
}

const input = parseArgs(args)
const root = input.cwd ? String(input.cwd).replace(/\/+$/, '') + '/' : ''

const ctx = {
  repo: input.repo || '',
  prNumber: input.prNumber || '',
  baseSha: input.baseSha || '',
  branch: input.branch || '',
  cwd: input.cwd || '',
  preexisting: [],
}

const emptyResult = {
  fixed: [],
  alreadyFixed: [],
  disagreed: [],
  unclear: [],
  blocked: [],
  duplicates: [],
  untriaged: [],
  heldReplies: [],
  humanReview: null,
  replies: [],
  pushed: null,
  items: [],
  schedule: { levels: [], brokenCycles: [], stranded: [], planNotes: '' },
  baseline: null,
  finalCheck: null,
  halted: null,
  treeDirty: [],
  strayPaths: [],
  postingBlocked: null,
}

// `cwd` is not a nicety. Without it the agents fall back to whatever directory
// the session happens to be in — on this monorepo, routinely the main checkout
// rather than the worktree holding the branch — and the path normalization that
// keeps two fixes off one file stops working at the same time. Refuse rather
// than run 130 agents in an unknown tree.
if (!ctx.cwd) {
  return {
    ...emptyResult,
    error: input.__parseError
      ? `args could not be parsed as JSON: ${input.__parseError}`
      : 'cwd is required — pass the absolute path of the checkout or worktree holding the branch',
  }
}

// Paths that were already dirty before the run. Without them the commit agent
// reports an unclean tree at every single level over some untracked scratch
// directory, and the one output that means "this repo is not finished" becomes
// noise.
const preexistingRaw = Array.isArray(input.preexisting)
  ? input.preexisting
  : String(input.preexisting || '').split('\n')
const preexisting = new Set()
for (const line of preexistingRaw) {
  const trimmed = String(line || '').trim()
  if (trimmed === '') continue
  const rest = trimmed.replace(/^\S+\s+/, '')
  const parts = rest.split(' -> ')
  const p = normalizePath(parts[parts.length - 1], root)
  if (p) preexisting.add(p)
}
ctx.preexisting = Array.from(preexisting)

function statusLeftovers(statusAfter) {
  return String(statusAfter || '')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .filter((l) => {
      const rest = l.replace(/^\S+\s+/, '')
      const parts = rest.split(' -> ')
      const p = normalizePath(parts[parts.length - 1], root)
      if (!p) return true
      // A pre-existing untracked directory covers everything under it.
      for (const known of preexisting) if (p === known || p.startsWith(`${known}/`)) return false
      return true
    })
}

// Two ways in. A caller with a pasted list (or a small PR) hands over `issues`
// directly. A caller pointing at a large PR hands over the PR and a selection,
// and the fetching happens here — 73 comment bodies is 85 KB, which is not
// something the calling agent can retype into a tool call without reading all of
// it into its own context first.
let rawIssues = Array.isArray(input.issues) ? input.issues : []

if (rawIssues.length === 0) {
  if (!ctx.repo || !ctx.prNumber) {
    return { ...emptyResult, error: 'no issues supplied, and no repo/prNumber to collect them from' }
  }
  const select = {
    include: (input.includeCommentIds || []).map(String),
    exclude: (input.excludeCommentIds || []).map(String),
    excludeSeverities: input.excludeSeverities || [],
  }
  log(`collecting review comments on ${ctx.repo}#${ctx.prNumber}`)
  const collected = await agent(collectPrompt(ctx, select), {
    label: 'collect comments',
    phase: 'Collect',
    schema: COLLECT,
    model: 'opus',
  })
  if (!collected || (collected.items || []).length === 0) {
    return { ...emptyResult, error: 'the collect agent found no comments to work on' }
  }
  rawIssues = collected.items.map((c) => ({ ...c, body: c.excerpt, truncated: true }))
  log(`collected ${rawIssues.length} item(s)${collected.excluded ? `, ${collected.excluded} excluded` : ''}`)
}

// Ids come from here, not from the triage agents, so a duplicated or
// hallucinated id cannot detach a fix from the issue it belongs to.
const issues = []
const seenIds = new Set()
for (let i = 0; i < rawIssues.length; i++) {
  const it = rawIssues[i] || {}
  let id = typeof it.id === 'string' && it.id.trim() !== '' ? it.id.trim() : `c${i + 1}`
  if (seenIds.has(id)) id = `${id}#${i + 1}`
  seenIds.add(id)
  const meta = botMeta(it.body || it.excerpt)
  issues.push({
    ...it,
    id,
    body: it.body || it.excerpt || '',
    source: it.source || (it.file ? 'inline' : 'issue'),
    truncated: Boolean(it.truncated),
    bot: isBotAuthor(it),
    severity: it.severity || meta?.severity || '',
    category: it.category || meta?.category || '',
    // A comment left on the tip has nothing to diff against.
    reviewedSha: it.reviewedSha && it.reviewedSha !== ctx.baseSha ? it.reviewedSha : '',
  })
}

if (issues.length === 0) {
  return { ...emptyResult, error: 'no issues supplied' }
}

const items = issues.map((it) => ({
  id: it.id,
  commentId: it.commentId || null,
  source: it.source,
  author: it.author || '',
  bot: it.bot,
  file: it.file || '',
  line: it.line || null,
  url: it.url || '',
  excerpt: (it.body || '').slice(0, 200),
}))

log(`${issues.length} item(s) of feedback — triaging in parallel`)

const triagedRaw = await parallel(
  issues.map((it) => () =>
    agent(triagePrompt(it, issues, Boolean(input.orderedList), ctx), {
      label: `triage:${it.id}`,
      phase: 'Triage',
      schema: TRIAGE,
      model: 'opus',
    }).then((t) => (t ? { ...t, id: it.id, issue: it } : null)),
  ),
)

const triaged = triagedRaw.filter(Boolean)

// Sets are built here rather than inside the thunk above. A `parallel()` result
// round-trips through the run journal, and that turns a Set into a plain object:
// `for ... of` then throws, and `Array.from` quietly returns [] — which on one
// run meant the plan agent saw an empty file list for all 73 items and built its
// graph blind. Arrays survive, so `files` is what gets rebuilt from.
for (const t of triaged) t.fileSet = pathSet(t.files, root)

if (strayPaths.length > 0) {
  log(`WARNING ${strayPaths.length} declared path(s) sit outside ${ctx.cwd} — e.g. ${strayPaths[0]}. An agent is in the wrong checkout and the same-file exclusion rule cannot see it.`)
}

const lost = issues.filter((it) => !triaged.some((t) => t.id === it.id))
if (lost.length > 0) log(`triage produced nothing for: ${lost.map((l) => l.id).join(', ')}`)

const toFix = triaged.filter((t) => t.verdict === 'fix')
const countOf = (v) => triaged.filter((t) => t.verdict === v).length

log(
  `${toFix.length} to fix, ${countOf('already-fixed')} already fixed on the branch, ${countOf('disagree')} disagreed, ${countOf('unclear')} unclear`,
)

const canPost = Boolean(ctx.repo && ctx.prNumber)

// Every item gets an answer written for it, whatever happened to it. Which of
// them go out is the only thing that differs, and it turns on one question:
// **is there a person on the other end?**
//
// Automated findings all get answered on the thread, unattended — fixed, refuted,
// folded in, or attempted and dropped. Nobody is kept waiting and a reviewer
// reading the PR should never have to guess what became of one.
//
// Anything aimed at a person is never posted. It goes into the markdown file
// instead, next to the commit that answers it, for them to send themselves.
function answerFor(t, outcomes) {
  const o = outcomes.get(t.id)
  if (t.verdict === 'fix') {
    if (o && o.kind === 'fixed') {
      return { text: fixedAnswer(o), kind: 'a note that this is fixed', outcome: 'fixed', sha: o.sha, subject: o.subject, needsPush: true }
    }
    if (o && o.kind === 'duplicate') {
      const keeper = outcomes.get(o.coveredBy)
      const landed = keeper && keeper.kind === 'fixed' ? keeper : null
      return {
        text: duplicateAnswer(landed, issues.find((i) => i.id === o.coveredBy)),
        kind: 'a note that another commit covers this',
        outcome: `folded into ${o.coveredBy}`,
        sha: landed ? landed.sha : '',
        subject: landed ? landed.subject : '',
        needsPush: Boolean(landed),
      }
    }
    return { text: blockedAnswer(o && o.why), kind: 'a note that this was not fixed', outcome: 'not fixed', sha: '', subject: '', needsPush: false }
  }
  if (t.verdict === 'already-fixed') {
    const m = SHA_IN_TEXT.exec(t.landedIn || '')
    return { text: alreadyFixedAnswer(t), kind: 'a note that this already landed', outcome: 'already fixed on the branch', sha: m ? m[1] : '', subject: '', needsPush: false }
  }
  if (t.verdict === 'disagree') {
    return { text: (t.reply || '').trim(), kind: 'a rebuttal', outcome: 'refuted', sha: '', subject: '', needsPush: false }
  }
  return {
    text: t.issue.bot ? unclearAnswer(t) : (t.reply || '').trim(),
    kind: 'a clarifying question',
    outcome: 'unclear',
    sha: '',
    subject: '',
    needsPush: false,
  }
}

function postingPolicy(t, a, pushed) {
  if (!canPost) return { post: false, why: 'no PR in scope — draft only' }
  if (!t.issue.bot) return { post: false, why: 'aimed at a person — yours to send' }
  if (!t.issue.commentId) return { post: false, why: 'no comment id, so it cannot be threaded' }
  if (!a.text) return { post: false, why: 'nothing was drafted for it' }
  if (a.needsPush && !pushed) return { post: false, why: 'the branch was not pushed, so the commit link would not resolve' }
  return { post: true }
}

// Answers are built here rather than up front because a reply to a fixed finding
// names the commit that fixed it, and that sha does not exist until the level
// loop has run. Posting waits for the same reason — and because the run's
// concurrency cap is around ten, so thirty reply agents launched alongside the
// first level of edits would starve the work that matters.
function planAnswers(outcomes, pushed) {
  const post = []
  const heldReplies = []
  const humanEntries = []
  for (const t of triaged) {
    const a = answerFor(t, outcomes)
    const policy = postingPolicy(t, a, pushed)
    const common = {
      id: t.id,
      kind: a.kind,
      outcome: a.outcome,
      author: t.issue.author || '',
      bot: Boolean(t.issue.bot),
      url: t.issue.url || '',
      sha: a.sha,
      subject: a.subject,
      text: a.text,
    }
    if (policy.post) {
      post.push({ ...t, reply: a.text, kind: a.kind })
      continue
    }
    heldReplies.push({ ...common, why: policy.why })
    if (!t.issue.bot) {
      humanEntries.push({
        ...common,
        summary: t.summary,
        file: t.issue.file || '',
        line: t.issue.line || null,
        excerpt: (t.issue.body || '').slice(0, 400),
        draft: a.text,
      })
    }
  }
  return { post, heldReplies, humanEntries }
}

async function runReplies(post) {
  if (post.length === 0) return []
  log(`answering ${post.length} automated finding${post.length === 1 ? '' : 's'} on their threads`)
  const out = await parallel(
    post.map((t) => () =>
      agent(replyPrompt(t, ctx), {
        label: `reply:${t.id}`,
        phase: 'Reply',
        schema: REPLY,
        model: 'haiku',
      }).then((r) => (r ? { ...r, id: t.id } : { id: t.id, posted: false, error: 'the reply agent returned nothing' })),
    ),
  )
  return out.filter(Boolean)
}

if (!canPost) log('no repo/prNumber in args — nothing can be posted, everything comes back as a draft')

const allWorkspaces = unique(toFix.flatMap((t) => (t.workspaces || []).map((w) => normalizePath(w, root)).filter(Boolean)))
const touchesIntegrationTests = toFix.some((t) => Array.from(asSet(t.fileSet)).some((f) => /integration\.test\.[jt]sx?$/.test(f)))

// Baseline and planning are independent; run them together.
const [baseline, planResult] = await parallel([
  () =>
    toFix.length > 0
      ? agent(baselinePrompt(allWorkspaces, ctx, touchesIntegrationTests), {
          label: 'baseline',
          phase: 'Baseline',
          schema: BASELINE,
          model: 'opus',
        })
      : null,
  () =>
    toFix.length > 1
      ? agent(planPrompt(toFix, ctx), {
          label: 'sequence fixes',
          phase: 'Plan',
          schema: PLAN,
          model: 'opus',
          effort: 'high',
        })
      : null,
])

function answered(replies) {
  const replyFor = (id) => replies.find((r) => r.id === id) || null
  return {
    alreadyFixed: triaged
      .filter((t) => t.verdict === 'already-fixed')
      .map((t) => ({ id: t.id, summary: t.summary, bot: Boolean(t.issue.bot), landedIn: t.landedIn || '', draft: t.reply, reply: replyFor(t.id) })),
    disagreed: triaged
      .filter((t) => t.verdict === 'disagree')
      .map((t) => ({ id: t.id, summary: t.summary, bot: Boolean(t.issue.bot), reason: t.rationale, draft: t.reply, reply: replyFor(t.id) })),
    unclear: triaged
      .filter((t) => t.verdict === 'unclear')
      .map((t) => ({ id: t.id, summary: t.summary, bot: Boolean(t.issue.bot), question: t.reply, reply: replyFor(t.id) })),
  }
}

if (baseline && baseline.green === false) {
  log('baseline is already red — stopping before any fix is applied')
  const outcomes = new Map(toFix.map((t) => [t.id, { kind: 'blocked', why: 'not attempted — the branch was already red before any change' }]))
  const plan = planAnswers(outcomes, false)
  const replies = await runReplies(plan.post)
  const markdown = humanReviewMarkdown(plan.humanEntries)
  return {
    ...emptyResult,
    ...answered(replies),
    items,
    untriaged: lost.map((l) => ({ id: l.id, body: (l.body || '').slice(0, 200) })),
    heldReplies: plan.heldReplies,
    humanReview: markdown ? { filename: reviewFilename(), markdown, count: plan.humanEntries.length } : null,
    replies,
    baseline,
    strayPaths: unique(strayPaths),
    postingBlocked: canPost ? null : 'repo and prNumber were not both supplied, so nothing was posted',
    halted: {
      at: 'baseline',
      why: 'the branch does not build or lint before any change was made — fixing on top of it would misattribute every failure',
      detail: baseline.failures || '',
    },
    blocked: toFix.map((t) => ({ id: t.id, summary: t.summary, why: 'not attempted — baseline was already red' })),
  }
}

const plan = planResult || { edges: [], duplicates: [], notes: '' }
const fixIds = new Set(toFix.map((t) => t.id))
const dupMap = resolveDuplicates(plan.duplicates, fixIds)
const dropped = Array.from(dupMap, ([id, info]) => ({ id, coveredBy: info.keep, why: info.why }))

const active = toFix.filter((t) => !dupMap.has(t.id))
const byId = new Map(active.map((t) => [t.id, t]))

const { levels, brokenCycles, stranded } = schedule(active, plan.edges)

for (const c of brokenCycles) {
  log(`circular dependency among ${c.cycle.join(', ')} — running ${c.forcedFirst} first`)
}
if (stranded.length > 0) log(`could not schedule: ${stranded.join(', ')}`)
if (active.length > 0) {
  log(
    `${active.length} fix(es) in ${levels.length} level(s): ${levels.map((l) => l.length).join(' → ')} in parallel${dropped.length > 0 ? `, ${dropped.length} duplicate(s) folded in` : ''}`,
  )
}

const committed = []
const blocked = []
const treeDirty = []
let halted = null

for (const id of stranded) {
  const it = byId.get(id)
  blocked.push({ id, summary: it ? it.summary : id, why: 'could not be placed in the dependency graph' })
}

for (let li = 0; li < levels.length; li++) {
  if (halted) {
    for (const id of levels[li]) {
      const it = byId.get(id)
      blocked.push({ id, summary: it ? it.summary : id, why: `not attempted — the run stopped at level ${halted.level}` })
    }
    continue
  }

  const batch = levels[li].map((id) => byId.get(id)).filter(Boolean)
  const tag = `level ${li + 1}/${levels.length}`
  log(`${tag}: applying ${batch.map((b) => b.id).join(', ')}`)

  const edits = await parallel(
    batch.map((it) => () =>
      agent(editPrompt(it, ctx), {
        label: `fix:${it.id}`,
        phase: 'Apply',
        schema: EDIT,
        model: 'opus',
      }),
    ),
  )

  const applied = []
  for (let i = 0; i < batch.length; i++) {
    const it = batch[i]
    const e = edits[i]
    if (!e || e.ok === false) {
      blocked.push({ id: it.id, summary: it.summary, why: e ? e.notes : 'the edit agent returned nothing' })
      continue
    }
    // What was actually touched governs verification, staging and reverting —
    // the declared list is only a prediction, and a file it missed would
    // otherwise go untested and unstaged.
    const changed = pathSet(e.filesChanged, root)
    it.effective = changed.size > 0 ? changed : new Set(asSet(it.fileSet))
    it.outOfLane = pathSet(e.outOfLane, root)
    it.editNotes = e.notes || ''
    // Written by the agent that made the change, while it still has the whole
    // picture. It is what gets posted under the finding.
    it.explanation = (e.explanation || '').trim()
    applied.push(it)
  }

  if (applied.length === 0) {
    log(`${tag}: nothing applied cleanly, moving on`)
    continue
  }

  // Two agents in one level reaching the same file means an out-of-lane edit
  // slipped past the exclusion rule. Worth saying out loud; it makes any
  // later attribution suspect.
  for (let i = 0; i < applied.length; i++) {
    for (let j = i + 1; j < applied.length; j++) {
      if (overlaps(applied[i].effective, applied[j].effective)) {
        log(`${tag}: WARNING ${applied[i].id} and ${applied[j].id} both touched a shared file`)
      }
    }
  }

  const workspaces = unique(applied.flatMap((it) => (it.workspaces || []).map((w) => normalizePath(w, root)).filter(Boolean)))
  let verdict = await agent(verifyPrompt(applied, workspaces, 0, ctx), {
    label: `verify:L${li + 1}`,
    phase: 'Verify',
    schema: VERIFY,
    model: 'opus',
  })

  const inBatch = (id) => applied.some((it) => it.id === id)
  const suspectsOf = (v) => unique((v?.failures || []).flatMap((f) => f.suspectIds || [])).filter(inBatch)

  let round = 0
  let unattributable = false

  while (verdict && !verdict.pass && round < 2) {
    let suspects = suspectsOf(verdict)

    if (suspects.length === 0) {
      const guess = await agent(attributePrompt(applied, verdict.failures || [], ctx), {
        label: `attribute:L${li + 1}`,
        phase: 'Verify',
        schema: ATTRIBUTE,
        model: 'opus',
        effort: 'high',
      })
      if (guess && guess.confident && (guess.attributions || []).length === 0) {
        log(`${tag}: failure attributed to nothing in this batch (flaky or pre-existing)`)
        unattributable = true
        break
      }
      if (!guess || !guess.confident) {
        log(`${tag}: cannot attribute the failure — leaving the batch for a human`)
        unattributable = true
        break
      }
      suspects = unique(guess.attributions.map((a) => a.id)).filter(inBatch)
      if (suspects.length === 0) {
        unattributable = true
        break
      }
      log(`${tag}: attributed to ${suspects.join(', ')} on a second look`)
    }

    round++
    log(`${tag}: repair round ${round} on ${suspects.join(', ')}`)
    const repairs = await parallel(
      suspects.map((id) => () => {
        const it = byId.get(id)
        const mine = (verdict.failures || []).filter((f) => (f.suspectIds || []).includes(id))
        return agent(repairPrompt(it, mine.length > 0 ? mine : verdict.failures || [], ctx), {
          label: `repair:${id}`,
          phase: 'Repair',
          schema: EDIT,
          model: 'opus',
        }).then((r) => ({ id, r }))
      }),
    )
    for (const entry of repairs.filter(Boolean)) {
      const it = byId.get(entry.id)
      if (!it) continue
      const changed = pathSet(entry.r?.filesChanged, root)
      if (changed.size > 0) for (const f of changed) it.effective.add(f)
      // The repair is part of what landed, so the reviewer-facing text has to
      // account for it rather than describing only the first attempt.
      const extra = (entry.r?.explanation || '').trim()
      if (extra && extra !== it.explanation) it.explanation = [it.explanation, extra].filter(Boolean).join('\n\n')
    }

    verdict = await agent(verifyPrompt(applied, workspaces, round, ctx), {
      label: `verify:L${li + 1}r${round}`,
      phase: 'Verify',
      schema: VERIFY,
      model: 'opus',
    })
  }

  let committable = applied

  if (!verdict || !verdict.pass) {
    const suspects = suspectsOf(verdict)

    // Nothing gets thrown away on a hunch. Without a specific, attributed
    // culprit the tree is left exactly as it is, the batch goes uncommitted,
    // and the run stops — later levels would be building on unverified state.
    if (unattributable || suspects.length === 0) {
      log(`${tag}: stopping — verification failed with no attributable cause, work left in the tree`)
      for (const it of applied) {
        blocked.push({
          id: it.id,
          summary: it.summary,
          why: 'verification failed with no attributable cause; the change is still in the working tree, uncommitted',
        })
        treeDirty.push({ id: it.id, files: Array.from(asSet(it.effective)) })
      }
      halted = {
        at: `level ${li + 1}`,
        level: li + 1,
        why: 'verification failed and no specific fix could be blamed, so nothing was reverted and nothing was committed',
        detail: (verdict?.failures || []).map((f) => `${f.command}: ${f.excerpt}`).join('\n') || 'no detail reported',
      }
      continue
    }

    const casualties = suspects.map((id) => byId.get(id)).filter(Boolean)
    const survivors = applied.filter((it) => !casualties.includes(it))
    const survivorPaths = new Set(survivors.flatMap((s) => Array.from(asSet(s.effective))))

    // Revert only what the casualty exclusively owns. A path a survivor also
    // touched is left alone and reported — unpicking it would take the
    // survivor's work with it.
    for (const c of casualties) {
      c.revertable = new Set(Array.from(asSet(c.effective)).filter((p) => !survivorPaths.has(p)))
      const shared = Array.from(asSet(c.effective)).filter((p) => survivorPaths.has(p))
      if (shared.length > 0) treeDirty.push({ id: c.id, files: shared, why: 'shared with a fix that passed; not reverted' })
    }

    log(`${tag}: reverting ${casualties.map((c) => c.id).join(', ')} — could not get it green`)
    const reverted = await agent(revertPrompt(casualties, Array.from(survivorPaths), ctx), {
      label: `revert:L${li + 1}`,
      phase: 'Repair',
      schema: REVERT,
      model: 'opus',
    })

    for (const c of casualties) {
      const why = (verdict?.failures || [])
        .filter((f) => (f.suspectIds || []).includes(c.id))
        .map((f) => `${f.command}: ${f.excerpt}`)
        .join(' | ')
      blocked.push({
        id: c.id,
        summary: c.summary,
        why: why || 'verification failed',
        revertFailed: reverted ? (reverted.failed || []).length > 0 : true,
      })
    }
    if (!reverted) log(`${tag}: the revert agent returned nothing — tree state is unknown`)

    committable = survivors

    // The revert itself can break a survivor that depended on what was undone,
    // so the batch has to be re-checked before anything is committed.
    if (committable.length > 0) {
      const recheck = await agent(verifyPrompt(committable, workspaces, round + 1, ctx), {
        label: `verify:L${li + 1}post-revert`,
        phase: 'Verify',
        schema: VERIFY,
        model: 'opus',
      })
      if (!recheck || !recheck.pass) {
        log(`${tag}: still red after reverting — stopping, nothing committed from this level`)
        for (const it of committable) {
          blocked.push({
            id: it.id,
            summary: it.summary,
            why: 'still failing after the reverts; the change is in the working tree, uncommitted',
          })
          treeDirty.push({ id: it.id, files: Array.from(asSet(it.effective)) })
        }
        halted = {
          at: `level ${li + 1}`,
          level: li + 1,
          why: 'reverting the failing fixes did not restore a green build',
          detail: (recheck?.failures || []).map((f) => `${f.command}: ${f.excerpt}`).join('\n') || 'no detail reported',
        }
        continue
      }
    }
  }

  if (committable.length === 0) {
    log(`${tag}: nothing survived verification`)
    continue
  }

  const result = await agent(commitPrompt(committable, ctx), {
    label: `commit:L${li + 1}`,
    phase: 'Commit',
    schema: COMMIT,
    model: 'opus',
  })

  if (!result) {
    for (const it of committable) {
      blocked.push({
        id: it.id,
        summary: it.summary,
        why: 'verified, but the commit agent returned nothing — the change may still be uncommitted in the working tree',
      })
      treeDirty.push({ id: it.id, files: Array.from(asSet(it.effective)) })
    }
    continue
  }

  for (const c of result.committed || []) {
    const it = byId.get(c.id)
    committed.push({
      id: c.id,
      summary: it ? it.summary : c.subject,
      sha: c.sha,
      subject: c.subject,
      explanation: it ? it.explanation || '' : '',
      url: commitUrl(c.sha),
    })
  }
  for (const s of result.skipped || []) {
    const it = byId.get(s.id)
    blocked.push({ id: s.id, summary: it ? it.summary : s.id, why: s.why })
  }
  const accounted = new Set([...(result.committed || []).map((c) => c.id), ...(result.skipped || []).map((s) => s.id)])
  for (const it of committable) {
    if (!accounted.has(it.id)) {
      blocked.push({ id: it.id, summary: it.summary, why: 'the commit agent did not report on this issue either way' })
    }
  }
  const leftovers = statusLeftovers(result.statusAfter)
  if (leftovers.length > 0) {
    treeDirty.push({ id: `level ${li + 1}`, files: [], status: leftovers.join('\n') })
    log(`${tag}: working tree not clean after committing — ${leftovers.length} path(s) beyond what was already dirty`)
  }
}

// Per-level verification only ever ran the tests that level touched, so nothing
// so far has given an untouched test the chance to fail. This is the check the
// push decision should actually rest on.
let finalCheck = null
if (committed.length > 0 && !halted) {
  const touched = unique(
    committed
      .map((c) => byId.get(c.id))
      .filter(Boolean)
      .flatMap((it) => (it.workspaces || []).map((w) => normalizePath(w, root)).filter(Boolean)),
  )
  log(`${committed.length} commit(s) landed — running the full suite once before you push`)
  finalCheck = await agent(finalCheckPrompt(touched.length > 0 ? touched : allWorkspaces, ctx), {
    label: 'final check',
    phase: 'Final check',
    schema: BASELINE,
    model: 'opus',
  })
  if (finalCheck && finalCheck.green === false) log('the full suite is RED on the branch tip — do not push')
}

// The push belongs here rather than to the caller, because every answer posted
// below links to a commit from this run and an unpushed sha 404s. Whatever is
// not pushed cannot be answered, and is held instead.
let pushed = null
if (committed.length === 0) {
  pushed = { pushed: false, skipped: 'nothing was committed' }
} else if (halted) {
  pushed = { pushed: false, skipped: 'the run stopped partway — push is yours to decide' }
} else if (finalCheck && finalCheck.green === false) {
  pushed = { pushed: false, skipped: 'the full suite is red on the branch tip' }
} else if (input.push === false) {
  pushed = { pushed: false, skipped: 'push was turned off in the args' }
} else {
  pushed = await agent(pushPrompt(ctx), { label: 'push', phase: 'Push', schema: PUSH, model: 'haiku' })
  if (!pushed) pushed = { pushed: false, error: 'the push agent returned nothing' }
  log(pushed.pushed ? `pushed ${pushed.range || ctx.branch}` : `push did not happen: ${pushed.error || pushed.skipped || 'unknown'}`)
}

// Everything that happened to each item, keyed by id, so an answer can name the
// commit that carries it.
const outcomes = new Map()
for (const c of committed) outcomes.set(c.id, { kind: 'fixed', sha: c.sha, subject: c.subject, explanation: c.explanation })
for (const d of dropped) if (!outcomes.has(d.id)) outcomes.set(d.id, { kind: 'duplicate', coveredBy: d.coveredBy })
for (const b of blocked) if (!outcomes.has(b.id)) outcomes.set(b.id, { kind: 'blocked', why: b.why })

const answers = planAnswers(outcomes, pushed.pushed === true)
const replies = await runReplies(answers.post)
const markdown = humanReviewMarkdown(answers.humanEntries)
if (answers.humanEntries.length > 0) log(`${answers.humanEntries.length} item(s) from people — drafted into ${reviewFilename()} for you, not posted`)

return {
  fixed: committed,
  ...answered(replies),
  blocked,
  duplicates: dropped,
  untriaged: lost.map((l) => ({ id: l.id, body: (l.body || '').slice(0, 200) })),
  heldReplies: answers.heldReplies,
  humanReview: markdown ? { filename: reviewFilename(), markdown, count: answers.humanEntries.length } : null,
  replies,
  pushed,
  items,
  treeDirty,
  halted,
  baseline,
  finalCheck,
  strayPaths: unique(strayPaths),
  postingBlocked: canPost ? null : 'repo and prNumber were not both supplied, so nothing was posted',
  schedule: {
    levels: levels.map((l) => l.slice()),
    brokenCycles,
    stranded,
    planNotes: plan.notes || '',
  },
}
