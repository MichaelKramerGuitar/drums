/**************************************************************
Mind and Heart Lead Sheet

leadsheets/mindAndHeartLeadSheet.scd
**************************************************************/

~leadSheet = "./baseLeadSheet.scd".loadRelative[0];

(
~mindAndHeartLeadSheet = (
    title: "Mind and Heart",
    tempo: 156,
    swing: 0.3,  // or keep a feel param; engine currently doesn't use swing

    sections: [
        (name: \intro, meter: [4,4], bars: 8, density: 0.25, energy: 0.45),

        // AABA form:
        (name: \A,     meter: [4,4], bars: 8,  density: 0.18, energy: 0.22),
        (name: \A2,    meter: [4,4], bars: 8,  density: 0.21, energy: 0.24),
        (name: \B,     meter: [4,4], bars: 8, density: 0.12, energy: 0.28),
        (name: \A3,    meter: [4,4], bars: 8,  density: 0.20, energy: 0.30)
    ],

    kit: ~leadSheet.kit, // reuse same kit mapping
	roadMapSpec: (
    intro: \intro,
    form: [\A, \A2, \B, \A3],
    choruses: 3
)
);
)