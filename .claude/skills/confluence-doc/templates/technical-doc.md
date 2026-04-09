# Technical Documentation Template

Use this template for technical documentation in Confluence.

## Structure

```confluence
{info}
*Status:* Draft | In Progress | Review | Completed
*Author:* [Author Name]
*Created:* YYYY-MM-DD
*Last Updated:* YYYY-MM-DD
*Related Jira:* [TICKET-123]
{info}

h1. [Technical Component/Feature Name]

h2. Overview

Brief description of the technical component, feature, or system being documented.

h2. Architecture

h3. System Architecture

High-level architecture overview.

h3. Components

Description of main components and their responsibilities.

h3. Data Flow

How data flows through the system.

h2. Technical Details

h3. Technologies Used

* Technology 1 - Purpose
* Technology 2 - Purpose
* Technology 3 - Purpose

h3. Key Interfaces

|| Interface || Type || Description ||
| API Endpoint | REST | Description |
| Service | Internal | Description |

h2. Implementation

h3. Code Structure

Description of code organization.

{code:javascript}
// Example code
{code}

h3. Key Functions/Methods

|| Function || Parameters || Returns || Description ||
| functionName() | param1, param2 | returnType | What it does |

h2. Configuration

h3. Environment Variables

|| Variable || Required || Default || Description ||
| VAR_NAME | Yes | - | Purpose |

h3. Configuration Files

Description of configuration files and their purpose.

h2. Dependencies

h3. External Dependencies

* Dependency 1 - Version - Purpose
* Dependency 2 - Version - Purpose

h3. Internal Dependencies

* Internal Service 1 - How it's used
* Internal Service 2 - How it's used

h2. Testing

h3. Test Strategy

Description of testing approach.

h3. Running Tests

{code:bash}
npm test
{code}

h2. Deployment

h3. Deployment Process

Step-by-step deployment instructions.

h3. Rollback Procedure

How to rollback if issues occur.

h2. Monitoring & Observability

h3. Metrics

Key metrics to monitor.

h3. Logs

Where to find logs and what to look for.

h3. Alerts

Alert configurations and response procedures.

h2. Troubleshooting

h3. Common Issues

|| Issue || Cause || Solution ||
| Issue description | Root cause | How to fix |

h2. API Reference

(If applicable)

h3. Endpoints

h4. GET /api/endpoint

*Description:* What this endpoint does

*Parameters:*
|| Parameter || Type || Required || Description ||
| param1 | string | Yes | Description |

*Response:*
{code:json}
{
  "key": "value"
}
{code}

h2. Related Documentation

* [Related Page 1]
* [Related Page 2]
* [External Documentation|https://example.com]

h2. Changelog

|| Date || Version || Changes || Author ||
| YYYY-MM-DD | 1.0.0 | Initial release | Name |

---

*Contributors:* @name1, @name2
*Tags:* technical, backend, api, documentation
```
