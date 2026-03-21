# Mobile Design Standards

## Apple HIG Requirement

All iOS UI/UX changes in this project must follow Apple's Human Interface Guidelines (HIG) as a baseline requirement.

- Source: <https://developer.apple.com/design/human-interface-guidelines/>
- Scope: New screens, redesigns, navigation patterns, controls, typography, spacing, color usage, motion, accessibility, and interaction behavior.
- Rule: If a proposed design conflicts with HIG, the implementation must be revised to align with HIG unless there is an explicit product decision documenting the exception.

## Implementation Expectations

- Prefer native iOS patterns and components before custom UI patterns.
- Use clear information hierarchy and avoid overcrowded screens.
- Use control types that match user intent (for example segmented controls for mutually exclusive options).
- Keep terminology concise and action-oriented.
- Ensure accessibility support is part of the default definition of done.

## Workflow Requirement

For each UI-related PR:

- Confirm HIG alignment in the PR description.
- Call out any intentional HIG deviations and the product rationale.
