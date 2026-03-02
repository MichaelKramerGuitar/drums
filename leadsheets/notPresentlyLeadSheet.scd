/**************************************************************
Not Presently Lead Sheet

leadsheets/notPresentlyLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

(
~notPresentlyLeadSheet = (
    title: "Not Presently",
    tempo: 120,
    swing: 0.2,  // or keep a feel param; engine currently doesn't use swing

    sections: [

		(name: \intro,     meter: [3,4], bars: 10,  density: 0.60, energy: 0.90),
        // AABA form:
        (name: \A,     meter: [3,4], bars: 8,  density: 0.60, energy: 0.90),
        (name: \B,     meter: [4,4], bars: 8, density: 0.80, energy: 0.60),
		(name: \B_prime, meter: [4,4], bars: 10, density: 0.88, energy: 0.70),
        (name: \C, meter: [4,4], bars: 16, density: 0.40, energy: 0.20),

    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\A, \B, \B, \A, \C, \A, \B_prime],
    choruses: 1
)
);
)