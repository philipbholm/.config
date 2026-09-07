# GitHub feedback

## Collect the items

Resolve the PR from the supplied number, URL, or branch. Fetch review comments,
conversation comments, and review bodies with pagination. Keep an index of
IDs, authors, paths, original commit IDs, thread state, and short previews;
read full bodies when assessing each item.

```bash
gh api --paginate repos/{owner}/{repo}/pulls/<n>/comments
gh api --paginate repos/{owner}/{repo}/issues/<n>/comments
gh api --paginate repos/{owner}/{repo}/pulls/<n>/reviews
```

Keep replies with their parent thread. Exclude items already settled in the
conversation, and record that exclusion. Otherwise assess every requested
finding; neither an old revision nor low severity is reason to discard it.

## Distinguish automated findings from human comments

Automated reviews may be posted through ordinary member accounts. An account
with `user.type: User` can carry both kinds; inspect the comment itself.

An inline finding is automated when it has a severity, `·`, and backticked
slug header, or ends with an automated-review footer. Match severity words
such as Critical, Blocker, Major, Minor, or Nit; emoji and slugs can vary.

```text
🟡 **Minor** · `test-coverage`
🟠 **Major** · `denial-of-service`
```

Review bodies announce automation at the top or in a footer. Historical forms
include:

```text
🤖 **Automated review by Claude Code.**
## Automated review — PR #3707 … produced automatically by **Claude Code**
_This review was produced automatically by Claude Code._
🤖 **Automated review by Claude Code using claude-opus-4-6.**
```

These are examples, not an exhaustive list. A person discussing an automated
review is still a person. Treat replies individually: a human reply inside an
automated thread remains human. Genuine GitHub Apps are automated. When
classification is uncertain, treat the comment as human.

## Respond after pushing

Answer every automated finding with its recorded outcome. For Fixed or Already
fixed, link the correction's commit or location. Explain the problem and
correction only as much as needed; other outcomes carry their evidence or
blocker. Several findings from one review body receive one combined response.

Read the thread before posting to avoid duplicate replies. Post file-backed
bodies with `-F`, not `-f body=@…`, and read back the result to confirm that the
text, rather than a file path, was posted. Resolve answered automated threads
unless repository instructions say otherwise.

Never post a response aimed at a human or resolve a human-started thread.
Write human-response drafts to a local Markdown file containing each thread
link, the comment being answered, outcome, correction link when applicable,
and a draft reply. Return that file to the user. This applies even when the
human finding was fixed.
