# Review Pull Request

Review a pull request changeset and provide comprehensive analysis. The review is posted as a comment on the PR and saved locally as a memory file.

## Usage

```bash
/review-pr 54                  # Review PR #54 by number
/review-pr ambassador 5348     # Review PR #5348 in the ambassador repo
```

## Steps

1. **Identify the PR**

   Use the provided PR number. Detect the repo owner/name:

   ```bash
   gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
   gh pr view <pr-number> --json number,title,body,baseRefName,headRefName,files
   ```

2. **Pull latest in a worktree**

   Always check out the PR branch in a clean worktree before reviewing. This ensures the review is against the latest code, not a stale local copy:

   ```bash
   git fetch origin
   gh pr checkout <pr-number> --detach
   ```

   Or use a git worktree if reviewing from a different repo context. The goal is to have the latest PR code available for reading files and understanding context.

3. **Fetch existing PR comments**

   Before writing the review, gather existing reviewer feedback to incorporate:

   ```bash
   gh api repos/<owner>/<repo>/pulls/<pr-number>/comments
   gh pr view <pr-number> --json comments,reviews
   ```

   Filter out bot comments (e.g., coderabbitai). Focus on human reviewer feedback. Note which comments have been addressed vs still pending.

4. **Get the diff and commits**

   ```bash
   gh pr view <pr-number> --json commits --jq '.commits[].messageHeadline'
   gh pr diff <pr-number>
   ```

5. **Conduct the review**

   Read the changed files in the worktree. Analyze the diff and produce the review following the structure below.

6. **Post the review as a PR comment**

   Always post the review as a comment on the PR:

   ```bash
   gh pr comment <pr-number> --body "<review-content>"
   ```

7. **Save the review locally**

   Save to `memories/personal/pr-reviews/{REPO_NAME}/YYYY-MM-DD-pr-{pr-number}-review.memory.md`. Create directories if needed.

## Review Structure

### 1. Executive Summary

- Brief overview of changes
- Overall risk assessment (Low/Medium/High)
- Recommendation (approve/request changes/discuss) — this is a **suggestion only**, see Rules
- Priority fixes needed (if any)

### 2. File-by-File Analysis

For each changed file with findings:

- **File**: `path/to/file.ext`
- **Lines X-Y**: Specific feedback with line numbers
- **Issue Type**: Bug/Security/Performance/Code Quality
- **Severity**: Critical/High/Medium/Low
- **Recommendation**: Specific fix or improvement

### 3. Cross-File Issues

- Integration problems between files
- Architecture concerns
- Breaking changes
- Performance impacts

### 4. Security & Best Practices

- Security vulnerabilities with file:line references
- Input validation issues
- Error handling problems
- Data protection concerns

### 5. Testing & Documentation

- Missing tests with file references
- Documentation gaps

### 6. Existing Reviewer Comments

Summarize existing human reviewer comments:

| Reviewer | File              | Line | Comment        | Status            |
| -------- | ----------------- | ---- | -------------- | ----------------- |
| name     | `path/to/file.ts` | 45   | "comment text" | Addressed/Pending |

## Rules

These rules apply every time this command runs. No exceptions.

- **Never approve or reject**: Do not use `gh pr review --approve` or `gh pr review --request-changes`. Only post a comment with your analysis and suggestion. The human reviewer makes the final call.
- **Always pull latest**: Review against the latest code in the PR branch, not a stale local copy.
- **Always post to PR**: The review must be posted as a comment on the PR via `gh pr comment`.
- **Always save locally**: Save the review to `memories/personal/pr-reviews/`.
- **Never merge PRs**: Do not run `gh pr merge` or any merge command.
- **Never assign reviewers**: Do not add reviewers unless the user explicitly requests it.
- **Focus on the diff**: Review the changes, not the entire codebase. Only comment on surrounding code if it's directly affected.
- **Be specific and actionable**: Every finding should reference a file and line number, and include a concrete recommendation.

## Review Guidelines

- Always reference file names and line numbers for specific issues
- Use format: `File: path/to/file.ext:Line X - Issue description`
- Prioritize critical issues that could cause production problems
- Provide specific, actionable recommendations
- Fetch existing PR comments before writing the review to avoid duplicating feedback

## Save Format

Include YAML frontmatter in the memory file:

```yaml
---
title: PR #{PR_NUMBER} Review
description: Code review for {PR title}
created: { today }
tags: [code-review, pr-review, { repository }]
pr_number: { PR_NUMBER }
repository: { REPO_NAME }
risk_level: { Low/Medium/High }
---
```

## Additional Guidance

$ARGUMENTS
