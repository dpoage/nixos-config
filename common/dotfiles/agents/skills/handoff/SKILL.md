---
name: handoff
description: Use when work must survive an interruption — shutdown, reboot, power loss, a network or API outage, a dead or overloaded session — or when resuming after one. Covers the handoff file a multi-session lane keeps current, and the resume protocol that re-measures state and revives parked subagents before work continues. Trigger on "resume", "pick up where we left off", "we lost power", "the machine rebooted", "the session died", "write a handoff", "hand this off"; also at the first checkpoint of any lane that spans sessions (an epic, an oracle round).
---

# Handoff and Resume

Resuming a session restores its conversation. It does not restore the machine, and it
does not show whether the commands that were running at the cut finished. This skill
closes both gaps with a handoff file that the lane keeps current and a resume protocol.

Work that finishes inside one session needs no handoff file. A lane that spans sessions,
or that runs agents that outlive a turn, keeps one.

## What survives an interruption

| Interruption | Survives | Lost |
|---|---|---|
| Network or API outage | Processes, kernels, containers, files | Turns in flight abort; the agents park |
| omp crash or restart | Containers, all files on disk | Eval kernels, hub processes not started `detached`, background jobs, turns in flight |

When a session resumes, the harness restores the transcript, marks the interrupted turn
as aborted, and restores its subagents as parked. A parked agent keeps its context, and
one hub message revives it.

## The handoff file

Each lane has one handoff file at a fixed, gitignored path in the lane's checkout. The
default path is `.cache/handoff-<lane>.md`. If `git check-ignore` does not match the
path, add it to `.git/info/exclude`. Add a comment with the path to the lane's bead, so
that `bd show` finds it. A nested lane, such as a round under an epic, has its own file,
and the parent file lists that file under Agents.

The file is the lane's only entry point. Never open it with "read X first".

The file has two parts.

**Durable.** This part changes only on a ruling or a user decision.

- Goal: what the lane builds, in two sentences.
- Decisions in force, each with its date and who decided it.
- How the work runs: topology, gates, environment rules, and paths each role owns.

Link longer material, such as the plan and the briefs, by path. Do not copy it.

**Current.** Rewrite this part whole at every update. Never append to it.

1. `Updated: <ISO time> by <agent id>, session <session file>`.
2. Next action: the first thing to do after the resume protocol, in one or two
   sentences.
3. State: one row per ref, with worktree, branch, hash, dirty-file count, stash count,
   and pushed or not.
4. In flight: one row per running item, with what it is, its owner, its start time, and
   the command whose output shows whether it finished.
5. Agents: ID, role, worktree, and status.
6. Environment: numbered bring-up commands, each with the check that proves it worked.

History never goes in Current. Incidents, verdicts, and superseded state go to the
ledger or to bead comments. A dated bullet in Current is history that leaked in; move
it out.

### When to update

A power cut gives no warning, so update the file at every event that changes Current:
a commit, a merge, a dispatch, a verdict, a ruling, or an environment change. Also
update it before any wait longer than a few minutes. Write to `<file>.tmp`, then
`mv -f` it over the file, so that an interrupted write never leaves a truncated file.

## Resume protocol

The handoff file and the transcript are claims. Measure before you act.

1. Read the handoff file. If the repository has commits newer than `Updated`, the file
   is stale. Trust your measurements over the file.
2. Bring up the environment and run each check. After a network outage only, skip this
   step unless a check in step 3 fails.
3. Measure State. For each worktree, run `git rev-parse HEAD`, `git status --short | wc -l`,
   and `git stash list | wc -l`. Run `git worktree list`: a directory without `.git` is
   not a worktree. Record each difference from the file.
4. Run each In-flight command. Classify each item as finished, not started, or partial.
   Inspect a partial item before you retry it. Never repeat a step that is unsafe to
   repeat, such as a commit, a push, a merge, or a bead update, until you measure that
   it did not happen.
5. Revive each parked agent with one hub message. The message states the interruption
   time and the measured state of the agent's worktree, and says: "Re-measure your last
   step before you continue. Reply with what you measured." Never dispatch a new agent
   onto a worktree whose owner can be revived.
6. If an agent cannot be revived, or cannot continue coherently, spawn a fresh agent in
   the same role with its brief, plus: "The worktree holds prior uncommitted work.
   Measure it, keep what passes, and redo the rest."
7. Rewrite Current with what you measured. Then do the Next action.

Source: the apollo d52-r2 round recovered from a host reboot on 2026-09-28 with steps
2–5. Both revived agents continued with their context. One agent's in-progress fix had
not reached disk and was redone.
