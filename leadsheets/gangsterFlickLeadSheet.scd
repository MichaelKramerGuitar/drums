/**************************************************************
Gangster Flick Lead Sheet

leadsheets/gangsterFlickLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

(
~gangsterFlickLeadSheet = (
    title: "Gangster Flick",
    tempo: 200,
    swing: 0.2,  // or keep a feel param; engine currently doesn't use swing

    sections: [
        (name: \intro, meter: [5,4], bars: 10, density: 0.95, energy: 0.85),

        // AABA form:
        (name: \A,     meter: [5,4], bars: 12,  density: 0.18, energy: 0.50),
        (name: \A2,    meter: [5,4], bars: 8,  density: 0.21, energy: 0.45),
        (name: \interlude, meter: [5,4], bars: 8, density: 0.76, energy: 0.87),
        (name: \A,     meter: [5,4], bars: 12,  density: 0.18, energy: 0.50),
        (name: \A2,    meter: [5,4], bars: 8,  density: 0.21, energy: 0.45),
        (name: \interlude, meter: [5,4], bars: 8, density: 0.80, energy: 0.87),
        (name: \B,     meter: [5,4], bars: 12, density: 0.12, energy: 0.40),
        (name: \interlude, meter: [5,4], bars: 8, density: 0.85, energy: 0.92),

    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\A, \A2, \interlude, \A, \A2, \interlude, \B, \interlude],
    choruses: 2
)
);
)