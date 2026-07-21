# OPA policy — the AI gateway decision point (ai-access authz, ai-governance).
# The gateway sends {user, model, tokens, ...} as `input`; OPA returns allow/deny.
# This is the OSS analog of APIM's AI gateway policies + Purview DSPM governance:
# a SINGLE central, audited policy point every AI request flows through.
# Test:  opa eval -d gateway-policy.rego -i request.json 'data.ai.gateway'
package ai.gateway

import future.keywords.contains
import future.keywords.if
import future.keywords.in

default allow := false

# --- ai-governance: allowed models ------------------------------------------
# Only sanctioned models may be used at all (blocks shadow / unapproved models).
sanctioned_models := {"llama3.2:1b", "qwen2.5:0.5b"}

# A larger model is gated to the "ml" group only (least privilege on inference).
privileged_models := {"llama3.1:8b"}

# --- ai-access: authn is a precondition -------------------------------------
authenticated if {
    input.user.authenticated == true
    input.user.name != ""
}

# --- allow rules -------------------------------------------------------------
allow if {
    authenticated
    input.model in sanctioned_models
    not over_quota
}

allow if {
    authenticated
    input.model in privileged_models
    "ml" in input.user.groups
    not over_quota
}

# --- ai-access / ai-governance: per-identity token quota ---------------------
# Denial-of-wallet / abuse control: cap tokens per identity per window.
default token_budget := 100000

over_quota if {
    input.user.tokens_used_today > token_budget
}

# --- audited denial reasons (logged centrally for governance) ----------------
deny contains msg if {
    not authenticated
    msg := "request is not authenticated"
}

deny contains msg if {
    authenticated
    not input.model in sanctioned_models
    not input.model in privileged_models
    msg := sprintf("model %q is not a sanctioned model", [input.model])
}

deny contains msg if {
    authenticated
    input.model in privileged_models
    not "ml" in input.user.groups
    msg := sprintf("model %q requires the 'ml' group; user %q lacks it", [input.model, input.user.name])
}

deny contains msg if {
    over_quota
    msg := sprintf("user %q exceeded the daily token budget (%d)", [input.user.name, token_budget])
}
