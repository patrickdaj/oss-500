package agentic.actions

# action-gate: classify an action as consequential (must pause for human/deterministic approval)
# vs. safe (may proceed autonomously). NIST 800-207 PEP/PDP, applied to AGENT ACTIONS.
# The agent calls this BEFORE executing; a `consequential` result triggers LangGraph interrupt().

# Consequential = it changes state, spends money, sends messages, or runs code.
consequential if { input.action.tool == "submit_change" }
consequential if { input.action.effect == "write" }
consequential if { input.action.effect == "exec" }
consequential if { input.action.effect == "network_egress" }

# Everything else (pure reads/lookups) is safe to run without approval.
requires_approval := consequential

# Reason string for the approval prompt + audit trail.
reason := sprintf("action %q (effect=%q) is consequential — approval required", [input.action.tool, input.action.effect]) if consequential
