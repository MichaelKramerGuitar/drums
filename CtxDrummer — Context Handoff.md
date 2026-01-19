CtxDrummer — Context Handoff Document
What this project is

CtxDrummer is a context-aware, form-following MIDI rhythm engine written in SuperCollider, designed to drive drum racks (e.g. Ableton) via MIDI.

It is not a pattern sequencer.
It is a score-driven, generative performance system.

At a high level:

leadSheet / roadMap
        ↓
   shared context (~ctx)
        ↓
 independent limb generators
        ↓
     MIDI output

Core design principles (DO NOT BREAK)

These are invariants. Any extension must preserve them.

Musical structure is declarative

Song form lives in ~leadSheet and optional ~roadMap

No hardcoded song logic inside generators

Generators are stateless with respect to form

Limb tasks read ~ctx

They do not track bars, sections, or choruses themselves

Single source of time truth

One TempoClock

All Tasks are rebuilt and bound to that clock on ~start

Lifecycle safety

~build always stops old tasks before creating new ones

~start may be called repeatedly without duplication

~stop leaves no running Tasks

No functional regressions

Extensions must not change existing behavior unless explicitly requested

Key data structures
1. ~leadSheet (musical score)

Defines the musical intent, not behavior.

Required fields:

(
    title: "Name",
    tempo: 132,
    sections: [
        (name: \A, meter: [4,4], bars: 8, density: 0.2, energy: 0.3),
        ...
    ],
    kit: (kick: 36, snare: 38, ...)
)


Optional:

roadMapSpec: (
    intro: \intro,
    form: [\A, \A2, \B, \A3],
    choruses: 4,
    outro: \outro
)


Rules

sections is the authoritative definition of all possible sections

roadMapSpec is performance logic, not musical definition

You can swap the entire tune by replacing ~leadSheet

2. ~roadMap (performance plan)

An optional finite performance order, e.g.:

[\intro, \A, \A2, \B, \A3, \A, \A2, \B, \A3, \outro]


Priority order:

Manual override: ~roadMap

Compiled from ~leadSheet.roadMapSpec

nil → loop sections forever

3. ~ctx (shared runtime context)

This is the only thing limb generators read.

Canonical fields:

~ctx = (
    section: \A,
    barInSection: 3,
    meter: [4,4],
    density: 0.22,
    energy: 0.28
)


Guidelines:

~ctx is written only by the score follower

Limb tasks must treat it as read-only

Extensions may add fields, but must not remove existing ones

Common extensions:

~ctx.chorus
~ctx.globalBar
~ctx.isSectionStart
~ctx.isLastBar

Engine components
4. Score follower (~scoreTask)

Responsibilities:

Advance through sections or roadmap

Update ~ctx at section boundaries

Count bars accurately

Print form diagnostics (optional)

Two modes:

Infinite: loop through sections

Finite: iterate ~roadMap once, then stop

Important:

Score logic must stay lightweight (no heavy computation)

Bar counting must be explicit and deterministic

5. Limb definitions (~limbs)

Defines role behavior, not notes.

Per-limb parameters:

(
    subdiv4: 8,       // base rhythmic grid
    phase: 3,         // offset to avoid unison
    densityMul: 0.6,  // role weighting
    vel: [40, 90]     // MIDI dynamics
)


Design intent:

Limbs are musical roles (kick, ride, foot, texture)

Limb independence comes from different grids + phase

Density is globally controlled but locally shaped

6. Limb task factory (~makeLimbTask)

This is the generative engine.

Current algorithm:

Compute bar length from meter

Scale limb grid to bar length

Convert density → hits per bar

Distribute hits evenly with phase rotation

Emit short MIDI notes

Allowed extensions:

Euclidean rhythms

Clave / son / cascara logic

Cross-rhythm cycles

Probabilistic accenting

Microtiming offsets

Not allowed:

Hardcoding song form

Reading anything other than ~ctx + limb role

Managing lifecycle internally

Lifecycle API (public surface)

These are the only functions external code should call.

~setTune.(leadSheet)   // choose tune
~start.()              // build + run
~stop.()               // clean stop


Optional overrides:

~roadMap = [...]


Guarantees:

~start is idempotent

~build rebuilds everything

No stale Tasks survive

Known pitfalls (already solved)

MIDIOut by name is unreliable on Windows → use index

Tasks must be recreated when clock changes

Bar counters must be explicit (never infer from waits)

Printing must not affect timing

Mental model (important)

Think of CtxDrummer as:

A conductor, not a drummer

The score decides where we are

The context tells everyone what that means

The limbs improvise within that moment

MIDI is just the output medium

How to extend safely

When adding a feature, ask:

Does this belong in:

leadSheet?

roadMap?

ctx?

limb role?

limb algorithm?

Can this be done without:

adding state to limb tasks?

hardcoding form logic?

duplicating timing logic?

If yes → it belongs.

Version note

This document corresponds to:

CtxDrummer v0.1 — Context-Driven MIDI Performance Engine

Stable core:

leadSheet → ctx → limbTasks → MIDI

Everything else is negotiable.