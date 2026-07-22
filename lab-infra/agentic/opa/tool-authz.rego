package agentic.tools

# mcp-authz: authorize EVERY MCP tool call by identity x tool x arguments.
# The agent (PEP) sends {subject, tool, args} as input; OPA (PDP) returns allow + reasons.
# Default deny — an unlisted identity/tool/argument combination is refused.

default allow := false

# The safe read tool: anyone with a valid delegated token scoped to "read" may call it.
allow if {
	input.tool == "lookup"
	"read" in input.subject.scopes
}

# The consequential write tool: only the "ops" group, and only within the caller's own tenant.
# (action-gate/action-class.rego still routes it through the approval interrupt.)
allow if {
	input.tool == "submit_change"
	"ops" in input.subject.groups
	input.args.tenant == input.subject.tenant
}

# Deny reasons surfaced to the agent + the audit log.
deny contains msg if {
	not allow
	msg := sprintf("tool %q denied for subject %q (scopes=%v groups=%v)", [input.tool, input.subject.name, input.subject.scopes, input.subject.groups])
}

# Argument guardrail: never allow a wildcard/traversal target even if the tool is permitted.
deny contains msg if {
	some k
	v := input.args[k]
	regex.match(`(\*|\.\.\/)`, sprintf("%v", [v]))
	msg := sprintf("argument %q has a disallowed pattern: %v", [k, v])
}
