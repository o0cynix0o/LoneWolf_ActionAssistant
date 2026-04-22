# Strategy Guide Style Guide

This is the house style for book-specific strategy guides in the Lone Wolf wiki.

Use this for:

- new strategy guides created when a new book becomes playable
- major rewrites of existing book guides
- route-guide updates large enough to affect the overall voice and structure

The target feel is:

- classic `BradyGames` / printed strategy-guide article
- spoiler-friendly
- readable in one sitting
- useful during planning and replay

This is not the style for:

- terse route notes
- design memos
- audit reports
- achievement-only checklists

## Core Rule

Write the guide like an article someone wants to read, not a stack of bullets someone has to decode.

The guide should feel like:

- a confident guide writer explaining the book
- a readable feature article with practical advice
- a polished wiki page that renders cleanly on GitHub

It should not feel like:

- a wall of disconnected list items
- a route spreadsheet
- a dev note dump
- an audit report copied into the wiki

## Reader Experience Goals

Every guide should help the reader answer these questions quickly:

- what is this book about
- how does this book actually work
- what is the safest first win
- what are the meaningful winning route families
- which items or clues really matter
- what should I come back for on replay

The page should still be enjoyable even if the reader is not actively playing at that exact moment.

## Voice And Tone

The tone should be:

- warm
- direct
- confident
- spoiler-friendly
- slightly dramatic when the book deserves it

The voice should sound like a strategy-guide writer, not a changelog.

Prefer:

- full explanations
- connective tissue between ideas
- clear verdicts and recommendations
- prose that tells the reader why a route matters

Avoid:

- repetitive `Why it is good / Why it is bad / Best for` blocks everywhere
- overly clinical route cataloguing
- dry audit phrasing
- list-heavy chunks with no paragraph flow

## Structure Expectations

Each guide should usually include these parts in roughly this order:

1. title
2. short opening explanation of what the guide is
3. story summary
4. quick answer or quick recommendation section near the top
5. explanation of how the book works
6. first-playthrough recommendation
7. major winning route families
8. item, clue, or discovery routes that matter
9. discipline or build notes when relevant
10. trap choices, common mistakes, or risk warnings
11. achievement-cleanup advice
12. final recommendation

Not every book needs exactly the same labels, but every guide should cover the same reader needs.

## Keep The Story Summary

Book summaries are required.

Do not strip them out in the name of efficiency.

The summary should:

- set the tone of the book
- explain the mission or emotional arc
- help the reader understand why the strategy feels the way it does

The summary should not be a giant lore recap. Keep it focused on the shape of the run.

## Prose First, Lists Second

The guide should be prose-first.

Use paragraphs as the default tool. Use lists only when they genuinely help readability.

Good uses of lists:

- quick-answer callouts
- naming the three main winning routes
- short section-path references
- small achievement or item reminders

Bad uses of lists:

- replacing normal explanation with bullet spam
- breaking every route into tiny repeated sub-bullets
- turning the whole guide into a checklist

If a section can be explained more naturally in two or three paragraphs, do that.

## Paragraph Length And GitHub Rendering

Remember that the raw Markdown will look denser in plain text than it does on GitHub.

To keep the rendered wiki page readable:

- use frequent section headings
- keep paragraphs short to medium length
- break up very dense sections into smaller headings
- leave breathing room between major ideas

The goal is:

- article flow
- not giant text blocks

## Route Coverage Style

When describing major routes:

- explain the route in prose
- say what kind of player or run it suits
- explain why it is strong, weak, safe, risky, direct, clever, or memorable

Do not reduce route coverage to a bare section-number dump.

Section paths are useful, but they should support the explanation rather than replace it.

## What To Emphasize

Prefer writing about:

- what a first-time player should do
- what a replaying player should come back for
- what the book rewards
- what the book punishes
- what makes one route feel different from another

This means the guide should include judgment, not just information.

## What To Avoid

Avoid these habits unless a specific guide truly needs them:

- giant `At A Glance` bullet walls
- repeating the same mini-template for every route
- listing every possible branch
- reading like a testing artifact
- reading like internal design notes

The wiki guide is a player-facing article, not a dev-facing audit file.

## Recommended Opening Pattern

The top of the guide should usually feel like this:

- brief explanation of the page
- story summary
- quick answer section
- transition into deeper route analysis

That gives the page both:

- immediate usefulness
- long-form readability

## Reusable Template Skeleton

```md
# Book X Strategy Guide: <Title>

Intro paragraph explaining what the guide is and how spoiler-friendly it will be.

## Quick Answer

Short practical recommendation for first win / replay / cleanup.

## Story Summary

Article-style summary that sets the tone and mission of the book.

## How Book X Really Works

Explain the book's true challenge and what kind of judgment it rewards.

## The Best First Playthrough

Explain the safest serious approach in prose.

## The Major Winning Routes

Use route-by-route prose sections with section-path references where useful.

## Item And Discovery Routes That Matter

Explain the routes worth revisiting for item, clue, or campaign reasons.

## Discipline And Build Notes

Explain what kinds of disciplines or builds matter in this book.

## Trap Choices And Common Mistakes

Warn the reader about the book's bad habits and bait branches.

## Achievement Cleanup

Explain how to split clean-win and cleanup goals intelligently.

## Final Recommendation

End with a printed-guide-style summary verdict.
```

## Short Quality Check Before Publishing

Before calling a guide done, ask:

- does this read like an article
- does it keep the story summary
- does it give a clear first-win recommendation
- does it explain the important routes instead of just listing them
- does it avoid feeling like a bullet wall
- would this render cleanly and pleasantly on GitHub

If the answer to any of those is `no`, revise before publishing.
