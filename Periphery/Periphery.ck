// Set up the camera and background color
GG.camera().orthographic();
@(0, 0, 0) => GG.scene().backgroundColor; // Off-White background

// Set up render passes
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1.0 => bloom_pass.intensity;
0.3 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

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
    // Random size between 0.2 and 1.3
    Std.rand2f(0.5, 1.5) => float circle_size;

    // Random position within a range (-4.0 to 4.0)
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
    circle_geo.build(circle_size, 64, 0.0, 2.0 * pi);

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

// Main loop
while (true) {
    GG.nextFrame() => now;

    // Update background circles
    for (0 => int i; i < num_bg_circles; i++) {
        // Calculate new size based on time and individual speed
        0.8 + 0.2 * Math.sin(now / second * bg_circle_speeds[i] + i) => float new_size;
        bg_circle_geometries[i].build(new_size, 64, 0.0, 2.0 * pi);
    }
}
