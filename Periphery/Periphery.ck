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
0 => int num_bg_circles; // Start with no background circles

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

// Variables for central circle size modulation
3 * 0.8 => float base_circle_size; // Adjusted size
base_circle_size => float current_circle_size;
0.3 * base_circle_size => float min_circle_size;
0.0 => float sin_time;
0.45 => float sin_speed;

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
        pad.sca(padSpacing * 0.4);
        pad.posY(padSpacing * i - frustrumHeight / 2.0 + padSpacing / 2.0);
        // Position pads on the left side
        (-frustrumWidth / 2.0 + padSpacing * 0.4) => pad.posX;
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

    // Array to store the background circles for each pad
    new GMesh[5] @=> GMesh bg_circle_meshes[];
    new CircleGeometry[5] @=> CircleGeometry bg_circle_geometries[];
    new FlatMaterial[5] @=> FlatMaterial bg_circle_materials[];
    new float[5] @=> float bg_circle_target_sizes[]; // Target sizes for ease-in animation
    new float[5] @=> float bg_circle_current_sizes[]; // Current sizes for ease-in animation
    new float[5] @=> float bg_circle_growth_speeds[]; // Growth speeds for ease-in animation
    new vec3[5] @=> vec3 bg_circle_colors[];
    new float[5] @=> float bg_circle_speeds[];
    new int[5] @=> int is_shrinking[]; // Track if a circle is shrinking

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
            else if (input == MOUSE_CLICK) {
                enter(ACTIVE);
                instantiateCircles(); // Instantiate circles on pad select
            }
        } else if (state == HOVERED) {
            if (input == MOUSE_EXIT)       enter(NONE);
            else if (input == MOUSE_CLICK) {
                if (state == ACTIVE) {
                    enter(NONE);
                    shrinkCircles(); // Shrink circles on pad deselect
                } else {
                    enter(ACTIVE);
                    instantiateCircles(); // Instantiate circles on pad select
                }
            }
        } else if (state == ACTIVE) {
            if (input == MOUSE_CLICK) {
                enter(NONE);
                shrinkCircles(); // Shrink circles on pad deselect
            }
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

        // Update the growth of circles if active
        if (state == ACTIVE) {
            for (0 => int i; i < bg_circle_meshes.size(); i++) {
                if (is_shrinking[i] == 0 && bg_circle_meshes[i] != null) {
                    bg_circle_current_sizes[i] + bg_circle_growth_speeds[i] * (bg_circle_target_sizes[i] - bg_circle_current_sizes[i]) => float new_size;
                    new_size => bg_circle_current_sizes[i];
                    bg_circle_geometries[i].build(new_size, 64, 0.0, 2.0 * Math.PI);
                }
            }
        }

        // Handle shrinking animation
        for (0 => int i; i < bg_circle_meshes.size(); i++) {
            if (is_shrinking[i] == 1 && bg_circle_meshes[i] != null) {
                bg_circle_current_sizes[i] - (0.05 * bg_circle_target_sizes[i]) => float new_size;
                if (new_size <= 0.0) {
                    // Remove circle from scene
                    bg_circle_meshes[i].detach();
                    null @=> bg_circle_meshes[i];
                    null @=> bg_circle_geometries[i];
                    null @=> bg_circle_materials[i];
                    0 => is_shrinking[i]; // Reset shrinking flag
                } else {
                    new_size => bg_circle_current_sizes[i];
                    bg_circle_geometries[i].build(new_size, 64, 0.0, 2.0 * Math.PI);
                }
            }
        }
    }

    // Instantiate background circles
    fun void instantiateCircles() {
        for (0 => int i; i < 5; i++) {
            // Random size between 0.5 and 1.5
            Std.rand2f(0.5, 1.5) => float circle_size;

            // Set initial size to zero for ease-in effect
            0.0 => float initial_size;

            // Random position within a range (-5.0 to 5.0)
            Std.rand2f(-5.0, 5.0) => float x_pos;
            Std.rand2f(-5.0, 5.0) => float y_pos;

            // Random speed factor for size oscillation
            Std.rand2f(0.1, 0.5) => float speed_factor;
            speed_factor => bg_circle_speeds[i];

            // Random growth speed for ease-in animation
            Std.rand2f(0.02, 0.1) => float growth_speed;
            growth_speed => bg_circle_growth_speeds[i];

            // Random color from the minimalist_colors array
            minimalist_colors.size() => int num_colors;
            Std.rand2(0, num_colors - 1) => int color_index;
            minimalist_colors[color_index] => vec3 circle_color;
            circle_color => bg_circle_colors[i];

            // Create geometry and material
            new CircleGeometry @=> bg_circle_geometries[i];
            bg_circle_geometries[i].build(initial_size, 64, 0.0, 2.0 * Math.PI);

            new FlatMaterial @=> bg_circle_materials[i];
            circle_color => bg_circle_materials[i].color; // Assign color

            // Create mesh and add to scene
            new GMesh(bg_circle_geometries[i], bg_circle_materials[i]) @=> bg_circle_meshes[i];
            bg_circle_meshes[i] --> GG.scene(); // Add to the scene
            @(x_pos, y_pos, bg_circle_z) => bg_circle_meshes[i].pos;

            // Set target size for animation
            circle_size => bg_circle_target_sizes[i];
            initial_size => bg_circle_current_sizes[i];
            0 => is_shrinking[i]; // Set shrinking flag to false
        }
    }

    // Shrink background circles
    fun void shrinkCircles() {
        for (0 => int i; i < bg_circle_meshes.size(); i++) {
            if (bg_circle_meshes[i] != null && is_shrinking[i] == 0) {
                1 => is_shrinking[i];
            }
        }
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

    // Update center circle size
    updateCircleSize();

    // Place pads after the window is created
    placePads();
}
