# Frontend and user experience

- Use the existing design-system component before creating a custom primitive.
- Render all user-visible text through translation keys in Norwegian and
  English. Compare logic with language-independent values.
- Use locale-aware date and number formats. Interpolate thresholds and other
  behavior-driving values into translations instead of duplicating constants
  in prose. Permission messages name the unavailable action in user language.
- Use consistent domain precision within comparable numeric columns. Every
  editable control affects the submitted value, including timezone controls;
  apply size and selection constraints on initial render as well as interaction.
- Compute derived values during render. Use `useEffect` only for synchronization
  with an external system, with cleanup when applicable.
- Handle user-triggered changes in the interaction handler. Give URL/default
  selection reconciliation one owner and test direct links, refresh, deleted
  selections, and newly created records awaiting refetch.
- A remount key identifies a record or editing session, not mutable form
  contents. Test external value changes and incomplete typed input when
  changing a controlled or uncontrolled field.
- Instantiate hooks close to where their result is used. Prefer cohesive
  components over state and callback prop chains.
- Do not destructure query or form objects when the repository convention keeps
  their provenance visible.
- Disable unavailable actions and explain why. Do not hide permission-dependent
  actions as a substitute for authorization.
- Omit options that do not apply to the current feature or resource. This differs
  from an applicable action that is unavailable because permission is missing.
- Explanations for disabled controls remain reachable by keyboard and pointer.
- Destructive actions require confirmation. Require typing the resource name
  when the action affects a composite object or many records. Judge the data
  removed, not just the number of selected rows; preserve stronger existing
  confirmation for clinical data unless a product decision changes it.
- Use semantic HTML, associated labels, keyboard-operable forms, sensible focus,
  and meaningful accessible names. Interactive states remain distinguishable.
- Resize and drag controls provide keyboard and pointer access. Global shortcuts
  respect editable targets and repeated key events.
- Use stable domain identifiers as React keys. Use `useId()` for generated HTML
  identifiers.
- Use the application's route map or typed router in navigation and tests.
  Route renames include links, redirects, test setup, and diagnostic messages.
- Keep reusable components free of layout opinions. Remove wrapper elements
  without a semantic or styling purpose.
- A component owns the CSS it needs wherever it mounts, including stories.
  Use story decorators and mocks instead of adding production props solely
  for a fixture.
- Preserve all supported states and viewport access when replacing a component
  or restructuring navigation.
- Complex or rarely visited UI states receive Storybook coverage. Stories use
  fixed dates and avoid duplicate states.
- Fixtures must reach the branch the story claims to cover. Include the new
  feature's empty, populated, pending, error, and open-dialog states where
  relevant; exercise controls when static fixtures cannot show the behavior.
- Keep Storybook focused on distinct visual states. Play steps can reach those
  states; behavioral integration assertions need not be copied into each story.
- Use static Tailwind class names, the shared spacing scale, and `cn`/`clsx` for
  conditional classes. Portals protect popovers, menus, and tooltips inside
  stacking contexts.
- Use the palette defined by the app's theme. Registries resets default
  Tailwind colors; use its design tokens and component variants.
- Reusable link or trigger wrappers forward the events, attributes, and ref
  required by their consumers. Verify them inside the actual menu or dialog.

## Async state and persistence

- Retained query data belongs to the entity and input that produced it. On an
  entity switch, show retained data only when its identity matches the request;
  read loading and errors from the live result. Test a failed switch after a
  successful load, including a return to a previously visited entity.
- Keep loading, absent, failed, redacted, and zero values distinct. Show a
  useful error at the active interaction surface, including an open dialog.
- Each query contributing to a loading state has an error outcome. Preserve
  useful navigation when a secondary query fails; missing required route
  context goes to a recovery state rather than an empty ID and endless `skip`.
- Track pending operations, errors, and retries per independent entity.
  Disable the affected action and show progress without blocking unrelated rows.
- Retry clears stale failure state, prevents duplicate submission, and allows
  another attempt after failure. Exercise the transition after a previous error.
- A debounced save defines what happens to unsaved edits on navigation, deletion,
  retry, and unmount. Clear timers and prevent a late response from updating
  another record. Preview labels and numbers use the same submitted input.
- Verify what the normalized cache updates before adding or removing refetches.
  Mutation success must reach every affected visible query; avoid redundant
  refetches when the returned identity and fields already update those queries.
- Keep feature providers, subscriptions, and listeners inside their flag guard.
  For boolean feature flags, enable behavior only on explicit `true`; loading
  or an absent flag must not mount the feature. Prefer the existing
  `FeatureFlagContainer` in registries and test the guard and the entry point.
