/**************************************************************
Scandal Thread Lead Sheet

leadsheets/scandalThreadLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

(
~scandalThreadLeadSheet = (
    title: "Scandal Thread",
    tempo: 208,
    swing: 0.2,  // or keep a feel param; engine currently doesn't use swing

    sections: [
        (name: \intro, meter: [3,4], bars: 12, density: 0.95, energy: 0.40),

        // AABA form:
        (name: \A,     meter: [3,4], bars: 16,  density: 0.50, energy: 0.50),
        (name: \B,     meter: [3,4], bars: 8, density: 0.12, energy: 0.40),
        (name: \interlude, meter: [3,4], bars: 8, density: 0.85, energy: 0.92),
		(name: \outro, meter: [3,4], bars: 8, density: 0.1, energy: 0.1),

    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\intro, \A, \interlude, \A, \interlude, \A, \interlude, \A, \interlude, \A, \interlude, \B, \outro],
    choruses: 2
)
);
)