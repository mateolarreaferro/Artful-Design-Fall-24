//-----------------------------------------------------------------------------
// name: simplified_pads.ck
// desc: clickable pads with hover/select functionalities
//-----------------------------------------------------------------------------

// Initialize Mouse Manager
Mouse mouse;
spork ~ mouse.selfUpdate(); // start updating mouse position

// Scene setup
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ cam;
cam.orthographic();  // Orthographic camera mode for 2D scene

// Create pad groups
GGen padGroup --> GG.scene();

// Number of pads
4 => int NUM_PADS;

// Array of pads
GPad pads[NUM_PADS];

// Update pad positions on window resize
fun void resizeListener() {
    WindowResizeEvent e;  // listens to the window resize event
    while (true) {
        e => now;  // window has been resized
        placePads();
    }
} spork ~ resizeListener();

// Place pads based on window size
fun void placePads() {
    // Recalculate aspect ratio
    (GG.frameWidth() * 1.0) / (GG.frameHeight() * 1.0) => float aspect;
    // Calculate world-space units
    cam.viewSize() => float frustrumHeight;
    frustrumHeight * aspect => float frustrumWidth;
    frustrumWidth / NUM_PADS => float padSpacing;

    // Place pads horizontally
    for (0 => int i; i < NUM_PADS; i++) {
        pads[i] @=> GPad pad;

        // Initialize pad
        pad.init(mouse);

        // Connect to scene
        pad --> padGroup;

        // Set transform
        pad.sca(padSpacing * 0.7);
        pad.posX(padSpacing * i - frustrumWidth / 2.0 + padSpacing / 2.0);
    }
    padGroup.posY(0);  // Center the pad group vertically
}

// Class for pads with hover and select functionalities
class GPad extends GGen {
    // Initialize mesh
    GPlane pad --> this;
    FlatMaterial mat;
    pad.mat(mat);

    // Reference to a mouse
    Mouse @ mouse;

    // States
    0 => static int NONE;     // Not hovered or active
    1 => static int HOVERED;  // Hovered
    2 => static int ACTIVE;   // Clicked
    0 => int state;           // Current state

    // Input types
    0 => static int MOUSE_HOVER;
    1 => static int MOUSE_EXIT;
    2 => static int MOUSE_CLICK;

    // Color map
    [
        Color.GRAY,    // NONE
        Color.YELLOW,  // HOVERED
        Color.GREEN    // ACTIVE
    ] @=> vec3 colorMap[];

    // Constructor
    fun void init(Mouse @ m) {
        if (mouse != null) return;
        m @=> this.mouse;
        spork ~ this.clickListener();
    }

    // Set color
    fun void color(vec3 c) {
        mat.color(c);
    }

    // Returns true if mouse is hovering over pad
    fun int isHovered() {
        pad.scaWorld() => vec3 worldScale;  // Get dimensions
        worldScale.x / 2.0 => float halfWidth;
        worldScale.y / 2.0 => float halfHeight;
        pad.posWorld() => vec3 worldPos;    // Get position

        if (mouse.worldPos.x > worldPos.x - halfWidth && mouse.worldPos.x < worldPos.x + halfWidth &&
            mouse.worldPos.y > worldPos.y - halfHeight && mouse.worldPos.y < worldPos.y + halfHeight) {
            return true;
        }
        return false;
    }

    // Poll for hover events
    fun void pollHover() {
        if (isHovered()) {
            handleInput(MOUSE_HOVER);
        } else {
            if (state == HOVERED) handleInput(MOUSE_EXIT);
        }
    }

    // Handle mouse clicks
    fun void clickListener() {
        while (true) {
            GG.nextFrame() => now;
            if (GWindow.mouseLeftDown() && isHovered()) {
                handleInput(MOUSE_CLICK);
            }
        }
    }

    // Handle input and state transitions
    fun void handleInput(int input) {
        if (state == NONE) {
            if (input == MOUSE_HOVER)      enter(HOVERED);
            else if (input == MOUSE_CLICK) enter(ACTIVE);
        } else if (state == HOVERED) {
            if (input == MOUSE_EXIT)       enter(NONE);
            else if (input == MOUSE_CLICK) enter(ACTIVE);
        } else if (state == ACTIVE) {
            if (input == MOUSE_CLICK)      enter(NONE);
        }
    }

    // Enter a new state
    fun void enter(int s) {
        s => state;
    }

    // Override GGen update
    fun void update(float dt) {
        // Check if hovered
        pollHover();

        // Update state color
        this.color(colorMap[state]);

        // Smooth scaling animation
        pad.scaX() + 0.05 * (1.0 - pad.scaX()) => pad.sca;
    }
}

// Simplified Mouse class
class Mouse {
    vec3 worldPos;

    // Update mouse world position
    fun void selfUpdate() {
        while (true) {
            GG.nextFrame() => now;
            // Calculate mouse world X and Y coords
            GG.camera().screenCoordToWorldPos(GWindow.mousePos(), 1.0) => worldPos;
        }
    }
}

// Game loop
while (true) {
    GG.nextFrame() => now;

    // Place pads after the window is created
    placePads();
}
