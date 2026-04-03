# Book Source Map

This doc is the quick map for the local book corpus used by audits and route work.

## Source Priority

Preferred source order for Lone Wolf audits:

1. local corpus under `books/lw/`
2. local rules/support pages in the same book folder
3. Project Aon plus errata as fallback or cross-check
4. Definitive Edition playtest findings as correction layer when they differ

## Local Corpus Layout

Main local corpus root:

- `books/lw/`

Other local book roots present:

- `books/gs/`
- `books/fw/`

These are currently just noted here. The Kai workflow so far has used `books/lw/`.

Typical Lone Wolf book folder contents:

- `title.htm`
- `sect1.htm` through the book's last section file
- `gamerulz.htm`
- `footnotz.htm`
- `equipmnt.htm`
- `action.htm`
- `random.htm`
- `crtable.htm`
- `cmbtrulz.htm`
- map / illustration / art assets

Most useful files during audits:

- `sect*.htm`
  section text and route tracing
- `footnotz.htm`
  footnotes and special exceptions
- `gamerulz.htm`
  book-specific rules context
- `equipmnt.htm`
  equipment and startup package context
- `random.htm`
  book-specific random-number guidance when present

## Kai Book Folder Map

- `01fftd`
  `Flight from the Dark`
- `02fotw`
  `Fire on the Water`
- `03tcok`
  `The Caverns of Kalte`
- `04tcod`
  `The Chasm of Doom`
- `05sots`
  `Shadow on the Sand`
- `06tkot`
  `The Kingdoms of Terror`
- `07cd`
  `Castle Death`
- `08tjoh`
  `The Jungle of Horrors`
- `09tcof`
  `The Cauldron of Fear`
- `10tdot`
  `The Dungeons of Torgar`
- `11tpot`
  `The Prisoners of Time`
- `12tmod`
  `The Masters of Darkness`
- `13tplor`
  `The Plague Lords of Ruel`
- `14tcok`
  `The Captives of Kaag`
- `15tdc`
  `The Darke Crusade`
- `16tlov`
  `The Legacy of Vashna`
- `17tdoi`
  `The Deathlord of Ixia`
- `18dotd`
  `Dawn of the Dragons`
- `19wb`
  `Wolf's Bane`
- `20tcon`
  `The Curse of Naar`
- `21votm`
  `Voyage of the Moonstone`
- `22tbos`
  `The Buccaneers of Shadaki`
- `23mh`
  `Mydnight's Hero`
- `24rw`
  `Rune War`
- `25totw`
  `Trail of the Wolf`
- `26tfobm`
  `The Fall of Blood Mountain`
- `27v`
  `Vampirium`
- `28thos`
  `The Hunger of Sejanoz`
- `29tsoc`
  `The Storms of Chai`
- `dotd`
  `Dawn of the Darklords`

## Recommended Audit Start Pattern

For a new book audit:

1. go to `books/lw/<code>/title.htm`
2. confirm the title
3. trace sections from `sect1.htm`
4. keep `footnotz.htm`, `gamerulz.htm`, and `equipmnt.htm` open as side references
5. only use Project Aon or errata pages if the local corpus is missing data or needs cross-checking

## Repo Hygiene

- `books/` should remain local-only reference material
- do not commit the corpus into the main repo
- audit reports and route summaries belong in:
  - `testing/logs/`
- app behavior and workflow changes belong in:
  - `docs/`
