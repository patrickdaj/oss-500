# agent-deleg — enable OAuth 2.0 Token Exchange (RFC 8693) on the d1 realm

The agent must **never** hold a long-lived credential. Instead it exchanges the user's access token
for a **scoped, short-lived on-behalf-of token** (RFC 8693) each time it acts. This reuses the
Keycloak `oss500` realm from `lab-infra/identity` — no new IdP.

## Steps (directions)

1. **Enable the feature.** Keycloak ships token exchange as a preview feature. Start Keycloak with
   `--features=token-exchange` (already set in `lab-infra/identity` if you enabled it there; otherwise
   add it and restart). This is the "preview feature" caveat called out in `d6-identity.md`.

2. **Create the agent client** (`agent-runtime`) in the `oss500` realm: confidential, service-accounts
   on, standard flow off. This client is the *token-exchange actor* — it presents its own secret to
   perform the exchange, but the resulting token's authority is bounded by the user's token + requested scope.

3. **Scope it down.** Define client scopes `read` and `ops:write` and map them to the `mcp-tools`
   audience. Grant `agent-runtime` permission to exchange *to* `mcp-tools` for `read` by default;
   `ops:write` only for members of the `ops` group. This is what makes an over-broad exchange fail.

4. **Short lifetimes.** Set the exchanged access-token lifespan low (e.g. 5 min) so a stolen agent
   token expires fast — the "short-lived, auto-rotated, no stored secret" property.

## Prove it (labs/d6-identity.md)

- A token exchanged for `read` **cannot** call `submit_change` (audience/scope mismatch → refused at the resource).
- An **expired** exchanged token is refused (401) — demonstrating the time bound.
- The agent's *workload* identity (SPIRE SVID, see `../spire/registration.md`) is distinct from this
  *delegated* token: one says who the process is, the other says what it may do for which user.

Secrets: the `agent-runtime` client secret is gitignored; never commit it or log an exchanged token.
