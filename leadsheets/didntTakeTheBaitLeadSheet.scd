/**************************************************************
Didn't Take The Bait Lead Sheet

leadsheets/didntTakeTheBaitLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

(
~didntTakeTheBaitLeadSheet = (
    title: "Didn't Take The Bait",
    tempo: 152,
    swing: 0.3,  // or keep a feel param; engine currently doesn't use swing

    sections: [
        (name: \intro, meter: [5,4], bars: 2, density: 0.25, energy: 0.45),

        // AABA form:
        (name: \A,     meter: [5,4], bars: 8,  density: 0.18, energy: 0.22),
        (name: \A2,    meter: [5,4], bars: 8,  density: 0.21, energy: 0.24),
        (name: \B,     meter: [5,4], bars: 8, density: 0.12, energy: 0.28),
        (name: \A3,    meter: [5,4], bars: 8,  density: 0.20, energy: 0.30)
    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\A, \A2, \B, \A3],
    choruses: 3
)
);
)