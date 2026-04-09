# Project Documentation Template

Use this template for project documentation in Confluence.

## Structure

```confluence
{info}
*Status:* Planning | Active | On Hold | Completed
*Project Owner:* [Name]
*Created:* YYYY-MM-DD
*Last Updated:* YYYY-MM-DD
*Related Jira Epic:* [EPIC-123]
{info}

h1. [Project Name]

h2. Executive Summary

Brief overview of the project, its goals, and expected outcomes (2-3 paragraphs).

h2. Project Overview

h3. Background

Context and motivation for the project. What problem are we solving?

h3. Goals & Objectives

Primary goals of this project:

* Goal 1 - Measurable outcome
* Goal 2 - Measurable outcome
* Goal 3 - Measurable outcome

h3. Success Metrics

|| Metric || Target || How We Measure ||
| Metric 1 | 90% | Description |
| Metric 2 | $100k | Description |

h2. Scope

h3. In Scope

* Feature/functionality 1
* Feature/functionality 2
* Feature/functionality 3

h3. Out of Scope

* Item 1
* Item 2
* Item 3

h3. Future Considerations

Items that may be addressed in future phases.

h2. Timeline & Milestones

|| Milestone || Target Date || Status || Description ||
| Kickoff | YYYY-MM-DD | Completed | Project launch |
| Phase 1 | YYYY-MM-DD | In Progress | Milestone description |
| Phase 2 | YYYY-MM-DD | Not Started | Milestone description |
| Launch | YYYY-MM-DD | Not Started | Go-live date |

h2. Team & Responsibilities

h3. Core Team

|| Name || Role || Responsibilities ||
| Person 1 | Project Manager | Overall coordination |
| Person 2 | Tech Lead | Technical decisions |
| Person 3 | Developer | Implementation |

h3. Stakeholders

|| Name || Role || Involvement ||
| Person 4 | Executive Sponsor | Strategic direction |
| Person 5 | Product Owner | Requirements |

h2. Requirements

h3. Functional Requirements

# User must be able to...
# System shall provide...
# Application needs to support...

h3. Non-Functional Requirements

* *Performance:* Response time < 200ms
* *Scalability:* Handle 10k concurrent users
* *Security:* SOC 2 compliance
* *Availability:* 99.9% uptime

h3. Technical Requirements

* Technology stack requirements
* Infrastructure requirements
* Integration requirements

h2. Architecture & Technical Approach

High-level technical approach and key architectural decisions.

{note}
See [Technical Design Document] for detailed technical specifications.
{note}

h2. Deliverables

|| Deliverable || Owner || Due Date || Status ||
| Technical Design Doc | Tech Lead | YYYY-MM-DD | Completed |
| Feature Implementation | Dev Team | YYYY-MM-DD | In Progress |
| Documentation | Tech Writer | YYYY-MM-DD | Not Started |
| QA Testing | QA Team | YYYY-MM-DD | Not Started |

h2. Dependencies

h3. Internal Dependencies

* Dependency on Team/Project A
* Dependency on Service B
* Requires feature C to be completed

h3. External Dependencies

* Third-party service integration
* Vendor deliverables
* External approvals

h2. Risks & Mitigation

|| Risk || Probability || Impact || Mitigation Strategy ||
| Risk description | High/Med/Low | High/Med/Low | How we'll address it |

h2. Budget & Resources

h3. Budget

|| Category || Estimated Cost || Actual Cost ||
| Development | $XX,XXX | $XX,XXX |
| Infrastructure | $XX,XXX | $XX,XXX |
| Third-party Services | $XX,XXX | $XX,XXX |
| *Total* | *$XXX,XXX* | *$XXX,XXX* |

h3. Resource Allocation

|| Resource || Allocation || Duration ||
| Developer 1 | 50% | 3 months |
| Designer | 25% | 1 month |

h2. Communication Plan

|| Audience || Frequency || Method || Owner ||
| Stakeholders | Weekly | Email update | PM |
| Team | Daily | Stand-up | Tech Lead |
| Leadership | Monthly | Presentation | PM |

h2. Testing Strategy

h3. Test Plan

Overview of testing approach.

h3. QA Criteria

* Acceptance criteria 1
* Acceptance criteria 2
* Performance benchmarks

h2. Rollout Plan

h3. Phases

# Phase 1: Beta release to 10% of users
# Phase 2: Gradual rollout to 50%
# Phase 3: Full rollout to 100%

h3. Rollback Strategy

Description of rollback procedures if issues arise.

h2. Post-Launch

h3. Monitoring

Key metrics and monitoring procedures post-launch.

h3. Support Plan

How issues will be triaged and resolved.

h3. Documentation

* User documentation
* Training materials
* Runbooks

h2. Project Status Updates

h3. [Date] - Status Update

Brief update on progress, blockers, and next steps.

h3. [Date] - Status Update

Brief update on progress, blockers, and next steps.

h2. Related Documentation

* [Technical Design Document]
* [API Documentation]
* [User Guide]
* [Related Projects]

h2. Changelog

|| Date || Version || Changes || Author ||
| YYYY-MM-DD | 1.0.0 | Project kickoff | Name |
| YYYY-MM-DD | 1.1.0 | Updated timeline | Name |

---

*Contributors:* @name1, @name2, @name3
*Tags:* project, planning, active
```
