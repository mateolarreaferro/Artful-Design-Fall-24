//-----------------------------------------------------------------------------
// name: integrated_script_with_pads.ck
// desc: Script with integrated clickable pads as a side bar
//-----------------------------------------------------------------------------

// Set up the camera and background color
GG.camera().orthographic();
@(1, 1, 1) => GG.scene().backgroundColor; // Start with white background

// Set up render passes
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1.0 => bloom_pass.intensity;
0.3 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

// Variables for background color modulation
0 => float bg_time; // Initialize background time
(2.0 * Math.PI) / 60.0 => float bg_omega; // Angular frequency for a 60-second cycle

// Number of background circles
0 => int num_bg_circles;

// Arrays to store background circles
new GMesh[0] @=> GMesh bg_circle_meshes[];
new CircleGeometry[0] @=> CircleGeometry bg_circle_geometries[];
new FlatMaterial[0] @=> FlatMaterial bg_circle_materials[];

// Additional arrays for colors and speeds
new vec3[0] @=> vec3 bg_circle_colors[];
new float[0] @=> float bg_circle_speeds[];

// Z-position for background circles
-0.5 => float bg_circle_z;

// Initialize the minimalist_colors array
new vec3[0] @=> vec3 minimalist_colors[];

// Define minimalist and modern colors
minimalist_colors << @(0.8, 0.8, 0.8);   // Soft Gray
minimalist_colors << @(0.9, 0.9, 0.9);   // Light Gray
minimalist_colors << @(0.7, 0.8, 0.9);   // Pale Blue
minimalist_colors << @(0.6, 0.7, 0.8);   // Muted Blue
minimalist_colors << @(0.7, 0.85, 0.75); // Mint Green
minimalist_colors << @(0.9, 0.8, 0.8);   // Blush Pink
minimalist_colors << @(0.8, 0.75, 0.9);  // Lavender

// Create background circles
for (0 => int i; i < num_bg_circles; i++) {
    // Random size between 0.5 and 1.5
    Std.rand2f(0.5, 1.5) => float circle_size;

    // Random position within a range (-5.5 to 5.5)
    Std.rand2f(-5.5, 5.5) => float x_pos;
    Std.rand2f(-5.5, 5.5) => float y_pos;

    // Random speed factor for size oscillation
    Std.rand2f(0.1, 0.5) => float speed_factor;
    bg_circle_speeds << speed_factor;

    // Random color from the minimalist_colors array
    minimalist_colors.size() => int num_colors;
    Std.rand2(0, num_colors - 1) => int color_index;
    minimalist_colors[color_index] => vec3 circle_color;
    bg_circle_colors << circle_color;

    // Create geometry and material
    CircleGeometry circle_geo;
    circle_geo.build(circle_size, 64, 0.0, 2.0 * Math.PI);

    FlatMaterial circle_material;
    circle_color => circle_material.color; // Assign color

    // Create mesh and add to scene
    GMesh circle_mesh;
    circle_mesh.geometry(circle_geo);
    circle_mesh.material(circle_material);
    circle_mesh --> GG.scene(); // Add to the scene
    @(x_pos, y_pos, bg_circle_z) => circle_mesh.pos;

    // Add to arrays
    bg_circle_meshes << circle_mesh;
    bg_circle_geometries << circle_geo;
    bg_circle_materials << circle_material;
}

// Variables for central circle size modulation
3 * 0.8 => float base_circle_size; // Adjusted size
base_circle_size => float current_circle_size;
0.3 * base_circle_size => float min_circle_size;
0.0 => float sin_time;
0.5 => float sin_speed;

vec3 circle_center;
circle_center.set(0.0, 0.0, 0.0);

// Adjusted positions for rendering order
-0.01 => float frame_circle_z;
0.0 => float env_circle_z;

// Frame circle
1.5 * base_circle_size => float frame_circle_size;
CircleGeometry frame_circle_geo;
FlatMaterial frame_circle_material;
GMesh frame_circle_mesh(frame_circle_geo, frame_circle_material) --> GG.scene();

// Set frame circle position with adjusted z
@(circle_center.x, circle_center.y, frame_circle_z) => frame_circle_mesh.pos;

frame_circle_geo.build(frame_circle_size, 64, 0.0, 2.0 * Math.PI);
@(0.0, 0.0, 0.0) => frame_circle_material.color;

// Center circle
CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();

// Set center circle position with adjusted z
@(circle_center.x, circle_center.y, env_circle_z) => center_circle_mesh.pos;

center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI);
@(0.8, 0.8, 0.8) => center_circle_material.color;

// Function to smoothly adjust the circle size using a cosine function
fun void updateCircleSize() {
    sin_time + (sin_speed * GG.dt()) => sin_time;
    base_circle_size - ((base_circle_size - min_circle_size) / 2.0) * (1.0 + Math.cos(sin_time)) => current_circle_size;
    center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI);
    frame_circle_geo.build(current_circle_size * 1.02, 64, 0.0, 2.0 * Math.PI);
}

// =======================================================
// Integration of clickable pads as a side bar
// =======================================================

// Initialize Mouse Manager
Mouse mouse;
spork ~ mouse.selfUpdate(); // start updating mouse position

// Create pad group
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
    GG.camera().viewSize() => float frustrumHeight;
    frustrumHeight * aspect => float frustrumWidth;

    // Set pad spacing and positions for side bar
    frustrumHeight / NUM_PADS => float padSpacing;
    for (0 => int i; i < NUM_PADS; i++) {
        pads[i] @=> GPad pad;

        // Initialize pad
        pad.init(mouse);

        // Connect to scene
        pad --> padGroup;

        // Set transform
        pad.sca(padSpacing * 0.7);
        pad.posY(padSpacing * i - frustrumHeight / 2.0 + padSpacing / 2.0);
        // Position pads on the left side
        (-frustrumWidth / 2.0 + padSpacing * 0.8) => pad.posX;
    }
    // Adjust padGroup position if needed
    padGroup.posX(0);  // Adjust if necessary
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

// Main loop
while (true) {
    GG.nextFrame() => now;

    // Update background time
    bg_time + GG.dt() => bg_time;

    // Calculate the sine of the angular frequency times time
    bg_omega * bg_time => float bg_angle;
    Math.sin(bg_angle) => float sin_value;

    // Map sine value from [-1,1] to [0,1] for brightness
    (sin_value + 1.0) / 2.0 => float brightness;

    // Set the background color using the calculated brightness
    @(brightness, brightness, brightness) => GG.scene().backgroundColor;

    // Update background circles
    for (0 => int i; i < num_bg_circles; i++) {
        // Calculate new size based on time and individual speed
        0.8 + 0.2 * Math.sin(now / second * bg_circle_speeds[i] + i) => float new_size;
        bg_circle_geometries[i].build(new_size, 64, 0.0, 2.0 * Math.PI);
    }

    // Update center circle size
    updateCircleSize();

    // Place pads after the window is created
    placePads();
}
