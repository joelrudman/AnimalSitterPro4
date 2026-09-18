# Privacy, legal & ethical guardrails

This system collects detailed telemetry about people's devices and their use of
files. That makes it powerful for a legitimate DLP program and dangerous if
misused. Read this before deploying.

## Intended use

DLP Sentinel is intended to run on **organization‑owned or organization‑managed
devices**, as part of a **documented, disclosed** data‑protection program, with
the **knowledge of the people using those devices**. Typical setting: a company
protecting its own confidential documents on laptops it issues to employees and
contractors.

## Not an acceptable use

- Installing on devices you do not own or administer.
- Monitoring people who have not been told monitoring may occur.
- Covert surveillance of individuals (partners, family, journalists, activists).
- Repurposing the beacon/canary features as a stalking or tracking tool.

The design deliberately avoids features that only make sense for covert abuse
(e.g. hiding the agent from the user, exfiltrating file *contents*, keystroke
capture). It records *that* a monitored file was handled and *where the host
was*, not the contents of what people write.

## Legal checklist (not legal advice)

Requirements vary widely by jurisdiction; involve counsel. Common obligations:

- **Notice & consent.** Many jurisdictions (EU/UK GDPR, various US state laws,
  works‑council rules in Germany/France, etc.) require employees be informed of
  monitoring and its scope, and sometimes require consent or worker‑council
  agreement.
- **Proportionality & data minimisation.** Collect the least telemetry needed.
  The policy system lets you dial telemetry verbosity down; default to the
  minimum that meets your detection goal.
- **Purpose limitation.** Use the data only for the stated DLP purpose; don't
  feed it into performance management or unrelated profiling.
- **Retention limits.** Set and enforce a retention window; delete old events.
- **Access control & audit.** Restrict who can see events; log admin access.
- **Cross‑border transfer.** The main server may receive telemetry from other
  countries — mind transfer rules.
- **DPIA/records.** A Data Protection Impact Assessment is often required for
  systematic monitoring.

## Telemetry: what is and isn't collected

Collected (see `packages/shared/src/telemetry.js`): hostname, OS + version,
logged‑in username, device identifiers, local/observed IP and network SSID/name,
timezone, coarse timing, the monitored file's path/name/hash and the action, and
the agent version. **Configurable** to collect less.

Never collected by design: file *contents*, keystrokes, screenshots, browsing
history beyond the monitored‑doc URL, or microphone/camera.

> Geolocation, when enabled, is derived server‑side from the observed IP (coarse,
> city‑level). The agent does not read GPS.

## Operational guardrails baked in

- The agent is **visible**: it ships with a user‑facing notice, an "about" entry,
  and does not attempt to hide its process.
- Telemetry verbosity is **policy‑controlled** and defaults to a conservative set.
- The dashboard warns that it is unauthenticated and demo‑only.
- Docs repeatedly steer toward disclosure and minimisation.

If your intended use conflicts with the "Not an acceptable use" list above, do
not deploy this software.
