## Grill Me

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one by one.

Input: `$ARGUMENTS` is the plan, design, or topic to grill me on. It may be a URL to an issue, path to a document, or the plan stated directly. If `$ARGUMENTS` is blank, ask what to grill me on and wait.

### Process

- Ask the questions one at a time. For each question, lead with your recommended answer with rationale.
- If a question can be answered by exploring the codebase, explore the codebase instead of asking.
- Only ask where the answer changes the implementation. Do not ask derivative questions.
- Continue until every branch of the decision tree is resolved.