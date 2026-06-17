# Secret Room Assistant

Secret Room Assistant helps players find likely Secret Room locations in *The Binding of Isaac: Repentance* without revealing hidden floor data.

Finding a Secret Room normally requires checking the visible room layout, remembering which walls have already been tested, and recognizing locations that are impossible because of obstacles or floor rules. This becomes tedious during longer runs and is especially difficult around large or L-shaped rooms.

The mod performs that bookkeeping for the player. It uses only information the player could reasonably know, evaluates visible room connections, rejects walls blocked by rocks, poop, spikes, water, or similar grid entities, and remembers failed bomb tests. It also avoids suggesting standard Secret Rooms on floors where they cannot generate.

Candidate markers are displayed through MinimapAPI:

- `!` - a strong candidate touching at least three known rooms.
- `?` - a possible candidate touching two known rooms.
- `x` - a location ruled out by an obstacle or a failed bomb test.

The current version focuses exclusively on standard Secret Rooms. Super Secret Room support is intentionally reserved for a later version.

## Requirement

- MinimapAPI

