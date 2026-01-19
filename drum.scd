
MIDIClient.dispose;
MIDIClient.init;
// Step 1. find the index of loopMIDI!
MIDIClient.destinations.do { |ep, i|
    (i.asString ++ ": " ++ ep.device ++ " / " ++ ep.name).postln;
};

~midiOut = MIDIOut(2);  // <-- index of loopMIDI from Step 1
~midiOut.latency = 0;


// sanity check
/*~midiOut.noteOn(0, 51, 100);
~midiOut.noteOff(0, 51);*/
// 1 Clock + conductor

(
~tempo = 132/60;
~clock = TempoClock(~tempo);

// This approach is a 12 bar fixed form approach - can move to configuration driven form later
~conductor = (
    bar: 0,
    chorus: 0,
    barsPerChorus: 12,

    advanceBar: { |self|
		self.bar = self.bar + 1;
		if (self.bar >= self.barsPerChorus) {
			self.bar = 0;
			self.chorus = self.chorus + 1;
			("-- New chorus: " ++ self.chorus).postln;
		};
		self.updateFeel;
	}
);
)

(
// These are “musical controls” you can tweak live:
// 0..1: overall activity / conversational pressure
~conductor.density = 0.20;   // Miles-ish default (low)

// 0..1: how "up" the band is (affects accents)
~conductor.energy = 0.05;


// simple per-bar shaping (12-bar chorus)
~conductor.updateFeel = { |self|
    var b = self.bar;

    // a gentle arc: slightly more presence late in the form
    self.density = (
        if (b < 4) { 0.18 }         // bars 1-4: lots of air
        { if (b < 8) { 0.20 }       // bars 5-8: tiny uptick
          { 0.24 } }                // bars 9-12: a touch more intent
    );

    // energy: give the turnaround a little lift, but still subtle
    self.energy = (
        if (b < 10) { 0.22 } { 0.30 }
    );
};
)

~conductor.updateFeel; // call after initialization too

// “human timing” profile (Miles = relaxed, not sloppy)
(
~feel = (
    ride: (aheadLo: -0.010, aheadHi: 0.008),
    hat:  (aheadLo: -0.006, aheadHi: 0.006),
    kick: (aheadLo: -0.010, aheadHi: 0.010),
    snare:(aheadLo: -0.014, aheadHi: 0.010)
);
)


// velocity helper
(
// float 0..1 -> int 1..127
~vel = { |x| (x.clip(0.0, 1.0) * 127).asInteger.max(1) };
)


// 2. Bar task
(
~barTask = Task({
    loop {
        4.wait;
        ~conductor.advanceBar;
    }
}, ~clock);
)


// ride cymbal to use if you're not using a DAW like Ableton
/*(
SynthDef(\ride, {
    |out=0, amp=0.5|
    var sig, env;

    env = EnvGen.kr(Env.perc(0.001, 0.3), doneAction: 2);
    sig = WhiteNoise.ar * env;
    sig = BPF.ar(sig, 8000, 0.3);
    sig = sig * amp;

    Out.ar(out, sig!2);
}).add;
)*/


(
~swingRatio = 0.6;  // 0.5 = straight, ~0.6–0.62 = jazz

~swingDur = Pseq([
    Pfunc { (2/3) * ~swingRatio },
    Pfunc { (1/3) * (1 - ~swingRatio) }
], inf);
)

// swing pattern
(
~swingPattern = Pseq([2/3, 1/3], inf);
)


// Here's the kit defs

// ride
(
~ride = Pbind(
    \type, \midi,
    \midiout, ~midiOut,
    \chan, 0,
    \midinote, 51,
    \dur, ~swingPattern,

    // rare breaths
    \isRest, Pfunc { (0.02 + (~conductor.density * 0.02)).coin },

    // skip-accent contour (classic jazz ride shape)
    \midivel, Pseq([0.45, 0.32], inf).collect { |x|
        var base = x + rrand(-0.05, 0.05);
        // a little more definition on bar 1
        if (~conductor.bar == 0) { base = base + 0.06 };
        // gentle turnaround lift
        if (~conductor.bar >= 10) { base = base + 0.04 };
        ~vel.(base);
    },

    \timingOffset, Pwhite(~feel.ride.aheadLo, ~feel.ride.aheadHi),
    \legato, 0.06
);
)



// hi hat
(
~hihatFoot = Pbind(
    \type, \midi,
    \midiout, ~midiOut,
    \chan, 0,
    \midinote, 44,
    \dur, 1,

    \isRest, Pseq([true, false, true, false], inf),

    \midivel, Pfunc {
        var v = rrand(0.28, 0.42) + (~conductor.energy * 0.05);
        ~vel.(v);
    },

    \timingOffset, Pwhite(~feel.hat.aheadLo, ~feel.hat.aheadHi),
    \legato, 0.04
);
)



// feathering kick
(
~kick = Pbind(
    \type, \midi,
    \midiout, ~midiOut,
    \chan, 0,
    \midinote, 36,
    \dur, 1,

    // feather on 1 (sometimes 3), lots of silence
    \isRest, Pfunc {
        var beatInBar = thisThread.beats.asInteger % 4; // 0..3-ish on quarter grid
        var pHit = if (beatInBar == 0) { 0.85 } { if (beatInBar == 2) { 0.20 } { 0.05 } };
        // slightly more presence late in the form
        pHit = pHit + (~conductor.density * 0.05);
        (pHit.coin).not
    },

    \midivel, Pfunc {
        var v = rrand(0.08, 0.16) + (~conductor.energy * 0.05);
        // occasional supportive accent near turnaround, but rare
        if ((~conductor.bar >= 10) and: { 0.04.coin }) { v = v + 0.25 };
        ~vel.(v);
    },

    \timingOffset, Pwhite(~feel.kick.aheadLo, ~feel.kick.aheadHi),
    \legato, 0.08
);
)



// snare
(
~snare = Pbind(
    \type, \midi,
    \midiout, ~midiOut,
    \chan, 0,
    \midinote, 38,

    // 8th-note listening grid (not constant playing)
    \dur, 0.5,

    \isRest, Pfunc {
        var bar = ~conductor.bar;
        var baseP = 0.03 + (~conductor.density * 0.05);  // very sparse
        var phraseP = 0.0;

        // phrase landmarks: tiny increase, not a fill
        if ([3, 7, 11].includes(bar)) { phraseP = 0.03 };

        // but: avoid too many notes on bar 1 (let the band speak)
        if (bar == 0) { baseP = baseP * 0.6 };

        ((baseP + phraseP).coin).not
    },

    \midivel, Pfunc {
        var v = rrand(0.18, 0.40) + (~conductor.energy * 0.08);

        // rare sharper comment
        if (0.07.coin) { v = v + 0.25 };

        ~vel.(v);
    },

    // snare tends to be a hair behind sometimes in this aesthetic
    \timingOffset, Pwhite(-0.010, 0.014),
    \legato, 0.05
);
)


(
~kit = Ppar([
    ~ride,
    ~hihatFoot,
    ~kick,
    ~snare
]);
)


// START The player
~barTask.start;
~kitPlayer = ~kit.play(~clock);




/// STOP the player
~kitPlayer.stop;
~barTask.stop;



