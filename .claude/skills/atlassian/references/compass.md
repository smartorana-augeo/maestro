# Compass API Reference

Compass uses a GraphQL API, not REST. All requests go to a single endpoint.

> Examples use bare `atlassian_api.sh` — prepend `$SKILL_DIR/` as defined in SKILL.md.

## Contents

- [Endpoint](#endpoint) — GraphQL endpoint URL
- [Authentication](#authentication) — Same Basic Auth as Jira/Confluence
- [Making GraphQL Requests](#making-graphql-requests) — Query and mutation syntax
- [Components](#components) — Search, get, types, create, delete
- [Relationships](#relationships) — Create and delete component relationships
- [Custom Field Definitions](#custom-field-definitions) — List, create, delete
- [Activity Events](#activity-events) — Deployments, builds, alerts, incidents
- [Component Labels](#component-labels) — Filter components by label
- [Finding Your Cloud ID](#finding-your-cloud-id) — Required for all GraphQL queries

## Endpoint

```http
POST /gateway/api/graphql
```

The `atlassian_api.sh` script works for this — use POST with the GraphQL query as the JSON body.
The base URL is `https://{ATLASSIAN_DOMAIN}`, same as other APIs.

## Authentication

Same Basic Auth as Jira/Confluence. The script handles this automatically.

## Making GraphQL Requests

```bash
.claude/skills/atlassian/scripts/atlassian_api.sh POST '/gateway/api/graphql' '{
  "query": "query { compass { ... } }"
}'
```

For mutations:

```bash
.claude/skills/atlassian/scripts/atlassian_api.sh POST '/gateway/api/graphql' '{
  "query": "mutation { compass { ... } }",
  "variables": { "input": { ... } }
}'
```

## Components

### List / Search Components

```graphql
query {
  compass {
    searchComponents(
      cloudId: "your-cloud-id"
      query: { query: "search term", first: 25 }
    ) {
      nodes {
        id
        name
        type
        description
        ownerId
        labels {
          name
        }
        links {
          url
          name
          type
        }
        fields {
          definition {
            name
          }
          value {
            ... on CompassFieldTextValue {
              textValue: value
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
```

### Get Component by ID

```graphql
query {
  compass {
    component(id: "component-ari") {
      id
      name
      type
      description
      ownerId
      lifecycle
      tier
      labels {
        name
      }
      links {
        id
        url
        name
        type
      }
      relationships {
        nodes {
          id
          type
          startNode {
            id
            name
          }
          endNode {
            id
            name
          }
        }
      }
      fields {
        definition {
          id
          name
        }
        value {
          ... on CompassFieldTextValue {
            textValue: value
          }
          ... on CompassFieldNumberValue {
            numberValue: value
          }
          ... on CompassFieldBooleanValue {
            booleanValue: value
          }
        }
      }
      events(first: 10) {
        nodes {
          id
          eventType
          displayName
          description
          lastUpdated
        }
      }
    }
  }
}
```

### Get Component Types

```graphql
query {
  compass {
    componentTypes(cloudId: "your-cloud-id") {
      id
      name
      description
    }
  }
}
```

Standard types: `SERVICE`, `LIBRARY`, `APPLICATION`, `CAPABILITY`, `CLOUD_RESOURCE`,
`DATA_PIPELINE`, `MACHINE_LEARNING_MODEL`, `UI_ELEMENT`, `WEBSITE`, `OTHER`.

### Components Owned by My Teams

```graphql
query {
  compass {
    searchComponents(
      cloudId: "your-cloud-id"
      query: { ownerId: ["team-ari-1", "team-ari-2"], first: 50 }
    ) {
      nodes {
        id
        name
        type
        ownerId
      }
    }
  }
}
```

You need the team ARIs first. Get them from the Jira teams API or by querying
your user's team memberships.

### Create Component

```graphql
mutation CreateComponent($input: CompassCreateComponentInput!) {
  compass {
    createComponent(input: $input) {
      success
      componentDetails {
        id
        name
        type
      }
      errors {
        message
      }
    }
  }
}
```

Variables:

```json
{
  "input": {
    "cloudId": "your-cloud-id",
    "name": "My New Service",
    "type": "SERVICE",
    "description": "Description of the service",
    "ownerId": "team-ari",
    "labels": [{ "name": "backend" }],
    "links": [
      {
        "url": "https://github.com/org/repo",
        "name": "Source Code",
        "type": "REPOSITORY"
      }
    ]
  }
}
```

### Delete Component

```graphql
mutation {
  compass {
    deleteComponent(input: { id: "component-ari" }) {
      success
      errors {
        message
      }
    }
  }
}
```

## Relationships

### Create Relationship

```graphql
mutation {
  compass {
    createRelationship(
      input: {
        type: "DEPENDS_ON"
        startNodeId: "component-ari-1"
        endNodeId: "component-ari-2"
      }
    ) {
      success
      relationship {
        id
        type
        startNode {
          id
          name
        }
        endNode {
          id
          name
        }
      }
      errors {
        message
      }
    }
  }
}
```

Relationship types: `DEPENDS_ON`, `OTHER`.

### Delete Relationship

```graphql
mutation {
  compass {
    deleteRelationship(input: { id: "relationship-ari" }) {
      success
      errors {
        message
      }
    }
  }
}
```

## Custom Field Definitions

### List Custom Field Definitions

```graphql
query {
  compass {
    customFieldDefinitions(cloudId: "your-cloud-id") {
      id
      name
      description
      type
    }
  }
}
```

### Create Custom Field Definition

```graphql
mutation {
  compass {
    createCustomFieldDefinition(
      input: {
        cloudId: "your-cloud-id"
        name: "Cost Center"
        description: "Finance cost center code"
        type: "text"
      }
    ) {
      success
      customFieldDefinition {
        id
        name
      }
      errors {
        message
      }
    }
  }
}
```

### Delete Custom Field Definition

```graphql
mutation {
  compass {
    deleteCustomFieldDefinition(input: { id: "field-definition-ari" }) {
      success
      errors {
        message
      }
    }
  }
}
```

## Activity Events

### Get Component Activity Events

```graphql
query {
  compass {
    component(id: "component-ari") {
      events(first: 20) {
        nodes {
          id
          eventType
          displayName
          description
          lastUpdated
          externalEventSourceId
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}
```

Event types include deployments, builds, alerts, incidents, and custom events.

## Component Labels

### Get Component Labels

Labels are returned as part of the component query (see Get Component by ID above).

To filter components by label, use the search query:

```graphql
query {
  compass {
    searchComponents(
      cloudId: "your-cloud-id"
      query: { labels: [{ name: "production" }], first: 50 }
    ) {
      nodes {
        id
        name
        labels {
          name
        }
      }
    }
  }
}
```

## Finding Your Cloud ID

You need the `cloudId` for Compass queries. Get it via the tenant info endpoint:

```bash
.claude/skills/atlassian/scripts/atlassian_api.sh GET '/_edge/tenant_info'
# Returns: {"cloudId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", ...}
```

Note: `/rest/api/3/serverInfo` does **not** return the cloudId. Use `_edge/tenant_info` instead.
