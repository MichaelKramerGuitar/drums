/**************************************************************
Down Lead Sheet

leadsheets/downLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

(
~notPresentlyLeadSheet = (
    title: "Down",
    tempo: 120,
    swing: 0.9,  // or keep a feel param; engine currently doesn't use swing

    sections: [

		(name: \intro,     meter: [4,4], bars: 10,  density: 0.60, energy: 0.5),
        // AABA form:
        (name: \A,     meter: [4,4], bars: 8,  density: 0.30, energy: 0.20),
		(name: \A,     meter: [4,4], bars: 8,  density: 0.40, energy: 0.30),
        (name: \B,     meter: [4,4], bars: 16, density: 0.50, energy: 0.40),
		(name: \interlude,     meter: [4,4], bars: 8,  density: 0.60, energy: 0.5),

    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\A, \A, \B, \interlude],
    choruses: 2
)
);
)