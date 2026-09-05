# Frontend and user experience

- Use the existing design-system component before creating a custom primitive.
- Render all user-visible text through translation keys in Norwegian and
  English. Compare logic with language-independent values.
- Compute derived values during render. Use `useEffect` only for synchronization
  with an external system, with cleanup when applicable.
- Instantiate hooks close to where their result is used. Prefer cohesive
  components over state and callback prop chains.
- Do not destructure query or form objects when the repository convention keeps
  their provenance visible.
- Disable unavailable actions and explain why. Do not hide permission-dependent
  actions as a substitute for authorization.
- Destructive actions require confirmation. Require typing the resource name
  when the action affects a composite object or many records.
- Use semantic HTML, associated labels, keyboard-operable forms, sensible focus,
  and meaningful accessible names. Interactive states remain distinguishable.
- Use stable domain identifiers as React keys. Use `useId()` for generated HTML
  identifiers.
- Keep reusable components free of layout opinions. Remove wrapper elements
  without a semantic or styling purpose.
- Preserve all supported states and viewport access when replacing a component
  or restructuring navigation.
- Complex or rarely visited UI states receive Storybook coverage. Stories use
  fixed dates and avoid duplicate states.
- Use static Tailwind class names, the shared spacing scale, and `cn`/`clsx` for
  conditional classes. Portals protect popovers, menus, and tooltips inside
  stacking contexts.
