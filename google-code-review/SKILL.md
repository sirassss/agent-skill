---
name: google-code-review
description: >
  Conduct thorough code reviews following Google Engineering Practices standards.
  Use this skill whenever you're asked to review code, review a PR/CL/diff, give
  feedback on code changes, or help someone understand what makes a good code review.
  Also use it when someone asks how to write good review comments, how to handle
  reviewer feedback, or how to structure a CL/PR for review. This covers both the
  reviewer's perspective and the developer's perspective.
---

# Google Code Review Guidelines

This skill encapsulates Google's Engineering Practices for code review. Apply these
principles when reviewing code or guiding someone through the review process.

## Core Philosophy

**The primary goal:** Make the overall code health of the codebase improve over time.

**The key rule:** Approve a CL once it *definitely improves* the overall code health,
even if it isn't perfect. Don't require perfection — seek continuous improvement.

- Technical facts and data overrule opinions and personal preferences
- Style guide is the absolute authority on style matters
- Software design decisions are based on principles, not personal taste
- "Nit:" prefix = minor point, author can choose to ignore it

---

## For the Reviewer

### Step 1 — Get the big picture first

1. Read the CL description. Does this change make sense? Does it belong here?
2. If the direction is fundamentally wrong, say so immediately with courtesy — don't
   waste time reviewing code that shouldn't exist in this form.
3. Find the "main" file(s) — the one with the most logical changes — and start there.

### Step 2 — What to look for

Go through these areas in every review:

**Design**
Is the code well-designed? Does it integrate well with the rest of the system?
Is this the right time to add this functionality? Does it belong in a library instead?

**Functionality**
Does the code do what the developer intended? Think about:
- Edge cases the developer might have missed
- Concurrency issues (race conditions, deadlocks)
- UI changes — verify or ask for a demo if it's hard to assess from code alone

**Complexity**
Could it be simpler? Watch for **over-engineering** — code that's more generic
than needed, or that solves problems that don't exist yet. Encourage solving the
problem that needs solving *now*.

**Tests**
- Are tests included for the new behavior?
- Do the tests actually *fail* when the code is broken?
- Are tests well-designed? (Tests are code too — don't accept complexity in them)
- Exception: emergencies may skip tests temporarily, but must add them after

**Naming**
Did the developer choose clear names? Long enough to communicate fully, not so
long they're hard to read.

**Comments**
Comments should explain *why*, not *what*. If code needs a comment to explain what
it does, the code itself should be made simpler. Exceptions: regex, complex algorithms.

**Style**
Follow the relevant style guide. Personal preferences that aren't in the style guide
are not blocking issues. Prefix style nits with "Nit:".

**Documentation**
If the change affects how users build, test, or use the code — check that READMEs
and other docs are updated.

**Context**
Look at the whole file when needed — a 4-line change might be in a 50-line method
that now needs to be broken up.

**Code Health**
Does the CL improve or degrade the system's overall code health? Don't accept CLs
that make things worse (except true emergencies).

### Step 3 — Writing review comments

**Be kind. Comment on the code, not the developer.**

Bad: "Why did *you* use threads here when there's no benefit?"
Good: "The concurrency model here adds complexity without a visible performance
benefit. Single-threaded would be cleaner here."

**Label comment severity** so authors can prioritize:
- `Nit:` — minor polish, not mandatory
- `Optional:` / `Consider:` — a good idea but not required
- `FYI:` — informational only, no action needed in this CL
- (unlabeled) = required change

**Explain why.** Your reasoning helps the developer learn and helps future readers.

**Acknowledge good work.** If the developer did something well — say so. It's
valuable mentoring.

**If you don't understand the code:** Ask for clarification. If you can't understand
it, other developers won't either. The response should be to *rewrite the code more
clearly*, not just explain in the review tool.

### Speed expectations

- Respond within one business day of a review request arriving
- Quick response time matters more than total cycle time
- If you're in deep focus mode, finish your task first, then respond
- For large CLs: ask the developer to split it into smaller ones

### LGTM with comments

You can approve (LGTM) while leaving unresolved comments when:
- You're confident the developer will address them appropriately
- The comments aren't mandatory
- The suggestions are minor (sort imports, fix typo, etc.)

Specify which situation applies so the author knows what's required.

### Handling pushback

When a developer disagrees with your suggestion:
1. First genuinely consider if they're right — they're closer to the code
2. If you still believe the change improves code health, continue to advocate for it
3. Stay polite. Acknowledge you hear them even if you disagree
4. Don't accept "I'll fix it later" unless they'll do it *immediately after* — cleanup
   promised for later almost never happens

For persistent conflicts: escalate to broader team discussion, tech lead, or manager.
Don't let a CL sit unresolved.

---

## For the Developer (CL Author)

### Write a good CL description

The description is a permanent record — people will read it for years.

**First line:**
- Short summary of *what* is being done
- Written as an imperative sentence ("Delete X and replace with Y")
- Should stand alone — someone skimming git history should understand it

**Body:**
- *Why* is this change being made?
- What problem does it solve? Why this approach?
- Any shortcomings or tradeoffs?
- Bug numbers, benchmark results, design doc links if relevant

Bad descriptions: "Fix bug", "Add patch", "Phase 1", "Moving code from A to B"
Good description: specific, explains the what AND why.

### Keep CLs small

A CL should be **one self-contained change** — usually just one part of a feature.

Benefits of small CLs:
- Reviewed faster and more thoroughly
- Less likely to introduce bugs
- Less wasted work if direction changes
- Easier to roll back

Target: ~100 lines is reasonable. ~1000 lines is usually too large.

Strategies to split large CLs:
- Stack changes (send first CL, start second CL immediately without waiting for approval)
- Split by files if different reviewers needed
- Separate refactoring CLs from feature CLs
- Horizontal split (by layer) or vertical split (by feature)

**Always include related test code in the same CL.**

### Handling reviewer comments

- Don't take it personally — it's about the code, not you
- If reviewer doesn't understand your code: **rewrite the code to be clearer** first
- Disagree respectfully — explain your reasoning with tradeoffs, don't just say "no"
- When you understand a comment but disagree:
  > "I went with X because of [pros/cons]. Using Y would be worse because [reasons].
  > Are you suggesting Y better serves the tradeoffs, or something else?"
- Never respond in anger — walk away, come back when calm

---

## Emergencies

An emergency CL is **small** and fixes something critical:
- Major launch blocker (instead of rolling back)
- Severe production bug affecting users
- Pressing legal issue or major security hole

In emergencies: speed and correctness trump everything else.

These are **NOT** emergencies:
- "I want to ship this week instead of next"
- Developer has worked on something a long time and wants it merged
- It's Friday afternoon
- A soft deadline (manager wants it done by EOD)
- Rolling back a CL causing test failures

After an emergency is resolved: go back and give the CL a thorough review.

---

## Quick Reference Card

**Reviewer checklist:**
- [ ] Design makes sense for the system
- [ ] Functionality is correct (edge cases, concurrency)
- [ ] Not over-engineered
- [ ] Tests are included and actually useful
- [ ] Names are clear
- [ ] Comments explain *why*, not *what*
- [ ] Follows style guide
- [ ] Docs updated if needed
- [ ] Every line understood (or reviewer noted exception)
- [ ] Overall code health improves

**Comment labels:**
- `Nit:` — minor, optional
- `Optional:` / `Consider:` — good idea, not required
- `FYI:` — informational
- (unlabeled) — required change
