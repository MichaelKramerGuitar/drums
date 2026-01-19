


MIDIClient.init;

MIDIClient.destinations.do { |ep, i|
    (i.asString ++ ": " ++ ep.device ++ " / " ++ ep.name).postln;
};

~midiOut = MIDIOut(2);  // <-- index of loopMIDI from Step 1
~midiOut.latency = 0;

// sanity check

//
// ~midiOut.noteOn(0, 60, 100);
//
// ~midiOut.noteOff(0, 60);

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
~limbs = (
    kick:    (subdiv4: 4,  phase: 0, densityMul: 0.6, vel: [55, 105]),
    snare:   (subdiv4: 8,  phase: 3, densityMul: 0.8, vel: [35,  95]),
    hatFoot: (subdiv4: 4,  phase: 1, densityMul: 0.4, vel: [25,  70]),
    hatC:    (subdiv4: 16, phase: 0, densityMul: 1.0, vel: [20,  60]),
    ride:    (subdiv4: 12, phase: 0, densityMul: 0.7, vel: [35,  80]),
    perc1:   (subdiv4: 10, phase: 2, densityMul: 1.1, vel: [30, 100])
);
)


(
~ctx = (section: \intro, barInSection: 0, meter: [4,4], density: 0.2, energy: 0.2);

~setCtxFromSection = { |sec|
    ~ctx.section = sec.name;
    ~ctx.meter = sec.meter;
    ~ctx.density = sec.density;
    ~ctx.energy = sec.energy;
};
)


(
~barBeats = { |meter|
    var num = meter[0], den = meter[1];
    num * (4/den)   // beats measured in quarter-notes
};
)


(
~scoreTask = Task({
    var sections = ~leadSheet.sections;
    var secIndex = 0;
    var sec, beatsPerBar;

    loop {
        sec = sections[secIndex];
        ~setCtxFromSection.(sec);

        ~ctx.barInSection = 0;
        beatsPerBar = ~barBeats.(sec.meter);

        sec.bars.do {
            // bar boundary "tick"
            // ("sec:" + ~ctx.section + " bar:" + ~ctx.barInSection + " meter:" + sec.meter).postln;

            beatsPerBar.wait;
            ~ctx.barInSection = ~ctx.barInSection + 1;
        };

        secIndex = (secIndex + 1) % sections.size;
    }
}, ~clock);
)

(
~makeLimbTask = { |kitKey|
    Task({
        var stepDur, stepsPerBar, stepIndex, meter, beatsPerBar, hits, note;
        var role, baseSteps, phase, densityMul, velLo, velHi;

        loop {
            role = ~limbs[kitKey] ? (subdiv4: 8, phase: 0, densityMul: 1.0, vel: [40, 100]);

            baseSteps  = role.subdiv4;
            phase      = role.phase;
            densityMul = role.densityMul;
            velLo      = role.vel[0];
            velHi      = role.vel[1];

            note = ~leadSheet.kit[kitKey];

            meter = ~ctx.meter;
            beatsPerBar = ~barBeats.(meter);

            // scale step count so it tracks bar length when meter changes
            stepsPerBar = (baseSteps * (beatsPerBar / 4)).round(1).asInteger.max(1);
            stepDur = beatsPerBar / stepsPerBar;

            // role-aware density
            hits = ((~ctx.density * densityMul).linlin(0.10, 0.40, 1, stepsPerBar).round(1))
                .clip(0, stepsPerBar);

            stepIndex = 0;
            stepsPerBar.do {
                var idx = (stepIndex + phase) % stepsPerBar;

                // evenly-spaced-ish distribution (still “non-human”)
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


// one task per instrument option
~pulseKick  = ~makeLimbTask.(\kick, 50, 110);
~pulseSnare = ~makeLimbTask.(\snare, 30, 90);


// get all layers dynamically, i.e. whole kit
(
~layers = IdentityDictionary.new;

~buildPulseLayersFromKit = {
    ~leadSheet.kit.keysValuesDo { |k, note|
        // optionally skip some keys if you want
        ~layers[k] = ~makeLimbTask.(k);
    };
};

~startLayers = {
    ~layers.valuesDo(_.start);
};

~stopLayers = {
    ~layers.valuesDo(_.stop);
};
)




(
// --- BUILD: create clock and rebuild tasks on it ---
~build = {
    // clock
    ~clock = TempoClock(~leadSheet.tempo/60);

    // rebuild score task on this clock
    ~scoreTask = Task({
        var sections = ~leadSheet.sections;
        var secIndex = 0;
        var sec, beatsPerBar;

        loop {
            sec = sections[secIndex];
            ~setCtxFromSection.(sec);

            ~ctx.barInSection = 0;
            beatsPerBar = ~barBeats.(sec.meter);

            sec.bars.do {
                beatsPerBar.wait;
                ~ctx.barInSection = ~ctx.barInSection + 1;
            };

            secIndex = (secIndex + 1) % sections.size;
        }
    }, ~clock);

    // rebuild layers dictionary from kit (each task bound to ~clock)
    ~layers = IdentityDictionary.new;
    ~leadSheet.kit.keysValuesDo { |k, note|
        ~layers[k] = ~makeLimbTask.(k); // makePulseTask uses ~clock
    };
};

// --- START ---
~start = {
    ~build.();
    ~scoreTask.start;
    ~layers.keysValuesDo { |k, t| t.start };
    "CtxDrummer: started".postln;
};

// --- STOP ---
~stop = {
    if (~layers.notNil) { ~layers.keysValuesDo { |k, t| t.stop } };
    if (~scoreTask.notNil) { ~scoreTask.stop };
    "CtxDrummer: stopped".postln;
};
)

~start.();
~stop.();

