# Working-tree snapshots

Use this when review includes uncommitted implementation. A Git tree captures
the final content without committing on the user's branch or changing the
real index. Temporary objects and exports are local review artifacts.

1. Record HEAD, status, and task-owned paths, including deletions and untracked
   files. Resolve ownership before including mixed or unrelated edits. When a
   file mixes task and unrelated hunks, prepare its task-only content separately
   for import in step 2. Leave the user's file and index untouched.
2. Create a temporary directory outside the checkout. Use its nonexistent
   `index` path as `GIT_INDEX_FILE` for every index command. Initialize it with
   `git read-tree <pinned-head>`, then use `git add -A -- <explicit-task-paths>`
   under that temporary index to capture final working-tree content. Do not
   use an unrestricted `git add -A`; keep ignored files and secrets excluded.
   Exclude mixed files from that add, then import their prepared content with
   `git hash-object -w` and `git update-index --cacheinfo`, preserving file modes.
   For an explicit staged-only review, capture the selected index versions
   instead of reading the working-tree versions.
3. Run `git write-tree` with that temporary index and record the returned tree
   ID. Compare `git diff <pinned-merge-base> <reviewed-tree>` and record
   `git log <pinned-merge-base>..<pinned-head>` separately. Local edits are part
   of the tree even though they do not appear in the commit list. Recheck HEAD
   and the task-owned diff after capture; rebuild if another writer changed
   the inputs during capture.
4. Read files with `git show <reviewed-tree>:<path>`, or export the tree with
   `git archive` into the temporary directory. Give reviewers that tree or
   export so later checkout edits cannot change their evidence. Resolve
   tracked standards and spec files from the same tree; capture external
   requirement sources separately when they are mutable.
5. Before delivery, repeat the capture with a fresh temporary index initialized
   from the pinned HEAD, then compare with the reviewed tree. Reinitializing
   preserves the ability to capture deleted paths again. If HEAD moved, inspect
   the intervening changes first and compare the final committed task content
   and remaining local changes with the snapshot. After fixes, capture a new
   tree and review the affected changes; record which final tree the completed
   assessment covers.

Remove only the temporary directory created for this review after its readers
finish. Do not stage, reset, stash, checkout, or commit in the user's working
tree to create a review snapshot.
