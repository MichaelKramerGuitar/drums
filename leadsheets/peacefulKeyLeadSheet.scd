/**************************************************************
Peaceful Key Lead Sheet

leadsheets/peacefulKeyLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

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