# Diagnose a missing feature flag

Use this reference when a feature is missing despite an enabled flag. Establish
the runtime facts before changing application code:

1. Confirm the deployed frontend or service includes the feature's commit.
   Read the deployed version or artifact; a merge to master alone is insufficient.
2. Find the exact flag key and consuming SDK in that revision. Check whether the
   feature is gated in the browser, backend, or both, and inspect its fallback.
3. Confirm the running SDK uses the intended project and environment. Inspect
   only the relevant configuration; keep credentials out of reports.
4. For a browser flag, inspect client-side SDK availability. LaunchDarkly sends
   client-side ID SDKs only flags enabled for that access. An enabled targeting
   rule does not make an unavailable flag reach the browser. See
   [LaunchDarkly SDK types](https://launchdarkly.com/docs/sdk/concepts/client-side-server-side).
5. Inspect the actual evaluation context and targeting, including context kind,
   key, and required attributes. Compare with an equivalent working flag.
6. Check SDK initialization or fetch errors, then inspect the exact value received
   by the consuming code. Distinguish an absent flag, a false value, and a local
   fallback. An absent flag suggests delivery or SDK configuration; it does not
   alone prove which setting is wrong.

Report the first failing boundary with evidence. Inspecting a live flag does not
authorize changing its targeting or SDK availability. Apply an authorized fix,
then repeat the same runtime check and verify the feature in the browser.
