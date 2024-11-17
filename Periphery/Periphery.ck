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
30 => int num_bg_circles;

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
}
