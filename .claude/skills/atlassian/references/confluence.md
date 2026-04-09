# Confluence REST API Reference

Confluence uses two API versions. The v2 API is preferred for page operations; the v1 API
is still needed for CQL search and some legacy operations.

**Important:** All Confluence paths require the `/wiki` prefix (e.g. `/wiki/api/v2/pages`),
unlike Jira which sits at the domain root.

## Pages (v2 API)

### Get Page

```http
GET /wiki/api/v2/pages/{id}?body-format=storage
```

Query params:

- `body-format` — `storage` (XHTML) or `atlas_doc_format` (ADF). Use `storage` for editing.

Response:

```json
{
  "id": "12345",
  "status": "current",
  "title": "Page Title",
  "spaceId": "98765",
  "parentId": "11111",
  "parentType": "page",
  "version": { "number": 3, "createdAt": "2026-04-01T12:00:00Z" },
  "body": {
    "storage": {
      "representation": "storage",
      "value": "<p>Page content in XHTML</p>"
    }
  },
  "_links": { "webui": "/spaces/PD/pages/12345/Page+Title" }
}
```

### Create Page

```http
POST /wiki/api/v2/pages
{
  "spaceId": "98765",
  "status": "current",
  "title": "New Page Title",
  "parentId": "11111",
  "body": {
    "representation": "storage",
    "value": "<p>Page content</p>"
  }
}
```

### Update Page

You must include the page `id` and the next `version.number` (current + 1):

```http
PUT /wiki/api/v2/pages/{id}
{
  "id": "12345",
  "status": "current",
  "title": "Updated Title",
  "body": {
    "representation": "storage",
    "value": "<p>Updated content</p>"
  },
  "version": {
    "number": 4,
    "message": "Updated via API"
  }
}
```

Always GET the page first to read the current version number, then increment by 1.

### Page Descendants (Children)

```http
GET /wiki/api/v2/pages/{id}/children?limit=25
```

### Delete Page

```http
DELETE /wiki/api/v2/pages/{id}
```

## Spaces (v2 API)

### List Spaces

```http
GET /wiki/api/v2/spaces?limit=25
```

Query params:

- `keys` — filter by space key(s), comma-separated
- `type` — `global` or `personal`
- `status` — `current` or `archived`
- `label` — filter by label
- `sort` — e.g. `name`, `-name` (descending)

Response:

```json
{
  "results": [
    {
      "id": "98765",
      "key": "PD",
      "name": "Product Development",
      "type": "global",
      "status": "current",
      "_links": { "webui": "/spaces/PD" }
    }
  ],
  "_links": { "next": "/wiki/api/v2/spaces?cursor=..." }
}
```

### Pages in a Space

```http
GET /wiki/api/v2/spaces/{spaceId}/pages?limit=25&status=current
```

Query params:

- `title` — filter by exact title
- `status` — `current`, `archived`, `draft`
- `sort` — `title`, `-title`, `created-date`, `-created-date`, `modified-date`, `-modified-date`

## Comments (v2 API)

### Footer Comments

```http
GET /wiki/api/v2/pages/{id}/footer-comments?limit=25&body-format=storage
```

Create footer comment:

```http
POST /wiki/api/v2/pages/{id}/footer-comments
{
  "body": {
    "representation": "storage",
    "value": "<p>My comment</p>"
  }
}
```

Reply to a footer comment:

```http
POST /wiki/api/v2/footer-comments/{parentCommentId}/children
{
  "body": {
    "representation": "storage",
    "value": "<p>Reply text</p>"
  }
}
```

### Inline Comments

```http
GET /wiki/api/v2/pages/{id}/inline-comments?limit=25&body-format=storage
```

Create inline comment (tied to selected text):

```http
POST /wiki/api/v2/pages/{id}/inline-comments
{
  "body": {
    "representation": "storage",
    "value": "<p>This needs clarification</p>"
  },
  "inlineCommentProperties": {
    "textSelection": "the exact text to annotate",
    "textSelectionMatchCount": 1,
    "textSelectionMatchIndex": 0
  }
}
```

## Search (v1 API — CQL)

```http
GET /wiki/rest/api/content/search?cql={cql}&limit=25&start=0
```

### Common CQL Patterns

```cql
type = page AND space = "PD" AND title ~ "release"
type = page AND space = "PD" AND label = "architecture"
type = page AND text ~ "deployment pipeline"
type = page AND ancestor = 12345
type = page AND creator = "accountId"
type = page AND lastModified >= "2026-01-01"
type = page AND space IN ("PD", "DOC", "AWE")
type = blogpost AND space = "PD"
```

URL-encode the CQL query. Use Python for reliability:

```bash
CQL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('type=page AND space=\"PD\" AND title~\"search term\"'))")
```

Response:

```json
{
  "results": [
    {
      "id": "12345",
      "type": "page",
      "title": "Page Title",
      "space": { "key": "PD", "name": "Product Development" },
      "_links": { "webui": "/spaces/PD/pages/12345/Page+Title" }
    }
  ],
  "start": 0,
  "limit": 25,
  "size": 3,
  "totalSize": 3,
  "_links": {}
}
```

## Confluence Storage Format (XHTML)

Pages use XHTML storage format. Key elements:

### Text Formatting

```html
<p>Regular paragraph</p>
<h1>Heading 1</h1>
through
<h6>Heading 6</h6>
<strong>Bold</strong>
<em>Italic</em>
<u>Underline</u>
<del>Strikethrough</del>
<code>Inline code</code>
```

### Lists

```html
<ul>
  <li>Bullet item</li>
  <li>
    Another item
    <ul>
      <li>Nested item</li>
    </ul>
  </li>
</ul>

<ol>
  <li>Numbered item</li>
</ol>
```

### Tables

```html
<table>
  <thead>
    <tr>
      <th>Header 1</th>
      <th>Header 2</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Cell 1</td>
      <td>Cell 2</td>
    </tr>
  </tbody>
</table>
```

### Links

```html
<a href="https://example.com">External link</a>
<ac:link><ri:page ri:content-title="Other Page" ri:space-key="PD" /></ac:link>
```

### Macros

**Code block:**

```html
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">javascript</ac:parameter>
  <ac:parameter ac:name="title">Example</ac:parameter>
  <ac:plain-text-body><![CDATA[const x = 1;]]></ac:plain-text-body>
</ac:structured-macro>
```

**Info/Note/Warning/Tip panels:**

```html
<ac:structured-macro ac:name="info">
  <ac:rich-text-body><p>Info text here</p></ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="note">
  <ac:rich-text-body><p>Note text</p></ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="warning">
  <ac:rich-text-body><p>Warning text</p></ac:rich-text-body>
</ac:structured-macro>
```

**Table of contents:**

```html
<ac:structured-macro ac:name="toc">
  <ac:parameter ac:name="maxLevel">3</ac:parameter>
</ac:structured-macro>
```

**Expand (collapsible section):**

```html
<ac:structured-macro ac:name="expand">
  <ac:parameter ac:name="title">Click to expand</ac:parameter>
  <ac:rich-text-body><p>Hidden content</p></ac:rich-text-body>
</ac:structured-macro>
```

**Status lozenge:**

```html
<ac:structured-macro ac:name="status">
  <ac:parameter ac:name="title">IN PROGRESS</ac:parameter>
  <ac:parameter ac:name="colour">Blue</ac:parameter>
</ac:structured-macro>
```

Colors: Grey, Red, Yellow, Blue, Green.

**Jira issue macro:**

```html
<ac:structured-macro ac:name="jira">
  <ac:parameter ac:name="key">CODE-123</ac:parameter>
</ac:structured-macro>
```

## Pagination (v2 API)

The v2 API uses cursor-based pagination. Check `_links.next` in the response:

```json
{
  "results": [...],
  "_links": {
    "next": "/wiki/api/v2/spaces/98765/pages?cursor=eyJpZCI6..."
  }
}
```

If `_links.next` exists, there are more results. Fetch the full URL to get the next page.
