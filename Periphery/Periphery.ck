// Import ChuGL
Machine.add("chugl");

// Set up the camera and background color
GG.camera().orthographic();
@(0.0, 0.0, 0.0) => GG.scene().backgroundColor;

// Set up render passes
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1.0 => bloom_pass.intensity;
0.3 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

// Number of background circles
20 => int num_bg_circles;

// Arrays to store background circles
new GMesh[0] @=> GMesh bg_circle_meshes[];
new CircleGeometry[0] @=> CircleGeometry bg_circle_geometries[];
new FlatMaterial[0] @=> FlatMaterial bg_circle_materials[];

// Z-position for background circles
-1.0 => float bg_circle_z;

// Create background circles
for (0 => int i; i < num_bg_circles; i++) {
    // Random size between 0.5 and 2.5
    Std.rand2f(0.2, 0.8) => float circle_size;

    // Random position within a range (-5.0 to 5.0)
    Std.rand2f(-6.0, 6.0) => float x_pos;
    Std.rand2f(-6.0, 6.0) => float y_pos;

    // Create geometry and material
    CircleGeometry circle_geo;
    circle_geo.build(circle_size, 64, 0.0, 2.0 * pi);

    FlatMaterial circle_material;
    @(0.8, 0.8, 0.8) => circle_material.color; // Light gray

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

// Number of foreground circles
0 => int num_fg_circles;

// Arrays to store foreground circles
new GMesh[0] @=> GMesh fg_circle_meshes[];
new CircleGeometry[0] @=> CircleGeometry fg_circle_geometries[];
new FlatMaterial[0] @=> FlatMaterial fg_circle_materials[];

// Z-position for foreground circles
0.0 => float fg_circle_z;

// Speed and radius for motion
0.5 => float speed;
2.0 => float radius;

// Create foreground circles
for (0 => int i; i < num_fg_circles; i++) {
    // Size of the circle
    1.0 => float circle_size;

    // Initial position
    0.0 => float x_pos;
    0.0 => float y_pos;

    // Create geometry and material
    CircleGeometry circle_geo;
    circle_geo.build(circle_size, 64, 0.0, 2.0 * pi);

    FlatMaterial circle_material;
    @(1.0, 0.0, 0.0) => circle_material.color; // Red

    // Create mesh and add to scene
    GMesh circle_mesh;
    circle_mesh.geometry(circle_geo);
    circle_mesh.material(circle_material);
    circle_mesh --> GG.scene(); // Add to the scene
    @(x_pos, y_pos, fg_circle_z) => circle_mesh.pos;

    // Add to arrays
    fg_circle_meshes << circle_mesh;
    fg_circle_geometries << circle_geo;
    fg_circle_materials << circle_material;
}

// Main loop
while (true) {
    GG.nextFrame() => now;

    // Update background circles
    for (0 => int i; i < num_bg_circles; i++) {
        // Calculate new size based on time
        0.5 * Math.sin(now / second * 0.5 + i) => float new_size;
        bg_circle_geometries[i].build(new_size, 64, 0.0, 2.0 * pi);
    }

    // Update foreground circles
    for (0 => int i; i < num_fg_circles; i++) {
        // Calculate angle for circular motion
        now / second * speed + i * (2.0 * pi / num_fg_circles) => float angle;

        // Calculate position
        Math.cos(angle) * radius => float x_pos;
        Math.sin(angle) * radius => float y_pos;

        // Update circle position
        @(x_pos, y_pos, fg_circle_z) => fg_circle_meshes[i].pos;
    }
}
