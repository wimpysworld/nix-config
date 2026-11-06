# Polish

Modified adaptation of Impeccable's `polish.md`. Source and licence details are in the skill's provenance.

Polish refines an established design. Preserve its identity, content, behaviour, and everything outside the assigned scope.

## Establish the system

Read the existing tokens, shared components, neighbouring pages, and design documentation.
Distinguish a missing token, duplicated component, structural mismatch, and local implementation defect.
Fix the cause at the narrowest correct level.

## Prioritise

1. Fix blocked tasks, misleading state, and inaccessible paths.
2. Complete required loading, empty, error, success, and disabled states.
3. Correct hierarchy, responsive behaviour, and drift from the design system.
4. Refine visual and motion consistency.
5. Remove accidental churn and unused additions within the changed scope.

## Inspect the whole path

- Keep terminology, navigation, and state transitions consistent with the product.
- Check alignment, spacing, wrapping, font loading, and content extremes.
- Preserve semantic colour meanings across themes.
- Check text, controls, and focus indicators against their rendered backgrounds.
- Keep icon weight and alignment consistent without adding icons merely to fill space.
- Check image proportions, alternative text, loading, and layout shifts.
- Test the actual controls with keyboard and pointer input.
- Keep motion useful, interruptible, and compatible with reduced motion.

Repeat affected browser checks after fixes. One finished screenshot does not prove that the whole path works.
Use the main skill's delivery gate before declaring the result complete.
