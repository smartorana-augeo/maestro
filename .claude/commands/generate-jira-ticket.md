# Create Jira Ticket

Create a detailed Jira ticket draft with all necessary information.

## Usage
When invoked, you'll be prompted for ticket details.

## Instructions

Create a comprehensive Jira ticket that includes all necessary information for development.

### Required Information to Gather
1. **Summary**: Clear, concise title
2. **Description**: Detailed explanation of the requirement
3. **Acceptance Criteria**: Specific, testable criteria
4. **Technical Notes**: Implementation hints or constraints
5. **Dependencies**: Related tickets or systems
6. **Priority**: How urgent is this?
7. **Labels/Tags**: For categorization

### Ticket Structure

#### Summary
One-line description that clearly states what needs to be done.

#### Description
**Background**: Why is this needed?

**User Story** (if applicable):
As a [user type]
I want to [action]
So that [benefit]

**Requirements**:
- Detailed requirement 1
- Detailed requirement 2
- Detailed requirement 3

#### Acceptance Criteria
- [ ] Specific criterion 1
- [ ] Specific criterion 2
- [ ] Specific criterion 3
- [ ] All tests pass
- [ ] Documentation updated

#### Technical Notes
- Implementation approach
- Architecture considerations
- APIs or services involved
- Database changes needed
- Performance requirements
- Security considerations

#### Dependencies
- Related tickets: TICKET-XXX
- Blocked by: TICKET-YYY
- Depends on: System/Service name

#### Test Plan
- Unit test requirements
- Integration test scenarios
- Manual testing steps
- Performance test criteria

### Output
Save the draft in `todos/public/` with naming convention:
`YYYY-MM-DD-jira-ticket-draft-{summary-slug}.todo.md`

Include frontmatter:
```yaml
---
title: Jira Ticket Draft - {Summary}
description: Draft ticket for {brief description}
status: pending
priority: {high|medium|low}
owner: {your name}
created: {today}
tags: [jira, ticket-draft]
---
```

Then include the formatted ticket content that can be copied into Jira.
