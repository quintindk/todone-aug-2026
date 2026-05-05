# Fabrikam - Cost spike investigation on retail storage account

Issue: #2
Type: investigation
Priority: P1

---

## Summary

Fabrikam ops reported a 3x month-over-month increase on the retail platform's primary storage account. Investigate, identify root cause, recommend a fix.

## Scope

**In scope:**
- Pull cost analysis and metric data for the affected storage account.
- Identify the change that triggered the spike.
- Recommend remediation.

**Out of scope:**
- Implementing the recommendation (handed back to ops).
- Cost optimisation across other resources (raise as separate work).

## Findings

Root cause: lifecycle management rule for tier transition was disabled during a recent ARM template deployment that didn't include the rule. Cool/archive transitions stopped, hot tier accumulation drove the cost.

## Deliverables

- [x] Cost data pulled and timeline reconstructed
- [x] Root cause identified ([`investigation-notes.md`](investigation-notes.md))
- [x] Lifecycle rule re-applied via portal as immediate fix
- [x] Recommendation issued: re-baseline IaC to include lifecycle rule
