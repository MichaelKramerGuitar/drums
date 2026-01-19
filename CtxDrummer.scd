/************************************************************
CtxDrummer: Context-aware, form-following MIDI rhythm engine
------------------------------------------------------------

WHAT THIS DOES (current behavior):
- Sends MIDI notes to Ableton via loopMIDI (SuperCollider acts as a sequencer).
- Uses a "lead sheet" (song roadmap) to update a shared context (~ctx).
- Creates one independent generator Task per kit piece ("limb independence").
- Each limb reads ~ctx (meter/density/energy) and produces a "non-human"
  but musical pulse texture that adapts to meter changes.

WHAT THIS DOES NOT DO YET (on purpose):
- No explicit “AABA x4 then outro” repetition logic (easy to add).
- No printing of section boundaries/bar numbers (easy to add).
- No kit switching or limb remapping mid-performance (easy to add).
- No advanced rhythm engines (Euclidean, clave, cross-rhythm), but the
  architecture is set up perfectly to add them.

EXTENSION STRATEGY:
- Musical structure lives in ~leadSheet (score / roadmap)
- Engine behavior lives in ~limbs and layer factories (~makeLimbTask)
- Rendering/DAW integration stays in MIDIOut (~midiOut)
************************************************************/


/************************************************************
1) MIDI OUTPUT SETUP (Ableton via loopMIDI)
------------------------------------------------------------
- MIDIClient.destinations prints available outputs.
- You discovered that on Windows, index-based MIDIOut is most reliable.
- If your loopMIDI index changes, update MIDIOut(2) accordingly.
************************************************************/
MIDIClient.init;

MIDIClient.destinations.do { |ep, i|
    (i.asString ++ ": " ++ ep.device ++ " / " ++ ep.name).postln;
};

~midiOut = MIDIOut(2);  // <- IMPORTANT: must match loopMIDI index
~midiOut.latency = 0;

// Optional sanity check:
// NOTE: Doing noteOn/noteOff immediately may not trigger Ableton visibly.
// If you want a reliable check, do it in a Routine/fork.
// {
//     ~midiOut.noteOn(0, 60, 100);
//     0.2.wait;
//     ~midiOut.noteOff(0, 60);
// }.fork;


(
// Simple click sound (audio only, no MIDI, never recorded as MIDI in Ableton)
SynthDef(\ctxClick, { |out=0, amp=0.15, freq=1200|
	var env = EnvGen.kr(Env.perc(0.001, 0.04), doneAction:2);
	var sig = SinOsc.ar(freq) * env * amp;
	Out.ar(out, sig!2);
}).add;
)

(
// Click config
~clickEnabled = true;      // toggle
~clickOut = 0;             // SC audio out bus (0 = main)
~clickAmp = 0.12;

// bar/beat click: strong on 1, light otherwise
~makeClickTask = {
	Task({
		loop {
			var meter = ~ctx.meter ? [4,4];
			var beatsPerBar = ~barBeats.(meter);     // in quarter-beats
			var beats = meter[0];                    // "counted" beats
			var beatDur = beatsPerBar / beats;       // duration of one beat in clock beats

			beats.do { |i|
				if (~clickEnabled) {
					Synth(\ctxClick, [
						\out, ~clickOut,
						\amp, (i == 0).if({ ~clickAmp * 1.8 }, { ~clickAmp }),
						\freq, (i == 0).if({ 1600 }, { 1100 })
					]);
				};
				beatDur.wait;
			};
		}
	}, ~clock);
};
)


/************************************************************
2) LEAD SHEET: musical context / roadmap (YOU EDIT THIS OFTEN)
------------------------------------------------------------
This is your “lead sheet” / score representation. It should contain:
- title, tempo, swing, and a list of sections
- per section: name, meter, bars, density, energy

HOW TO EXTEND:
- Add or reorder sections (intro, A, B, bridge, vamp, out, etc.)
- Change meters per section to get mixed-meter forms
- Change density/energy per section to shape rhythmic intensity
- Add new fields later (e.g. "feel", "kitName", "layersOn", "cue")
  without breaking the engine, as long as you decide how to use them.

IMPORTANT (current state):
- If ~roadMap is nil AND leadSheet.roadMapSpec is nil:
    -> the score loops leadSheet.sections forever.
- If ~roadMap is set OR leadSheet.roadMapSpec is present:
    -> the score will run a FINITE arrangement and then auto-stop.
- You can override which tune is active using ~setTune.(<leadSheet>).
************************************************************/
(
~leadSheet = (
    title: "Untitled",
    tempo: 132,
    swing: 0.58,

    sections: [
        (name: \intro, meter: [4,4], bars: 4, density: 0.15, energy: 0.20),
        (name: \A,     meter: [7,8], bars: 8, density: 0.22, energy: 0.28),
        (name: \B,     meter: [4,4], bars: 8, density: 0.30, energy: 0.35),
        (name: \A2,    meter: [7,8], bars: 8, density: 0.26, energy: 0.32),
        (name: \out,   meter: [4,4], bars: 4, density: 0.18, energy: 0.18)
    ],

    // KIT MAPPING:
    // Map musical "kit keys" to MIDI note numbers in Ableton Drum Rack.
    // Swap to a new kit by changing these numbers (or by switching ~leadSheet entirely).
    kit: (
        kick: 36,
        snare: 38,
        hatC: 42,
        hatFoot: 44,
        ride: 51,
        perc1: 70
    )
);
)

(
~peacefulKeyLeadSheet = (
    title: "Peaceful Key",
    tempo: 186,
    swing: 0.0,  // or keep a feel param; engine currently doesn't use swing

    sections: [
        (name: \intro, meter: [3,4], bars: 16, density: 0.12, energy: 0.18),

        // AABA form:
        (name: \A,     meter: [3,4], bars: 8,  density: 0.18, energy: 0.22),
        (name: \A2,    meter: [3,4], bars: 8,  density: 0.18, energy: 0.22),
        (name: \B,     meter: [3,4], bars: 16, density: 0.24, energy: 0.28),
        (name: \A3,    meter: [3,4], bars: 8,  density: 0.20, energy: 0.24),

        (name: \outro, meter: [3,4], bars: 16, density: 0.10, energy: 0.16)
    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\A, \A2, \B, \A3],
    choruses: 4,
    outro: \outro
)
);
)



/************************************************************
3) LIMBS: engine behavior per kit key (YOU TWEAK THIS OFTEN AND DURING RECORDING!)

THIS IS WHERE YOU CAN 'SHAPE' THE LIVE PERFORMANCE - and actually play the drums
------------------------------------------------------------
This determines limb independence + role:
- subdiv4   : base grid density (relative to 4/4 bar length)
- phase     : rotation/offset so limbs don't line up in unison
- densityMul: makes some limbs sparser/denser relative to ~ctx.density
- vel       : velocity range for that limb (Ableton dynamics)

HOW TO EXTEND:
- Add new kit keys here to control new Drum Rack pads
- Change subdiv4 to change rhythmic granularity
- Change phase to de-align parts (limb independence)
- Change densityMul to make certain limbs “speak” more/less
- Change vel ranges to balance your kit in Ableton

TIP:
- For “less chaos,” lower densityMul or subdiv4 on hatC/perc1.
************************************************************/
(
~limbs = (
    kick:    (subdiv4: 13,  phase: 3, densityMul: 0.001, vel: [55, 105]),
    snare:   (subdiv4: 18,  phase: 1, densityMul: 0.2, vel: [20,  95]),
    hatFoot: (subdiv4: 4,  phase: 1, densityMul: 0.4, vel: [25,  70]),
    hatC:    (subdiv4: 8, phase: 3, densityMul: 0.5, vel: [20,  60]),
    ride:    (subdiv4: 8, phase: 0, densityMul: 0.7, vel: [35,  80]),
    perc1:   (subdiv4: 10, phase: 2, densityMul: 1.1, vel: [30, 100])
);
)


/************************************************************
4) CONTEXT: the shared "what time is it?" state (ENGINE READS THIS)
------------------------------------------------------------
~ctx is the single shared current state:
- section: which section name we are in
- barInSection: bar index within current section
- meter/density/energy: derived from current section definition

All generator layers read ~ctx to adapt their output in real time.

HOW TO EXTEND:
- Add fields like:
  ~ctx.chorus = 0;
  ~ctx.globalBar = 0;
  ~ctx.sectionIndex = 0;
  ~ctx.formIteration = 0;
- Add “cue” flags like:
  ~ctx.isSectionStart = true/false;
  ~ctx.isLastBarOfSection = true/false;
so layers can do transitions/fills/changes near boundaries.
************************************************************/
(
~ctx = (section: \intro, barInSection: 0, meter: [4,4], density: 0.2, energy: 0.2);

~setCtxFromSection = { |sec|
    // Called whenever score enters a new section
    ~ctx.section = sec.name;
    ~ctx.meter = sec.meter;
    ~ctx.density = sec.density;
    ~ctx.energy = sec.energy;
};
)


/************************************************************
5) METER MATH: convert time signature to bar length in quarter-beats
------------------------------------------------------------
We define beatsPerBar in terms of quarter-note beats, because TempoClock
uses "beats" where 1 beat = quarter note by default.

Examples:
- 4/4 => 4 * (4/4) = 4 quarter-beats
- 7/8 => 7 * (4/8) = 3.5 quarter-beats
- 3/4 => 3 * (4/4) = 3 quarter-beats

This makes meter changes easy, and keeps everything coherent.
************************************************************/
(
~barBeats = { |meter|
    var num = meter[0], den = meter[1];
    num * (4/den)
};
)


/************************************************************
6) SCORE FOLLOWER (now built inside ~build)
------------------------------------------------------------
NOTE: The scoreTask is NOT defined as a top-level Task anymore.
It is rebuilt inside ~build every time you call ~start.

WHY:
- Prevents stale Tasks bound to old clocks.
- Makes tune/roadMap overrides reliable.
- Avoids multiple scoreTasks accidentally running at once.

CURRENT BEHAVIOR:
- If ~roadMap exists (or leadSheet.roadMapSpec compiles one):
    -> play roadmap once, print progress, then auto-stop.
- Else:
    -> loop leadSheet.sections forever.

PRINTING:
- Section entry prints at the top of each section.
- Bar-by-bar prints inside the section loop.
  (If too chatty, comment out the bar-level postln.)

EXTENSION POINTS (future):
- Add global counters to ~ctx (globalBar, chorus, sectionIndex).
- Add cue flags: isSectionStart / isLastBar.
- Add per-section directives like layersOn/layersOff.
************************************************************/


/************************************************************
7) LIMB TASK FACTORY: creates one independent generator per kitKey
------------------------------------------------------------
This is your “engine.”

CURRENT ALGORITHM:
- For the current section meter, compute beatsPerBar.
- Decide stepsPerBar from limb role (subdiv4) scaled to bar length.
- Compute a number of "hits" per bar from ~ctx.density * densityMul.
- Emit evenly-spaced-ish hits within the bar, rotated by phase.
- Each limb runs independently and continuously, reading ~ctx.

WHY THIS IS POWERFUL:
- You can swap the generator algorithm (Euclidean / clave / cross-rhythm)
  without changing the lead sheet, score follower, or Ableton routing.

HOW TO EXTEND:
A) Replace the hit distribution:
   - Euclidean/Bjorklund rhythms (very musical)
   - probabilistic accent patterns
   - cross-rhythm cycles (e.g. 5 over 4/4) that reset each section
B) Add microtiming:
   - per-limb jitter, or “ahead/behind” feel profiles
C) Add density shaping:
   - e.g. more hits late in the section, less early (phrasing)
D) Add section cues:
   - detect ~ctx.barInSection and do special behavior at boundaries
************************************************************/
(
~makeLimbTask = { |kitKey|
    Task({
        var stepDur, stepsPerBar, stepIndex, meter, beatsPerBar, hits, note;
        var role, baseSteps, phase, densityMul, velLo, velHi;

        loop {
            // Pull the limb definition (or fallback defaults)
            role = ~limbs[kitKey] ? (subdiv4: 8, phase: 0, densityMul: 1.0, vel: [40, 100]);

            baseSteps  = role.subdiv4;
            phase      = role.phase;
            densityMul = role.densityMul;
            velLo      = role.vel[0];
            velHi      = role.vel[1];

            // Resolve current kit mapping dynamically (allows swapping kits later)
            note = ~leadSheet.kit[kitKey];

            meter = ~ctx.meter;
            beatsPerBar = ~barBeats.(meter);

            // Scale grid to bar length for meter changes
            stepsPerBar = (baseSteps * (beatsPerBar / 4)).round(1).asInteger.max(1);
            stepDur = beatsPerBar / stepsPerBar;

            // Role-aware density => hits per bar
            hits = ((~ctx.density * densityMul).linlin(0.10, 0.40, 1, stepsPerBar).round(1))
                .clip(0, stepsPerBar);

            stepIndex = 0;
            stepsPerBar.do {
                var idx = (stepIndex + phase) % stepsPerBar;

                // Non-human "even-ish" distribution
                var shouldHit = ((idx * hits) % stepsPerBar) < hits;

                if (hits > 0 and: shouldHit) {
                    ~midiOut.noteOn(0, note, rrand(velLo, velHi));
                    SystemClock.sched(0.03, { ~midiOut.noteOff(0, note); nil });
                };

                stepDur.wait;
                stepIndex = stepIndex + 1;
            };
        }
    }, ~clock);
};
)


/************************************************************
8) LAYERS: build one Task per kitKey dynamically
------------------------------------------------------------
This uses ~leadSheet.kit as the source of truth:
- Every key in kit gets a layer Task
- If you add a new kit key (e.g. clap: 39) and map it in Ableton,
  it will automatically start generating unless you choose to skip it.

HOW TO EXTEND:
- Skip certain kit keys (e.g. only kick/snare/hat)
- Use multiple layer factories for different behaviors by role
- Use per-section “layersOn” to activate/deactivate layers
************************************************************/
(
~layers = IdentityDictionary.new;

~buildPulseLayersFromKit = {
    ~leadSheet.kit.keysValuesDo { |k, note|
        ~layers[k] = ~makeLimbTask.(k);
    };
};
)


/************************************************************
9) BUILD/START/STOP: lifecycle management
------------------------------------------------------------
~build:
- Creates a clock based on ~leadSheet.tempo
- Rebuilds scoreTask on that clock
- Rebuilds layers on that clock

~start:
- Calls build, then starts scoreTask + every layer

~stop:
- Stops every layer and the scoreTask

HOW TO EXTEND (next steps):
- Add a ~reset method that zeroes counters and restarts cleanly.
- Move roadMap generation into leadSheet.roadMapSpec for each tune so you
  rarely need to manually set ~roadMap.
- Add richer roadMap specs (e.g. tags, DS al Coda, vamp until cue).
- Add per-section print verbosity options (quiet/section-only/bar-by-bar).
- Add per-section layer enable/disable (e.g. hatC only in B, no perc1 in intro).
- Add "stop-after" controls:
    - already supported implicitly via finite roadMap (auto-stop at end)
    - could also add: stopAfterBars, stopAfterChoruses, etc.
************************************************************/
(
/************************************************************
TUNE OVERRIDE HOOK
------------------------------------------------------------
- Call ~setTune.(<leadSheetEvent>) before ~start to override the default.
- If you don't call ~setTune, ~defaultLeadSheet will be used.
************************************************************/
~defaultLeadSheet = ~leadSheet;   // whatever you defined earlier as the "default"
~activeLeadSheet = nil;

~setTune = { |ls|
    ~activeLeadSheet = ls;
    ("[CtxDrummer] Active leadSheet set to: " ++ ls.title).postln;
};


/************************************************************
ROADMAP PRECEDENCE (current behavior):
1) If ~roadMap is set (manual override), build uses it as-is.
2) Else if leadSheet.roadMapSpec exists, build compiles a finite roadMap.
3) Else, score loops leadSheet.sections forever.

PERSISTENCE NOTE:
- In ~stop, ~roadMap is cleared so the next ~start will recompile from
  leadSheet.roadMapSpec (unless you manually set ~roadMap again).
- If you want ~roadMap to persist across starts, comment out "~roadMap = nil;"
  in ~stop.
Roadmap format example (finite):
    ~roadMap = [\intro, \A, \A2, \B, \A3, \A, \A2, \B, \A3, \outro];

Recommended: keep this inside the leadSheet as roadMapSpec, then compile.
************************************************************/
~roadMap = nil;

~compileRoadMap = { |ls|
    var spec = ls.roadMapSpec;
    if (spec.isNil) { ^nil };

    // Builds: [intro] + (form repeated choruses times) + [outro]
    ^([spec.intro]
        ++ (spec.form ! spec.choruses).flat
        ++ [spec.outro]
    ).flat;
};


/************************************************************
BUILD: create clock, compile roadmap (optional), create score task, create layers
------------------------------------------------------------
IMPORTANT: This rebuilds Tasks every time you call ~start.
That’s good: it avoids stale tasks and makes overrides reliable.
************************************************************/
~build = {
	// --- hard stop anything currently running (prevents duplicate tasks) ---
	if (~scoreTask.notNil) { ~scoreTask.stop };
	if (~layers.notNil) { ~layers.keysValuesDo { |k, t| t.stop } };
    // 1) Choose tune
    // Priority:
    //   a) user override via ~setTune
    //   b) default lead sheet
    ~leadSheet = ~activeLeadSheet ? ~defaultLeadSheet;

	~layers = IdentityDictionary.new;

    // 2) Clock driven by leadSheet tempo
    ~clock = TempoClock(~leadSheet.tempo/60);

    // 3) Roadmap selection
    // Priority:
    //   a) manual override in ~roadMap (if you set it before start)
    //   b) compile from leadSheet.roadMapSpec
    //   c) nil => loop sections forever
    if (~roadMap.isNil) {
        ~roadMap = ~compileRoadMap.(~leadSheet);
    };

    ("[CtxDrummer] Using tune: " ++ ~leadSheet.title).postln;
    if (~roadMap.notNil) {
        ("[CtxDrummer] RoadMap (finite): " ++ ~roadMap).postln;
    } {
        "[CtxDrummer] RoadMap: none (looping sections forever)".postln;
    };

    // 4) Score task: either finite roadmap playback OR infinite sections loop
    ~scoreTask = Task({
        var sections = ~leadSheet.sections;
        var sec, beatsPerBar;

        // Optional form-tracking print helpers:
        // If the leadSheet has roadMapSpec.form, we can count choruses.
        var form = (~leadSheet.roadMapSpec ? ()).form ? nil;
        var formLen = form.notNil.if({ form.size }, { 0 });
        var formStep = 0;
        var chorus = 1;

        if (~roadMap.notNil) {
            // FINITE: play roadmap once, then stop
            ~roadMap.do { |secName|
                sec = sections.detect { |s| s.name == secName };

                if (sec.isNil) {
                    ("[CtxDrummer] WARNING: section not found: " ++ secName).postln;
                } {
                    // PRINT: section entry
                    ("== SECTION: " ++ sec.name
                        ++ " | meter: " ++ sec.meter
                        ++ " | bars: " ++ sec.bars
                        ++ " | chorus: " ++ chorus
                    ).postln;

                    ~setCtxFromSection.(sec);

                    ~ctx.barInSection = 0;
                    beatsPerBar = ~barBeats.(sec.meter);

                    sec.bars.do { |i|
						("   bar " ++ (i+1) ++ "/" ++ sec.bars
							++ " | density " ++ ~ctx.density
							++ " | energy " ++ ~ctx.energy
						).postln;

						beatsPerBar.wait;
						~ctx.barInSection = i+1;  // keep ctx in sync
					};


                    // Chorus counting: advance when we complete a whole form cycle
                    if (form.notNil and: { form.includes(sec.name) }) {
                        formStep = formStep + 1;
                        if (formStep >= formLen) {
                            chorus = chorus + 1;
                            formStep = 0;
                            ("-- END CHORUS: " ++ chorus).postln;
                        };
                    };
                };
            };

            "[CtxDrummer] RoadMap complete. Stopping.".postln;
            // schedule stop on the clock so we stop cleanly
            ~clock.sched(0, { ~stop.(); nil });

        } {
            // INFINITE: loop sections forever (your current behavior)
            var secIndex = 0;

            loop {
                sec = sections[secIndex];

                // PRINT: section entry
                ("== SECTION: " ++ sec.name
                    ++ " | meter: " ++ sec.meter
                    ++ " | bars: " ++ sec.bars
                ).postln;

                ~setCtxFromSection.(sec);

                ~ctx.barInSection = 0;
                beatsPerBar = ~barBeats.(sec.meter);

                sec.bars.do {
                    beatsPerBar.wait;
                    ~ctx.barInSection = ~ctx.barInSection + 1;
                };

                secIndex = (secIndex + 1) % sections.size;
            };
        };
    }, ~clock);

    // 5) Layers: one limb task per kit key (bound to this ~clock)
    ~layers = IdentityDictionary.new;
    ~leadSheet.kit.keysValuesDo { |k, note|
        ~layers[k] = ~makeLimbTask.(k);
    };

	~clickTask = ~makeClickTask.();
};


// START
~start = {
    ~build.();
	if (~clickTask.notNil) { ~clickTask.start };
    ~scoreTask.start;

    if (~layers.notNil) {
        ~layers.keysValuesDo { |k, t| t.start };
    }{
        "[CtxDrummer] WARNING: ~layers is nil".postln;
    };

    "CtxDrummer: started".postln;
};

// STOP
~stop = {
    if (~layers.notNil) { ~layers.keysValuesDo { |k, t| t.stop } };
    if (~scoreTask.notNil) { ~scoreTask.stop };
	if (~clickTask.notNil) { ~clickTask.stop };

    // optional safety: prevent stuck notes in Ableton racks
    // ~midiOut.allNotesOff(0);

    "CtxDrummer: stopped".postln;

    // IMPORTANT: clear roadmap if you want the next start to recompile from leadSheet
    // Comment this out if you want ~roadMap to persist across starts.
    ~roadMap = nil;
};




// Run:
~setTune.(~peacefulKeyLeadSheet); // choose tune here!

~roadMap = [\intro] ++ ([\A, \A2, \B, \A3] ! 4).flat ++ [\outro];  // specify an arrangement here!

~start.();


// Stop:
~stop.();

CmdPeriod.run;     // panic: stops routines, frees synths, clears queues
s.freeAll;

