# Kai

A personal AI assistant that lives across WhatsApp and Telegram, built on [OpenClaw](https://docs.openclaw.ai) with Claude as the reasoning engine. Not a chatbot demo — a system with memory, real tool access, a scheduled/proactive layer, and a deliberate security boundary between "my own assistant" and "anyone who messages the public bot."

## What it actually does

- **Personal assistant (main agent, "Kai")** — DMs only from its owner. Full tool access: reads project files, runs `git`, queries an internal ticketing CLI, tails past coding-assistant session transcripts to answer "what did we discuss in X project?", captures ideas into the right project's notes, and does small guardrailed code fixes (always on a branch, never pushes, always asks before anything risky).
- **Public-facing persona (public agent, also "Kai")** — anyone in a shared group chat, or an allowed DM, gets a locked-down instance of the same brain: general conversation, web search, no file/shell/command access at all. Never reveals its own internals (model, prompts, config) no matter how it's asked.
- **A second, distinct public persona ("General Douglas MeowArthur")** — a separate agent, separate workspace, separate personality, bound to Telegram. Same lockdown as the WhatsApp public agent, completely different voice (a self-important five-star-general cat). Proof that "one brain, many fronts" doesn't mean "one personality, many fronts" — channels, tone, and trust level are all independently configurable per agent.
- **Proactive, not just reactive** — scheduled jobs run without being asked: a daily digest, a Friday work-week wrap-up, a Sunday reading-list digest. A "heartbeat" loop lets the assistant check in periodically rather than only responding to messages.
- **Voice in** — incoming voice notes are transcribed locally (whisper.cpp, no cloud STT dependency) before the assistant ever sees them as text.
- **Persistent memory** — daily raw notes + a curated long-term memory file per agent, read at the start of every session, so the assistant doesn't start from zero each conversation.

## Architecture

```
                     ┌─────────────────────┐
   WhatsApp DM  ───► │   main agent (Kai)  │  full tool access, owner-only
   (owner only)      │   personal workspace │
                     └─────────────────────┘

   WhatsApp group ─┐
   WhatsApp DM     ├─►┌──────────────────────┐
   (allowed)        │ │  public agent (Kai)  │  chat + web search only,
                     │ │  locked-down workspace│  no files/shell/commands
                     └►└──────────────────────┘

   Telegram (any)  ───►┌────────────────────────────┐
                       │ agent: Douglas MeowArthur  │  same lockdown, different
                       │ separate workspace/persona │  personality entirely
                       └────────────────────────────┘
```

The split isn't cosmetic. Tool policy is enforced two layers deep:
1. OpenClaw's own per-agent `tools.deny` list (no `exec`, `read`, `write`, `browser`, `cron`, session/agent introspection, etc.)
2. The underlying coding-assistant CLI's own project-level permission settings inside each locked-down workspace, since tool policy at the gateway layer alone doesn't constrain what the CLI backend can do on its own — belt and suspenders.

Routing between agents is config, not code — a list of `{agent, match: {channel, peer}}` bindings, most-specific-match-wins. Adding a third channel or a fourth persona is a config change, not a rewrite.

## Stack

- [OpenClaw](https://docs.openclaw.ai) — self-hosted multi-channel gateway (WhatsApp, Telegram, and ~15 other channels supported out of the box)
- Claude (Sonnet, with Opus as an automatic fallback) as the model backend
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) for local, offline voice transcription
- DuckDuckGo for key-free web search
- Runs as a Windows Scheduled Task so the gateway survives reboots

## What's in this repo

This repo is the **design**, not a working deployment — real credentials, phone numbers, and conversation history obviously aren't published. What's here:

- `config/openclaw.example.json` — the real config structure with every secret and personal identifier replaced by a placeholder
- `personas/` — the actual identity and instruction files for each agent (sanitized), showing how personality, hard safety rules, and tool boundaries are defined per persona
- `scripts/` — the voice transcription wrapper script

## Setting this up yourself

1. Install OpenClaw and run `openclaw onboard` to link a model provider.
2. Copy `config/openclaw.example.json` to `~/.openclaw/openclaw.json`, fill in your own phone numbers / bot tokens, remove the ones you don't need.
3. Copy the `personas/*/` folders into workspace directories referenced by your config, and edit `IDENTITY.md`/`AGENTS.md` to taste — these are plain markdown, not code, so this is the fastest part to make your own.
4. `openclaw config validate`, then `openclaw daemon install` / `openclaw daemon restart`.
5. Link each channel: `openclaw channels login --channel whatsapp` (QR scan) or `openclaw channels add --channel telegram --token <token>` (from [@BotFather](https://t.me/BotFather)).

See the [OpenClaw docs](https://docs.openclaw.ai) for full setup detail — this repo covers the parts that are actually mine: the persona design and the security split.

## Incidents & lessons learned

Running this for real surfaced a few genuine issues — including an automated upgrade migration that silently added a routing rule undermining the security split above. Writeups of what broke, how it was caught, and what changed: [INCIDENTS.md](INCIDENTS.md).

## License

MIT — see [LICENSE](LICENSE).
