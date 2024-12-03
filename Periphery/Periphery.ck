//-----------------------------------------------------------------------------
// name: Periphery.ck
// Mateo Larrea
//-----------------------------------------------------------------------------

// Set up the camera and background color
GG.camera().orthographic();
@(0.992, 0.807, 0.388) => GG.scene().backgroundColor; 

// Set up render passes
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1 => bloom_pass.intensity;
0.1 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

// Variables for background color modulation
0 => float bg_time; // Initialize background time
(2.0 * Math.PI) / 60.0 => float bg_omega; // Angular frequency for a 60-second cycle

// Z-position for background circles
-0.5 => float bg_circle_z;

// Define a vibrant color palette
new vec3[0] @=> vec3 vibrant_colors[];
vibrant_colors << @(0.976, 0.643, 0.376);   // Soft Tangerine
vibrant_colors << @(0.992, 0.807, 0.388);   // Sunflower Yellow
vibrant_colors << @(0.357, 0.525, 0.761);   // Cerulean Blue

// Variables for central circle size modulation
3 * 0.8 => float base_circle_size; // Adjusted size
base_circle_size => float current_circle_size;
0.3 * base_circle_size => float min_circle_size;
0.0 => float sin_time;
0.5 => float sin_speed;
0.5 => float previous_sin_speed;

vec3 circle_center;
circle_center.set(0.0, 0.0, 0.0);

0.0 => float env_circle_z;

// Center circle
CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();

// Set center circle position with adjusted z
@(circle_center.x, circle_center.y, env_circle_z) => center_circle_mesh.pos;

center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI);
@(0, 0, 0) => center_circle_material.color; // Cerulean Blue

// Function to smoothly adjust the circle size using a cosine function
fun void updateCircleSize() {
    sin_time + (sin_speed * GG.dt()) => sin_time;
    base_circle_size - ((base_circle_size - min_circle_size) / 2.0) * (1.0 + Math.cos(sin_time)) => current_circle_size;
    center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI);
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

// Instantiate each pad in the array
for (0 => int i; i < NUM_PADS; i++) {
    new GPad @=> pads[i];
}

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
        pad.init(mouse, i);

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

    // Pad index
    int index;

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
        Color.BLACK,    // NONE
        Color.ORANGE,  // HOVERED
        Color.WHITE    // ACTIVE
    ] @=> vec3 colorMap[];

    // Arrays to store background circles for each pad
    new GMesh[5] @=> GMesh bg_circle_meshes[];
    new CircleGeometry[5] @=> CircleGeometry bg_circle_geometries[];
    new FlatMaterial[5] @=> FlatMaterial bg_circle_materials[];
    new float[5] @=> float bg_circle_target_sizes[]; // Target sizes for ease-in animation
    new float[5] @=> float bg_circle_current_sizes[]; // Current sizes for ease-in animation
    new float[5] @=> float bg_circle_growth_speeds[]; // Growth speeds for ease-in animation
    new vec3[5] @=> vec3 bg_circle_colors[];
    new float[5] @=> float bg_circle_speeds[];
    new int[5] @=> int is_shrinking[]; // Track if a circle is shrinking

    // Sound variables
    SndBuf @ sampleBuf;
    float volume;
    float targetVolume;
    float volumeStep;
    1.5 => float fadeTime;

    // Constructor
    fun void init(Mouse @ m, int idx) {
        if (mouse != null) return;
        m @=> this.mouse;
        idx => this.index;
        spork ~ this.clickListener();

        // Initialize sound variables
        null @=> sampleBuf;
        0.0 => volume;
        0.0 => targetVolume;
        0.0 => volumeStep;

        // Spork the update loop
        spork ~ this.selfUpdate();
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

    // Update loop
    fun void selfUpdate() {
        while (true) {
            this.update(GG.dt());
            GG.nextFrame() => now;
        }
    }

    // Handle input and state transitions
    fun void handleInput(int input) {
        if (state == NONE) {
            if (input == MOUSE_HOVER)      enter(HOVERED);
            else if (input == MOUSE_CLICK) {
                enter(ACTIVE);
                instantiateCircles(); // Instantiate circles on pad select
                startSample();        // Start sample on pad select
            }
        } else if (state == HOVERED) {
            if (input == MOUSE_EXIT)       enter(NONE);
            else if (input == MOUSE_CLICK) {
                if (state == ACTIVE) {
                    enter(NONE);
                    shrinkCircles(); // Shrink circles on pad deselect
                    stopSample();    // Stop sample on pad deselect
                } else {
                    enter(ACTIVE);
                    instantiateCircles(); // Instantiate circles on pad select
                    startSample();        // Start sample on pad select
                }
            }
        } else if (state == ACTIVE) {
            if (input == MOUSE_CLICK) {
                enter(NONE);
                shrinkCircles(); // Shrink circles on pad deselect
                stopSample();    // Stop sample on pad deselect
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
        pad.scaX() + (0.05 * (1.0 - pad.scaX())) => pad.sca;

        // Update the growth of circles if active
        if (state == ACTIVE) {
            for (0 => int i; i < bg_circle_meshes.size(); i++) {
                if (is_shrinking[i] == 0 && bg_circle_meshes[i] != null) {
                    bg_circle_current_sizes[i] + (bg_circle_growth_speeds[i] * (bg_circle_target_sizes[i] - bg_circle_current_sizes[i])) => float new_size;
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
                    bg_circle_geometries[i].build(new_size, 72, 0.0, 2.0 * Math.PI);
                }
            }
        }

        // Update volume towards targetVolume
        if (sampleBuf != null) {
            if (volume != targetVolume) {
                volume + (volumeStep * dt) => volume;
                // Ensure volume stays within [0.0, 1.0]
                if (volume > 1.0) { 1.0 => volume; }
                if (volume < 0.0) { 0.0 => volume; }
                if ((volumeStep > 0 && volume >= targetVolume) || (volumeStep < 0 && volume <= targetVolume)) {
                    targetVolume => volume;
                    if (volume == 0.0) {
                        // Stop the sample
                        sampleBuf =< dac;
                        null @=> sampleBuf;
                    }
                }
            }
            // Ensure sampleBuf is not null before setting gain
            if (sampleBuf != null) {
                volume => sampleBuf.gain;
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

            // Random growth speed for ease-in animation
            Std.rand2f(0.02, 0.1) => float growth_speed;
            growth_speed => bg_circle_growth_speeds[i];

            // Random color from the vibrant_colors array
            vibrant_colors.size() => int num_colors;
            Std.rand2(0, num_colors - 1) => int color_index;
            vibrant_colors[color_index] => vec3 circle_color;
            circle_color => bg_circle_colors[i];

            // Create geometry and material
            new CircleGeometry @=> bg_circle_geometries[i];
            bg_circle_geometries[i].build(initial_size, 72, 0.0, 2.0 * Math.PI);

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

    // Start playing the sample with fade in
    fun void startSample() {
        if (sampleBuf == null) {
            new SndBuf @=> sampleBuf;
            sampleBuf => dac;
            // Assign sample file based on index
            string filename;
            if (index == 0) {
                "samples/Nature.wav" => filename;
                0.6 => targetVolume;
            } else if (index == 1) {
                "samples/Rain.wav" => filename;
                0.2 => targetVolume;
            } else if (index == 2) {
                "samples/Beat.wav" => filename;
                0.3 => targetVolume;
            } else if (index == 3) {
                "samples/Drone.wav" => filename;
                1.0 => targetVolume;
            } else {
                // No sample for this pad
                return;
            }
            sampleBuf.read(filename);
            sampleBuf.loop(1);
            0.0 => sampleBuf.gain;
            sampleBuf.play();
            0.0 => volume;
            (targetVolume - volume) / fadeTime => volumeStep;
        } else {
            // Sample is already loaded, restart from beginning
            0 => sampleBuf.pos;
            0.0 => volume;
            if (index == 0) {
                0.6 => targetVolume;
            } else if (index == 1) {
                0.2 => targetVolume;
            } else if (index == 2) {
                0.3 => targetVolume;
            } else if (index == 3) {
                1.0 => targetVolume;
            } else {
                return;
            }
            (targetVolume - volume) / fadeTime => volumeStep;
        }
    }

    // Stop playing the sample with fade out
    fun void stopSample() {
        if (sampleBuf != null) {
            sampleBuf.gain() => volume;
            0.0 => targetVolume;
            (targetVolume - volume) / fadeTime => volumeStep;
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

// Particle class
class Particle {
    GMesh @ mesh;
    CircleGeometry @ geometry;
    FlatMaterial @ material;
    vec3 position;
    vec3 velocity;
    vec3 color;
    float lifespan;
    float age;
    float size;
    int active;

    // Constructor
    fun void init(vec3 pos, vec3 vel, vec3 col, float life, float s) {
        pos => position;
        vel => velocity;
        col => color;
        life => lifespan;
        0.0 => age;
        s => size;
        1 => active;

        // Create geometry and material
        new CircleGeometry @=> geometry;
        geometry.build(size, 32, 0.0, 2.0 * Math.PI);

        new FlatMaterial @=> material;
        material.color(col);

        // Create mesh and add to scene
        new GMesh(geometry, material) @=> mesh;
        mesh --> GG.scene();
        position => mesh.pos;
    }

    // Update function
    fun void update(float dt) {
        age + dt => age;
        if (age < lifespan) {
            // Update position
            position + velocity * dt => position;
            position => mesh.pos;

            // Fade out over time
            1.0 - (age / lifespan) => float alpha;
            material.color( @(color.x * alpha, color.y * alpha, color.z * alpha) );

            // Scale down over time
            size * alpha => float new_size;
            geometry.build(new_size, 32, 0.0, 2.0 * Math.PI);
        } else {
            // Remove particle
            mesh.detach();
            null @=> mesh;
            null @=> geometry;
            null @=> material;
            0 => active;
        }
    }
}

// Particle pool
32 => int MAX_PARTICLES;
Particle particles[MAX_PARTICLES];

// Initialize particles
for (0 => int i; i < MAX_PARTICLES; i++) {
    new Particle @=> particles[i];
    0 => particles[i].active;
}

// Function to instantiate particles when sin_speed changes
fun void instantiateParticles() {
    for (0 => int i; i < 5; i++) {
        // Find an inactive particle
        -1 => int idx;
        for (0 => int j; j < MAX_PARTICLES; j++) {
            if (particles[j].active == 0) {
                j => idx;
                break;
            }
        }
        if (idx == -1) {
            // No inactive particle available
            break;
        }

        // Random size between 0.05 and 0.15
        Std.rand2f(0.05, 0.15) => float size;

        // Random position near center
        circle_center.x + Std.rand2f(-current_circle_size / 2.0, current_circle_size / 2.0) => float x_pos;
        circle_center.y + Std.rand2f(-current_circle_size / 2.0, current_circle_size / 2.0) => float y_pos;
        circle_center.z => float z_pos;
        @(x_pos, y_pos, z_pos) => vec3 position;

        // Random velocity
        Std.rand2f(-1.0, 1.0) => float vx;
        Std.rand2f(-1.0, 1.0) => float vy;
        0.0 => float vz;
        @(vx, vy, vz) => vec3 velocity;

        // Random color from the vibrant_colors array
        vibrant_colors.size() => int num_colors;
        Std.rand2(0, num_colors - 1) => int color_index;
        vibrant_colors[color_index] => vec3 color;

        // Random lifespan between 1 and 2 seconds
        Std.rand2f(1.0, 2.0) => float lifespan;

        // Initialize the particle
        particles[idx].init(position, velocity, color, lifespan, size);
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

    // Read scroll delta
    GWindow.scrollY() => float scroll_delta;

    // Adjust sin_speed based on scroll delta
    sin_speed + (scroll_delta * 0.05) => sin_speed;

    // Clamp sin_speed between 0.2 and 2.0
    if (sin_speed < 0.2) { 0.2 => sin_speed; }
    if (sin_speed > 2.0) { 2.0 => sin_speed; }

    // Check if sin_speed has changed
    if (sin_speed != previous_sin_speed) {
        // sin_speed has changed, so instantiate particles
        instantiateParticles();
    }

    // Update previous sin_speed
    sin_speed => previous_sin_speed;

    // Update center circle size
    updateCircleSize();

    // Place pads after the window is created
    placePads();

    // Update particles
    for (0 => int i; i < MAX_PARTICLES; i++) {
        if (particles[i].active == 1) {
            particles[i].update(GG.dt());
        }
    }
}
