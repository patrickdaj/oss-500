## ADDED Requirements

### Requirement: Every CLI a lab invokes has a documented install source
Every command-line tool a lab invokes beyond the day-one baseline (Docker, kind, kubectl, Helm, git) SHALL have a documented install source: a central tools manifest (`TOOLS.md`) listing each tool, the phase it first appears, and how to install it per OS, plus a per-lab prerequisite that names the non-baseline CLIs that lab uses and links the manifest. No lab step SHALL fail on an un-obtained, unpointed binary. Tools whose absence hard-fails a bring-up script (Terraform, `jq`) SHALL additionally appear in the top-level prerequisite lists.

#### Scenario: A central tools manifest covers every invoked CLI
- **WHEN** a lab invokes a CLI (e.g. `terraform`, `vault`, `boundary`, `opa`, `cmctl`, `trivy`, `jq`)
- **THEN** that tool appears in `TOOLS.md` with the phase it first appears and a per-OS install command, so the learner can obtain it without a search

#### Scenario: A lab names its non-baseline tools
- **WHEN** a learner opens a lab that uses tools beyond Docker/kind/kubectl/Helm/git
- **THEN** the lab's Prerequisites name those CLIs and link `TOOLS.md`, rather than assuming the binary is already present

#### Scenario: Script-critical tools are listed as prerequisites
- **WHEN** a bring-up script hard-fails without a tool (e.g. `ztna-common/tf.sh` needs `terraform`; `lab-infra/secrets/up.sh` needs `jq`)
- **THEN** that tool is listed in the top-level `README.md` / `lab-infra/README.md` prerequisites with an install link, not only inside a later note
