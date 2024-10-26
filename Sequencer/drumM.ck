// Spiral-like Sequencer with ChucK and ChuGL

// Initialize Mouse Manager
Mouse mouse;
spork ~ mouse.selfUpdate(); // start updating mouse position

// Global Sequencer Params
120 => int BPM;  // beats per minute
(1.0/BPM)::minute / 2.0 => dur STEP;  // step duration
16 => int NUM_STEPS;  // steps per sequence

[
-5, -2, 0, 3, 5, 7, 10, 12, 15
] @=> int SCALE[];  // relative MIDI offsets for minor pentatonic scale

// Scene setup
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ cam;
cam.orthographic();  // Orthographic camera mode for 2D scene

GGen padGroup --> GG.scene();  // group for all pads in the spiral

// lead pads
GPad acidBassPads[NUM_STEPS][SCALE.size()];

// Spiral Parameters
360.0 / NUM_STEPS => float angleIncrement;  // Angle step per pad
1.0 => float radiusIncrement;               // Radius increase per step

// update pad positions on window resize
fun void resizeListener() {
    WindowResizeEvent e;
    while (true) {
        e => now;
        <<< GG.windowWidth(), " , ", GG.windowHeight() >>>;
        placePadsSpiral();
    }
} spork ~ resizeListener();

// place pads in a spiral
fun void placePadsSpiral() {
    cam.viewSize() => float viewHeight;
    (GG.frameWidth() * 1.0) / (GG.frameHeight() * 1.0) => float aspect;
    viewHeight * aspect => float viewWidth;
    
    // Starting radius
    float radius = Math.min(viewWidth, viewHeight) / 4.0;
    // Center of the screen
    0.0 => float centerX;
    0.0 => float centerY;
    
    // Place each step in a spiral pattern
    for (0 => int i; i < NUM_STEPS; i++) {
        float angle = i * angleIncrement;  // Calculate angle for this step
        radius += radiusIncrement;         // Increase the radius
        
        // Convert polar coordinates to Cartesian
        (radius * Math.cos(Math.radians(angle))) + centerX => float xPos;
        (radius * Math.sin(Math.radians(angle))) + centerY => float yPos;
        
        // Place vertical pads for the current step
        placePadsVerticalSpiral(acidBassPads[i], padGroup, xPos, yPos);
    }
}

// places pads vertically for each spiral step
fun void placePadsVerticalSpiral(GPad pads[], GGen @ parent, float x, float y) {
    1.0 / pads.size() => float padSpacing;
    for (0 => int i; i < pads.size(); i++) {
        pads[i] @=> GPad pad;
        
        // initialize pad
        pad.init(mouse);
        
        // connect to scene
        pad --> parent;
        
        // set transform for spiral position
        pad.sca(padSpacing * .7);
        pad.posX(x);
        pad.posY(y + (i - pads.size()/2) * padSpacing);
    }
}
