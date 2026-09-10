# Incidents & Lessons Learned

Running notes on things that actually broke, or almost broke, while operating this system — and what changed as a result. Kept honest and specific rather than generic ("we learned to be careful") because the specifics are the only useful part.

## 1. An automated version-upgrade migration silently weakened the security boundary

**What happened:** Upgrading OpenClaw two minor versions (to unlock a new voice-reply feature) required running its non-interactive config migration tool to repair several renamed/retired config keys. The migration completed cleanly and reported success — but it also silently added a new routing binding: the full-power, owner-only agent bound as a channel-wide fallback across *all* accounts on a channel, alongside the two intentional bindings (owner's DM → full-power agent, everyone else → locked-down agent).

**Why it mattered:** The whole point of the two-agent split is that a stranger in a group chat never reaches the agent with file/shell/git access. A new binding that routes unmatched traffic to the *privileged* agent, added automatically and silently during a routine upgrade, is exactly the kind of change that erodes a security boundary without anyone deciding to erode it.

**What we did:** Checked the resulting routing table immediately after the migration instead of assuming "migration succeeded" meant "nothing meaningful changed." Confirmed via the tool's own documentation that binding specificity (not array order) determines precedence, and that in this setup the new binding was very likely unreachable given the existing bindings — but "very likely unreachable" is not a security property worth relying on. Removed it outright and re-verified the routing table showed only the two intended rules.

**Lesson:** Treat every automated migration on a security-relevant config as a diff to review, not a black box to trust because it exited 0. "It probably doesn't matter" is not the same as "it's not there."

## 2. A messaging-provider migration (unrelated to us) caused a hard, silent logout

**What happened:** Migrating the bot's phone number to a business messaging tier invalidated its existing linked-device session. The gateway's own health-monitor detected this correctly (`401 Unauthorized ... conflict`) and — also correctly — stopped trying to auto-reconnect, because a session invalidated by the provider isn't a transient network blip; retrying it endlessly would just be noise. But "stopped retrying" also meant the bot went completely silent with no alert, and stayed that way for over a day before anyone noticed.

**What we did:** Diagnosed it from the gateway's own structured logs (searching for the channel's error-level lines around the time it went quiet, rather than guessing), found the exact `401 conflict` / `logged out` messages, and re-linked with a fresh QR pairing.

**Lesson:** A supervisor that correctly refuses to retry a permanently-broken connection still needs to *say so* somewhere a human will see it. Silence-on-purpose and silence-because-broken look identical from the outside unless something surfaces the distinction.

## 3. The gateway process died after a machine reboot with zero crash trace

**What happened:** After a routine reboot, the bot didn't respond. The scheduled-task service showed as installed and its last run "succeeded," but the actual process wasn't running and refused new connections. The log file showed completely normal activity — heartbeats every minute — right up until it simply stopped. No error, no shutdown message, no stack trace, nothing.

**What we did:** Confirmed the gap directly in the log timeline rather than trusting the service manager's summary status, then just restarted the service. It came back clean. It happened a second time on a later reboot.

**Lesson:** "The service says it's fine" and "the service is fine" are different claims — always cross-check against a live connectivity probe, not just the service manager's own report of itself. A silent death with no application-level trace usually means the *operating system* killed the process (a power/idle policy on the scheduled task is the leading suspect here), which is a different debugging path than an application bug — worth checking the task's power settings before assuming it's a code problem.

## 4. A near-miss: a rename almost shipped a mention-matching bug

**What happened:** While renaming the assistant, the natural next step was adding the new name as a chat-mention trigger. The obvious literal string would have matched as a *substring* inside common, everyday words in the assistant's primary working language — meaning normal conversation would have randomly, silently triggered "someone is talking to me" false positives constantly after shipping.

**What we did:** Before shipping, checked how these mention patterns actually get matched (they compile as regex, not literal-string containment) and tested the fix against real example sentences in that language before restarting the service — not after a user reported weird behavior.

**Lesson:** A short trigger string is exactly the kind of change that looks too trivial to test, which is precisely when it's worth testing — the failure mode (constant false positives in a language you didn't think to check against) is invisible until it's live in front of real users.

## Running theme

Every one of these had a system that was, in some sense, "working as designed" — a migration that completed, a health-monitor that correctly stopped retrying, a service manager reporting last-run success. The actual bugs were all in the gap between *the tool did what it was told* and *the tool did what we actually wanted*. Checking that gap — reading the real routing table, the real logs, the real regex behavior — instead of trusting the summary is the pattern that caught all four.
