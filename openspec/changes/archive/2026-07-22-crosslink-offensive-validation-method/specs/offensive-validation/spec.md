## ADDED Requirements

### Requirement: The purple-team method is defined once and cross-linked wherever applied

The purple-team four-step method (Build the control → Name the technique → Fire it locally → Confirm the defense holds) SHALL have a single canonical definition in `domains/5-offensive-validation/purple-team.md`. Any other note that applies the method — including flavored restatements in the Domain 5 track notes and the beyond-blueprint `domains/6-agentic-zero-trust/d6-validate.md` — SHALL cross-link that canonical note rather than presenting the method as a standalone re-teach, so each restatement reads as reinforcement of one authoritative source.

#### Scenario: A validation note applying the method cross-links the canonical definition

- **WHEN** a note outside `purple-team.md` restates the four-step method to apply it to a surface (for example `d6-validate.md` in its "four steps, agent flavor" section)
- **THEN** that note contains a link back to `purple-team.md` as the canonical method, and its own restatement retains only its surface-specific flavor rather than teaching the four steps as if newly introduced

#### Scenario: The canonical method has exactly one authoritative definition

- **WHEN** a reader looks for the authoritative statement of the Build → Name → Fire → Confirm method (the diagram and the "document the gap" loop)
- **THEN** it is found in `purple-team.md` alone, and every other occurrence is a flavored restatement that references it rather than a competing canonical definition
