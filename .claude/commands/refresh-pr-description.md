# Refresh PR Description

Update an existing pull request's title and description to reflect the current state of the branch. Useful after adding commits, rebasing, or when the original description is stale or incomplete.

For guidance on PR title format, base branch detection, and general PR rules, see `/open-pr`.

## Usage

```bash
/refresh-pr-description                # Refreshes the PR for the current branch
/refresh-pr-description 54             # Refreshes PR #54 by number
```

## Steps

1. **Identify the PR**

   If a PR number is provided, use it directly. Otherwise, find the open PR for the current branch:

   ```bash
   gh pr view --json number,title,body,baseRefName,headRefName
   ```

   If no open PR exists for the current branch, stop and inform the user. Do not create a new PR — use `/open-pr` for that.

2. **Get the current diff and commits**

   Gather the full picture of what the PR contains:

   ```bash
   # All commits on the branch since it diverged from base
   gh pr view --json commits --jq '.commits[].messageHeadline'

   # Full diff stat
   gh pr diff --stat
   ```

3. **Fetch the PR template**

   Always use the repo's PR template as the structure for the updated body:

   ```bash
   # Detect the GitHub owner/repo
   gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'

   # Fetch the PR template
   gh api repos/<owner>/<repo>/contents/.github/pull_request_template.md --jq '.content' | base64 -d
   ```

   If the template doesn't exist (404), use the existing PR body structure as a base.

4. **Generate the updated title and description**

   **Title**: Review the current title against the branch's commits. If the title no longer accurately reflects the PR's scope, generate an updated title following the `/open-pr` title format rules (ticket ID prefix from branch name, or conventional commit prefix). Always update the title if it is stale or generic.

   **Description**: Always regenerate the full description. Fill in every section of the template based on:
   - The branch's commits and diff
   - The existing PR body (preserve any manually written context that is still accurate)
   - Conversation context if relevant

   Show the updated title and body to the user for review before applying.

5. **Update the PR**

   After user confirmation, apply the changes:

   ```bash
   gh pr edit <pr-number> --title "<updated-title>" --body "<updated-body>"
   ```

   Return the PR URL to the user when done.

## Rules

These rules apply every time this command runs. No exceptions. See `/open-pr` for the full set of PR rules.

- **Always refresh the description**: The body is always regenerated from the template and current branch state. This is not optional.
- **Update the title when necessary**: If the title no longer matches the PR's scope or content, update it. When in doubt, update it.
- **Never merge PRs**: Do not run `gh pr merge` or any merge command.
- **Never assign reviewers**: Do not add reviewers unless the user explicitly requests it.
- **Never change draft status**: Do not convert draft PRs to ready for review, or vice versa.
- **Preserve manual context**: If the existing body contains manually written notes, decisions, or context that is still accurate, keep it. Only replace sections that are stale or empty.
- **Always confirm**: Show the updated title and description to the user before applying. Do not edit the PR without confirmation.

## Notes

- This command only updates the PR title and description. It does not push commits, rebase, or change the branch.
- If the PR has reviewer comments referencing specific sections, be careful not to remove context those comments depend on.
- The `$ARGUMENTS` variable below captures any additional context the user provides after `/refresh-pr-description`.

## Additional Guidance

$ARGUMENTS
