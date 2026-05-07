# Fabrikam - Document approved exception for public storage container

Issue: #4
Type: governance
Priority: P2

---

## Summary

Fabrikam's retail platform requires anonymous read access to a single storage container hosting product imagery for the public website. This violates the default "no public containers" policy. Document the approved exception so the policy exemption is auditable.

## Scope

**In scope:**
- Capture the business justification.
- Capture the compensating controls (CDN in front, no PII, lifecycle rule).
- Get the security architect's sign-off and link it.
- Apply the policy exemption.

**Out of scope:**
- Reviewing other policy exceptions (separate work).
- Migrating off public containers (out of scope; CDN is the long-term answer and is in place).

## Deliverables

- [x] Exception record drafted ([`exception-record.md`](exception-record.md))
- [x] Security architect approval captured
- [x] Policy exemption applied at resource group scope
- [x] Audit log entry confirmed
