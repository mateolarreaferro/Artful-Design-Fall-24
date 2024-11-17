// Set up the camera and background color
GG.camera().orthographic();
@(0, 0, 0) => GG.scene().backgroundColor;


GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1.0 => bloom_pass.intensity;
0.3 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

0 => float bg_time; // Initialize background time
(2.0 * Math.PI) / 60.0 => float bg_omega; // Angular frequency for a 60-second cycle

// Variables for circle sizes and expansion
3.0 => float base_circle_size;
0.3 * base_circle_size => float min_circle_size;
0.0 => float sin_time;
0.75 => float sin_speed;
base_circle_size => float current_circle_size;

vec3 circle_center;
circle_center.set(0.0, 0.0, 0.0);

// Positions for rendering order
-0.01 => float frame_circle_z;
0.0 => float center_circle_z;

// Create frame circle
1.02 * base_circle_size => float frame_circle_size;
CircleGeometry frame_circle_geo;
FlatMaterial frame_circle_material;
GMesh frame_circle_mesh(frame_circle_geo, frame_circle_material) --> GG.scene();
@(circle_center.x, circle_center.y, frame_circle_z) => frame_circle_mesh.pos;
frame_circle_geo.build(frame_circle_size, 64, 0.0, 2.0 * Math.PI);
@(0.0, 0.0, 0.0) => frame_circle_material.color;

// Create center circle
CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();
@(circle_center.x, circle_center.y, center_circle_z) => center_circle_mesh.pos;
center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI);
@(0.8, 0.8, 0.8) => center_circle_material.color;

// Function to update circle sizes
fun void updateCircleSize() {
    sin_time + (sin_speed * GG.dt()) => sin_time;
    base_circle_size - ((base_circle_size - min_circle_size) / 2.0) * (1.0 + Math.cos(sin_time)) => current_circle_size;
    center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI);
    frame_circle_geo.build(current_circle_size * 1.02, 64, 0.0, 2.0 * Math.PI);
}

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

    // Update circle sizes
    updateCircleSize();
}
