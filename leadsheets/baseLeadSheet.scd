/***********************************************************************
Base class for all lead sheets, they can inherit anything from here
but most useful is the kit

leadsheets/baseLeadSheet.scd
***********************************************************************/

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

    // KIT MAPPING:
    // Map musical "kit keys" to MIDI note numbers in Ableton Drum Rack.
    // Swap to a new kit by changing these numbers (or by switching ~leadSheet entirely).
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