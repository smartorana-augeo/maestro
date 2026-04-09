# Create a Pull Request Using GitHub CLI

Create a draft pull request for the current branch. This command walks through detecting the base branch, rebasing, fetching the repo's PR template, and opening a draft PR via `gh`.

## Usage

```bash
/open-pr                        # Opens a PR for the current branch
/open-pr for ambassador         # Specify the target repo for context
/open-pr base=develop           # Override the base branch
```

## Steps

1. **Detect the base branch**

   Target the repo's head branch (`master` or `main`) unless the user specifies otherwise. Detect it automatically:

   ```bash
   git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
   ```

2. **Pull latest and rebase**

   Always rebase on the head branch before creating the PR. This keeps the branch up to date and avoids merge conflicts:

   ```bash
   git fetch origin
   git rebase origin/<base-branch>
   ```

   If there are conflicts, stop and ask the user to resolve them before continuing.

3. **Push the branch**

   Ensure the branch is pushed to origin with tracking set up:

   ```bash
   git push -u origin <branch-name>
   ```

4. **Fetch the PR template**

   If the repo has a PR template, always fetch and use it — do not use a generic template or skip this step:

   ```bash
   # Detect the GitHub owner/repo from the remote URL
   gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'

   # Fetch the PR template
   gh api repos/<owner>/<repo>/contents/.github/pull_request_template.md --jq '.content' | base64 -d
   ```

   If the template doesn't exist (404), fall back to a simple body with a description of the changes.

   Fill in every section of the template. Replace HTML comments with actual content based on the branch's commits and diff.

5. **Create the draft PR**

   Open the PR as a draft. Never open a PR as ready for review:

   ```bash
   gh pr create --title "<title>" --base <base-branch> --draft --body "<filled-in-template>"
   ```

   Return the PR URL to the user when done.

## Rules

These rules apply every time this command runs. No exceptions.

- **Always draft**: Use `--draft` on every `gh pr create` call.
- **Never commit to head**: Never commit or push directly to `master` or `main`. Always work on a feature branch.
- **Never merge PRs**: Do not run `gh pr merge` or any merge command. PRs are merged by the team after review.
- **Never assign reviewers**: Do not add reviewers unless the user explicitly requests it.
- **PR title format**: If the branch name contains a ticket ID, prefix the title with it: `CODE-1234: description`. Otherwise, use a conventional commit prefix: `chore:`, `fix:`, `feat:`, `refactor:`, `docs:`.
- **Branch naming**: Branches should follow the pattern `TICKET-ID/short-description` (e.g. `CODE-7666/open-pr`).

## Notes

- PR templates vary between repos. Always fetch the actual template rather than assuming a structure.
- If `gh` is not authenticated, the user can run `! gh auth login` to authenticate within the session.
- The `$ARGUMENTS` variable below captures any additional context the user provides after `/open-pr`.

## Additional Guidance

$ARGUMENTS
