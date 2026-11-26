# /prodev

Pro-dev orchestration status and control for this repository.

Run these, in this order, and act on the output:

1. `prodev status` — resolved vault, task counts and live worker leases.
2. `prodev context` — the rehydration pack: brief, knowledge map, active plans,
   open issues and recent orchestrator log.
3. `prodev doctor` — checks the repo pointer, vault, `gh` auth and tools.

Rules that apply whenever this command is used:

- The vault is the memory. Write plans, decisions and logs to it, never only to
  the conversation.
- Every change gets a GitHub issue first (`prodev issue new`), and the issue is
  closed with a summary of what changed and how it was verified.
- At most two workers run at once, on disjoint file sets.
