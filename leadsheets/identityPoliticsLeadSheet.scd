/**************************************************************
Identity Politics Lead Sheet

leadsheets/identityPoliticsLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

(
~identityPoliticsLeadSheet = (
    title: "Identity Politics",
    tempo: 172,
    swing: 0.5,  // or keep a feel param; engine currently doesn't use swing

    sections: [
        (name: \intro, meter: [9,4], bars: 4, density: 0.25, energy: 0.45),

		// ABC form (16 total bars):
        (name: \A,     meter: [9,4], bars: 8,  density: 0.18, energy: 0.22),
        (name: \B,    meter: [9,4], bars: 4,  density: 0.25, energy: 0.24),
        (name: \C,     meter: [9,4], bars: 4, density: 0.32, energy: 0.28),
		(name: \outro, meter: [9,4], bars: 4, density: 0.25, energy: 0.45),
    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\A, \B, \C],
    choruses: 2
)
);
)