---
description: Pull latest changes from master and clean up merged branches
allowed-tools: Bash(git *)
---

I'll refresh your repository by pulling the latest changes and cleaning up merged branches.

$ARGUMENTS

Please follow this process:

1. **Check Current Status**

   - Run `git status` to see current state
   - Run `git branch --show-current` to confirm current branch

2. **Switch to Master (if needed)**

   - If not on master, switch to master branch
   - Stash any uncommitted changes if necessary

3. **Pull Latest Changes**

   - Run `git pull origin master`
   - Show summary of changes pulled

4. **List All Local Branches**

   - Show all local branches to identify candidates for cleanup
   - Identify which branches might be merged

5. **Clean Up Merged Branches**

   - Use `git branch --merged master` to find branches merged into master
   - Exclude master and current branch from deletion
   - Delete each merged branch with confirmation
   - Use `git branch -d [branch-name]` for safe deletion

6. **Optional: Clean Up Remote Tracking References**

   - Run `git remote prune origin` to remove stale remote branch references
   - This cleans up references to deleted remote branches

7. **Summary Report**
   - Show current branch status
   - List remaining local branches
   - Confirm repository is clean and up-to-date
   - Show any untracked files that remain

If any step encounters issues (like uncommitted changes or unmerged branches), stop and ask for guidance.
